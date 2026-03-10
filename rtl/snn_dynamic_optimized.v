// Dynamic-precision Triplet SNN with Per-Synapse Spike-Gated optimization
// Based on snn_dynamic.v with added SPIKE_GATE_EN parameter
// When SPIKE_GATE_EN=1, each synapse's STDP logic is individually gated:
//   - Synapse i is only active when S_in[i] OR spike1_now OR spike2_now
//   - Idle synapses (no pre/post spike) skip all STDP arithmetic
//   - With typical ~10-40% input activity, ~60-90% of synapses are gated off each cycle
// Trace decay runs every cycle regardless of gating (required for correctness).

module snn_dynamic_optimized #(
    parameter W_BITS      = 4,  // weight bit-width (2 = original precision, 4 = extended)
    parameter MODE        = 0,  // 0 = all-to-all, 1 = nearest-neighbor
    parameter TRIPLET_EN  = 1,  // 1 = triplet STDP, 0 = pair-based only
    parameter TRACE_BITS  = 4,  // trace register width (2 = 2-cycle window, 4 = 4-cycle window)
    parameter LEAK_EN     = 1,  // 1 = LIF (leaky), 0 = IF (no leak, matches original snn_network)
    parameter SYMMETRIC   = 1,  // 1 = symmetric LTP/LTD (A2_MINUS = A2_PLUS), 0 = use asymmetric A params
    parameter SPIKE_GATE_EN = 1, // 1 = per-synapse STDP gating when no local spikes (power optimization)
    parameter SEG_ADDER_EN  = 0, // 1 = approximate segmented adder for weighted sum (speed optimization)
    parameter LUT_STDP_EN   = 0  // 1 = use LUT-based STDP (ROM replaces multipliers), 0 = arithmetic STDP
) (
    input  wire              clk,
    input  wire              rst,
    input  wire [24:0]       S_in,    // input spikes
    input  wire              train,   // toggle to freeze weights between train and test
    output reg  [W_BITS+5:0] V1, V2,  // membrane potentials (width scales with W_BITS)
    output reg               spike1, spike2
);

// derived constants
localparam W_MAX          = (1 << W_BITS) - 1;        // max weight value
localparam W_SCALE_FACTOR = (1 << (W_BITS - 2));      // multiplier from original 2-bit values
localparam V_BITS         = W_BITS + 6;                // membrane potential width
localparam WSUM_BITS      = W_BITS + 5;                // weighted sum width (W_MAX * 25)
localparam TRACE_MAX      = (1 << TRACE_BITS) - 1;    // max trace value
// Approximate segmented adder: truncate bottom SEG_TRUNC_BITS from each weight
// before accumulation. This narrows the adder tree from WSUM_BITS to
// (W_BITS - SEG_TRUNC_BITS + 5) bits, reducing area, power, and critical path.
// The truncated bits are zero-filled in the result, bounding the error to
// at most 25 * (2^SEG_TRUNC_BITS - 1) LSBs per weighted sum.
localparam SEG_TRUNC_BITS = W_BITS / 2;                        // bits to truncate (2 for W_BITS=4)
localparam SEG_EFF_BITS   = W_BITS - SEG_TRUNC_BITS;           // effective weight bits after truncation
localparam SEG_WSUM_BITS  = SEG_EFF_BITS + 5;                  // narrowed accumulator width

// neuron parameters (base values scaled by W_SCALE_FACTOR)
parameter V_REST      = 6 * W_SCALE_FACTOR;
parameter V_THRESHOLD = 65 * W_SCALE_FACTOR;
parameter K_SYN       = 1;
parameter V_LEAK      = LEAK_EN ? 1 * W_SCALE_FACTOR : 0;

// STDP parameters
parameter A2_PLUS   = 4'd1;                          // pair-based LTP magnitude
parameter A2_MINUS  = SYMMETRIC ? A2_PLUS : 4'd3;    // symmetric: LTD = LTP; asymmetric: LTD = 3
parameter A3_PLUS   = 4'd1;                          // triplet LTP magnitude (modulated by o2)
parameter A3_MINUS  = 4'd4;                          // triplet LTD magnitude (modulated by r2)
parameter DW_SCALE  = TRACE_BITS - 2;                 // right-shift to scale weight updates (scales with trace width)
parameter TRACE_INC = (1 << (TRACE_BITS - 1));       // trace increment (half of max → 2 decay steps per spike)

// weight arrays (parameterized width)
reg [W_BITS-1:0] w1 [0:24];
reg [W_BITS-1:0] w2 [0:24];

// pre-synaptic traces (width controlled by TRACE_BITS)
reg [TRACE_BITS-1:0] r1 [0:24];   // fast pre-synaptic trace (decays by >>1 each cycle)
reg [TRACE_BITS-1:0] r2 [0:24];   // slow pre-synaptic trace (decays by -2 each cycle)

// post-synaptic traces (per output neuron)
reg [TRACE_BITS-1:0] o1_1, o1_2;  // fast post-synaptic trace (decays by >>1)
reg [TRACE_BITS-1:0] o2_1, o2_2;  // slow post-synaptic trace (decays by -2)

// 1-cycle delayed input for weighted sum (matches original behavior)
reg [24:0] S_in_prev;

// delayed reset flags
reg need_reset_1, need_reset_2;

// weighted sums (width scales with weight precision)
reg [WSUM_BITS-1:0] wsum1, wsum2;
integer i;

// spike detection (post-leak threshold check)
wire spike1_now = !need_reset_1 && (V1 + wsum1 >= V_THRESHOLD + V_LEAK);
wire spike2_now = !need_reset_2 && (V2 + wsum2 >= V_THRESHOLD + V_LEAK);

// spike-gating signals
// Global: any spike activity this cycle (used for coarse gating fallback)
wire any_spike = (|S_in) | spike1_now | spike2_now;
// Per-synapse: synapse i only needs STDP when its pre-synaptic input fires OR
// a post-synaptic neuron fires. Potentiation requires (spike_post AND r1[i]>0),
// depression requires (S_in[i] AND o1>0). Gating on S_in[i]|spike1_now|spike2_now
// is safe because if none are true, both pot and dep terms are zero for synapse i.

// initial weight maps (original 2-bit values scaled by W_SCALE_FACTOR)
initial begin
    // Output neuron 1:
    // original: {1,0,0,1,2, 0,3,2,3,0, 2,2,1,3,3, 1,3,0,0,2, 3,1,1,0,1}
    w1[0]  = 1 * W_SCALE_FACTOR; w1[1]  = 0;                   w1[2]  = 0;                   w1[3]  = 1 * W_SCALE_FACTOR; w1[4]  = 2 * W_SCALE_FACTOR;
    w1[5]  = 0;                   w1[6]  = 3 * W_SCALE_FACTOR; w1[7]  = 2 * W_SCALE_FACTOR; w1[8]  = 3 * W_SCALE_FACTOR; w1[9]  = 0;
    w1[10] = 2 * W_SCALE_FACTOR; w1[11] = 2 * W_SCALE_FACTOR; w1[12] = 1 * W_SCALE_FACTOR; w1[13] = 3 * W_SCALE_FACTOR; w1[14] = 3 * W_SCALE_FACTOR;
    w1[15] = 1 * W_SCALE_FACTOR; w1[16] = 3 * W_SCALE_FACTOR; w1[17] = 0;                   w1[18] = 0;                   w1[19] = 2 * W_SCALE_FACTOR;
    w1[20] = 3 * W_SCALE_FACTOR; w1[21] = 1 * W_SCALE_FACTOR; w1[22] = 1 * W_SCALE_FACTOR; w1[23] = 0;                   w1[24] = 1 * W_SCALE_FACTOR;

    // Output neuron 2:
    // original: {0,2,3,0,1, 2,0,2,0,0, 1,2,3,1,2, 0,1,1,0,1, 2,3,1,3,0}
    w2[0]  = 0;                   w2[1]  = 2 * W_SCALE_FACTOR; w2[2]  = 3 * W_SCALE_FACTOR; w2[3]  = 0;                   w2[4]  = 1 * W_SCALE_FACTOR;
    w2[5]  = 2 * W_SCALE_FACTOR; w2[6]  = 0;                   w2[7]  = 2 * W_SCALE_FACTOR; w2[8]  = 0;                   w2[9]  = 0;
    w2[10] = 1 * W_SCALE_FACTOR; w2[11] = 2 * W_SCALE_FACTOR; w2[12] = 3 * W_SCALE_FACTOR; w2[13] = 1 * W_SCALE_FACTOR; w2[14] = 2 * W_SCALE_FACTOR;
    w2[15] = 0;                   w2[16] = 1 * W_SCALE_FACTOR; w2[17] = 1 * W_SCALE_FACTOR; w2[18] = 0;                   w2[19] = 1 * W_SCALE_FACTOR;
    w2[20] = 2 * W_SCALE_FACTOR; w2[21] = 3 * W_SCALE_FACTOR; w2[22] = 1 * W_SCALE_FACTOR; w2[23] = 3 * W_SCALE_FACTOR; w2[24] = 0;
end

// LUT-based STDP ROMs (256 entries each: indexed by {trace1[3:0], trace2[3:0]})
// Stores pre-computed, scaled+clamped delta values, eliminating STDP multipliers.
// Only used when LUT_STDP_EN=1; synthesizer optimizes away when LUT_STDP_EN=0.
reg [W_BITS-1:0] lut_pot [0:255];  // potentiation delta: indexed by {r1, o2}
reg [W_BITS-1:0] lut_dep [0:255];  // depression delta:   indexed by {o1, r2}
// Initialize LUT arrays unconditionally — when LUT_STDP_EN=0, synthesis
// optimizes them away since they are never read.
initial begin
    `ifdef SYNTHESIS
        // Hardcoded LUT data for synthesis (no $readmemh)
        `include "stdp_lut_data.vh"
    `else
        // Simulation: load from .mem files
        $readmemh("lut/stdp_pot.mem", lut_pot);
        $readmemh("lut/stdp_dep.mem", lut_dep);
    `endif
end

// combinational weighted sums (uses 1-cycle delayed input, same as original)
// Spike-gated: when SPIKE_GATE_EN=1 and no delayed inputs active, skip computation
// Segmented adder: when SEG_ADDER_EN=1, split accumulation into independent
// MSB/LSB segments with carry killed at SEG_SPLIT to shorten critical path.
wire any_input = |S_in_prev;
generate
if (SEG_ADDER_EN) begin : gen_seg_adder
    // Approximate adder: truncate bottom SEG_TRUNC_BITS from each weight,
    // then accumulate using a single NARROWER adder tree (SEG_WSUM_BITS wide
    // instead of WSUM_BITS). The truncated LSBs are zero-filled in the output.
    // This reduces the number of gates in the adder tree AND shortens carry chains.
    // With W_BITS=4, SEG_TRUNC_BITS=2: each weight is 2-bit, accumulator is 7-bit
    // vs exact 4-bit weights / 9-bit accumulator → ~40% fewer adder bits.
    reg [SEG_WSUM_BITS-1:0] sum_trunc1, sum_trunc2;
    reg [SEG_EFF_BITS-1:0] trunc_w1, trunc_w2;
    always @(*) begin
        sum_trunc1 = 0;
        sum_trunc2 = 0;
        wsum1 = 0;
        wsum2 = 0;
        if (!SPIKE_GATE_EN || any_input) begin
            for (i = 0; i < 25; i = i + 1) begin
                // Truncate: keep only the top SEG_EFF_BITS of each weight
                trunc_w1 = w1[i][W_BITS-1:SEG_TRUNC_BITS] & {SEG_EFF_BITS{S_in_prev[i]}};
                trunc_w2 = w2[i][W_BITS-1:SEG_TRUNC_BITS] & {SEG_EFF_BITS{S_in_prev[i]}};
                sum_trunc1 = sum_trunc1 + trunc_w1;
                sum_trunc2 = sum_trunc2 + trunc_w2;
            end
            // Zero-fill truncated LSBs to restore scale
            wsum1 = {sum_trunc1, {SEG_TRUNC_BITS{1'b0}}};
            wsum2 = {sum_trunc2, {SEG_TRUNC_BITS{1'b0}}};
        end
    end
end else begin : gen_exact_adder
    // Exact adder: single carry chain (original behavior)
    always @(*) begin
        wsum1 = 0;
        wsum2 = 0;
        if (!SPIKE_GATE_EN || any_input) begin
            for (i = 0; i < 25; i = i + 1) begin
                wsum1 = wsum1 + (K_SYN * w1[i] * S_in_prev[i]);
                wsum2 = wsum2 + (K_SYN * w2[i] * S_in_prev[i]);
            end
        end
    end
end
endgenerate

// sequential logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        V1 <= V_REST;
        V2 <= V_REST;
        spike1 <= 1'b0;
        spike2 <= 1'b0;
        need_reset_1 <= 1'b0;
        need_reset_2 <= 1'b0;
        S_in_prev <= 25'b0;
        o1_1 <= 0;
        o1_2 <= 0;
        o2_1 <= 0;
        o2_2 <= 0;
        for (i = 0; i < 25; i = i + 1) begin
            r1[i] <= 0;
            r2[i] <= 0;
        end
    end
    else begin
        // --- LIF neuron 1 update (with leak) ---
        if (need_reset_1) begin
            V1 <= V_REST;
            spike1 <= 1'b0;
            need_reset_1 <= 1'b0;
        end
        else begin
            if (V1 + wsum1 >= V_THRESHOLD + V_LEAK) begin
                V1 <= V1 + wsum1 - V_LEAK;
                spike1 <= 1'b1;
                need_reset_1 <= 1'b1;
            end
            else if (V1 + wsum1 < V_REST + V_LEAK) begin
                V1 <= V_REST;
                spike1 <= 1'b0;
            end
            else begin
                V1 <= V1 + wsum1 - V_LEAK;
                spike1 <= 1'b0;
            end
        end

        // --- LIF neuron 2 update (with leak) ---
        if (need_reset_2) begin
            V2 <= V_REST;
            spike2 <= 1'b0;
            need_reset_2 <= 1'b0;
        end
        else begin
            if (V2 + wsum2 >= V_THRESHOLD + V_LEAK) begin
                V2 <= V2 + wsum2 - V_LEAK;
                spike2 <= 1'b1;
                need_reset_2 <= 1'b1;
            end
            else if (V2 + wsum2 < V_REST + V_LEAK) begin
                V2 <= V_REST;
                spike2 <= 1'b0;
            end
            else begin
                V2 <= V2 + wsum2 - V_LEAK;
                spike2 <= 1'b0;
            end
        end

        // --- Lateral inhibition ---
        if (!need_reset_1 && spike1_now &&
            (need_reset_2 || !spike2_now)) begin
            if (!need_reset_2)
                need_reset_2 <= 1'b1;
        end
        if (!need_reset_2 && spike2_now &&
            (need_reset_1 || !spike1_now)) begin
            if (!need_reset_1)
                need_reset_1 <= 1'b1;
        end

        // --- Triplet STDP weight updates (per-synapse spike-gated) ---
        // When SPIKE_GATE_EN=1, each synapse's STDP is individually gated:
        //   - Potentiation only fires when a post-synaptic neuron spikes
        //   - Depression only fires when the pre-synaptic input S_in[i] is active
        //   - If neither condition is true for synapse i, skip its entire update
        // This gives fine-grained gating: ~60-90% of synapses are idle each cycle.
        if (train) begin
            for (i = 0; i < 25; i = i + 1) begin : stdp_loop
                reg [11:0] pot_raw1, dep_raw1;
                reg [11:0] pot_raw2, dep_raw2;
                reg [11:0] pot_shift1, dep_shift1;
                reg [11:0] pot_shift2, dep_shift2;
                reg signed [12:0] dw1, dw2;
                reg signed [12:0] new_w1, new_w2;

                // Per-synapse gate: skip if no pre or post spike relevant to this synapse
                if (!SPIKE_GATE_EN || S_in[i] || spike1_now || spike2_now) begin

                if (LUT_STDP_EN) begin
                    // --- LUT-based STDP: ROM lookup replaces 4 multiplications ---
                    // Potentiation delta from LUT (indexed by {r1, o2})
                    // Depression  delta from LUT (indexed by {o1, r2})

                    // NEURON 1
                    pot_shift1 = spike1_now ? {8'd0, lut_pot[{r1[i], o2_1}]} : 12'd0;
                    dep_shift1 = S_in[i]   ? {8'd0, lut_dep[{o1_1, r2[i]}]} : 12'd0;

                    dw1 = $signed({1'b0, pot_shift1}) - $signed({1'b0, dep_shift1});
                    new_w1 = $signed({1'b0, {4'b0, w1[i]}}) + dw1;

                    if (new_w1 < 0)
                        w1[i] <= 0;
                    else if (new_w1 > W_MAX)
                        w1[i] <= W_MAX;
                    else
                        w1[i] <= new_w1;

                    // NEURON 2
                    pot_shift2 = spike2_now ? {8'd0, lut_pot[{r1[i], o2_2}]} : 12'd0;
                    dep_shift2 = S_in[i]   ? {8'd0, lut_dep[{o1_2, r2[i]}]} : 12'd0;

                    dw2 = $signed({1'b0, pot_shift2}) - $signed({1'b0, dep_shift2});
                    new_w2 = $signed({1'b0, {4'b0, w2[i]}}) + dw2;

                    if (new_w2 < 0)
                        w2[i] <= 0;
                    else if (new_w2 > W_MAX)
                        w2[i] <= W_MAX;
                    else
                        w2[i] <= new_w2;

                end else begin
                    // --- Arithmetic STDP: original multiply-shift-clamp path ---

                    // NEURON 1
                    pot_raw1 = 12'd0;
                    dep_raw1 = 12'd0;

                    if (spike1_now)
                        pot_raw1 = r1[i] * A2_PLUS + (TRIPLET_EN ? ((r1[i] * o2_1) >> TRACE_BITS) * A3_PLUS : 0);

                    if (S_in[i])
                        dep_raw1 = o1_1 * A2_MINUS + (TRIPLET_EN ? ((o1_1 * r2[i]) >> TRACE_BITS) * A3_MINUS : 0);

                    // scale and clamp to weight range
                    pot_shift1 = pot_raw1 >> DW_SCALE;
                    dep_shift1 = dep_raw1 >> DW_SCALE;
                    if (pot_shift1 > W_MAX) pot_shift1 = W_MAX;
                    if (dep_shift1 > W_MAX) dep_shift1 = W_MAX;

                    dw1 = $signed({1'b0, pot_shift1}) - $signed({1'b0, dep_shift1});
                    new_w1 = $signed({1'b0, {4'b0, w1[i]}}) + dw1;

                    if (new_w1 < 0)
                        w1[i] <= 0;
                    else if (new_w1 > W_MAX)
                        w1[i] <= W_MAX;
                    else
                        w1[i] <= new_w1;

                    // NEURON 2
                    pot_raw2 = 12'd0;
                    dep_raw2 = 12'd0;

                    if (spike2_now)
                        pot_raw2 = r1[i] * A2_PLUS + (TRIPLET_EN ? ((r1[i] * o2_2) >> TRACE_BITS) * A3_PLUS : 0);

                    if (S_in[i])
                        dep_raw2 = o1_2 * A2_MINUS + (TRIPLET_EN ? ((o1_2 * r2[i]) >> TRACE_BITS) * A3_MINUS : 0);

                    pot_shift2 = pot_raw2 >> DW_SCALE;
                    dep_shift2 = dep_raw2 >> DW_SCALE;
                    if (pot_shift2 > W_MAX) pot_shift2 = W_MAX;
                    if (dep_shift2 > W_MAX) dep_shift2 = W_MAX;

                    dw2 = $signed({1'b0, pot_shift2}) - $signed({1'b0, dep_shift2});
                    new_w2 = $signed({1'b0, {4'b0, w2[i]}}) + dw2;

                    if (new_w2 < 0)
                        w2[i] <= 0;
                    else if (new_w2 > W_MAX)
                        w2[i] <= W_MAX;
                    else
                        w2[i] <= new_w2;
                end

                end // per-synapse gate
            end
        end

        // --- Update pre-synaptic traces (NOT gated — must decay every cycle) ---
        for (i = 0; i < 25; i = i + 1) begin : trace_pre_update
            if (S_in[i]) begin
                if (MODE == 1)
                    r1[i] <= TRACE_INC;
                else
                    r1[i] <= (r1[i] + TRACE_INC > TRACE_MAX) ? TRACE_MAX[TRACE_BITS-1:0] : r1[i] + TRACE_INC;
            end
            else begin
                r1[i] <= r1[i] >> 1;
            end

            if (S_in[i]) begin
                if (MODE == 1)
                    r2[i] <= TRACE_INC;
                else
                    r2[i] <= (r2[i] + TRACE_INC > TRACE_MAX) ? TRACE_MAX[TRACE_BITS-1:0] : r2[i] + TRACE_INC;
            end
            else begin
                r2[i] <= (r2[i] > 1) ? r2[i] - 2 : 0;
            end
        end

        // --- Update post-synaptic traces (NOT gated — must decay every cycle) ---
        if (spike1_now) begin
            if (MODE == 1) begin
                o1_1 <= TRACE_INC;
                o2_1 <= TRACE_INC;
            end
            else begin
                o1_1 <= (o1_1 + TRACE_INC > TRACE_MAX) ? TRACE_MAX[TRACE_BITS-1:0] : o1_1 + TRACE_INC;
                o2_1 <= (o2_1 + TRACE_INC > TRACE_MAX) ? TRACE_MAX[TRACE_BITS-1:0] : o2_1 + TRACE_INC;
            end
        end
        else begin
            o1_1 <= o1_1 >> 1;
            o2_1 <= (o2_1 > 1) ? o2_1 - 2 : 0;
        end

        if (spike2_now) begin
            if (MODE == 1) begin
                o1_2 <= TRACE_INC;
                o2_2 <= TRACE_INC;
            end
            else begin
                o1_2 <= (o1_2 + TRACE_INC > TRACE_MAX) ? TRACE_MAX[TRACE_BITS-1:0] : o1_2 + TRACE_INC;
                o2_2 <= (o2_2 + TRACE_INC > TRACE_MAX) ? TRACE_MAX[TRACE_BITS-1:0] : o2_2 + TRACE_INC;
            end
        end
        else begin
            o1_2 <= o1_2 >> 1;
            o2_2 <= (o2_2 > 1) ? o2_2 - 2 : 0;
        end

        S_in_prev <= S_in;
    end
end

endmodule
