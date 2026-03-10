// Triplet SNN using LIF neurons and Triplet STDP
// Based on Pfister & Gerstner (2006) triplet STDP rule
// Supports both all-to-all (MODE=0) and nearest-neighbor (MODE=1) modes

module triplet_snn (
    input  wire        clk,
    input  wire        rst,
    input  wire [24:0] S_in,    // input spikes
    input  wire        train,   // toggle to freeze weights between train and test
    output reg  [9:0]  V1, V2,  // membrane potentials (widened to match 4-bit weight range)
    output reg         spike1, spike2
);

// neuron parameters (scaled by 4x to match 4-bit weights without lossy W_SCALE)
parameter V_REST      = 10'd24;   // 6 * 4
parameter V_THRESHOLD = 10'd260;  // 65 * 4
parameter K_SYN       = 1;
parameter V_LEAK      = 10'd4;    // 1 * 4

// triplet STDP parameters
parameter MODE      = 0;      // 0 = all-to-all, 1 = nearest-neighbor
parameter A2_PLUS   = 4'd1;   // pair-based LTP magnitude
parameter A2_MINUS  = 4'd3;   // pair-based LTD magnitude
parameter A3_PLUS   = 4'd1;   // triplet LTP magnitude (modulated by o2)
parameter A3_MINUS  = 4'd4;   // triplet LTD magnitude (modulated by r2)
parameter DW_SCALE  = 2;      // right-shift to scale weight updates
parameter TRACE_INC = 8;      // trace increment for all-to-all mode (unsized to avoid 4-bit overflow in saturating add)

// 4-bit weight arrays (0-15 range for finer STDP granularity)
reg [3:0] w1 [0:24];
reg [3:0] w2 [0:24];

// pre-synaptic traces (shared across output neurons, driven by S_in)
reg [3:0] r1 [0:24];   // fast pre-synaptic trace (decays by >>1 each cycle)
reg [3:0] r2 [0:24];   // slow pre-synaptic trace (decays by -2 each cycle)

// post-synaptic traces (per output neuron)
reg [3:0] o1_1, o1_2;  // fast post-synaptic trace (decays by >>1)
reg [3:0] o2_1, o2_2;  // slow post-synaptic trace (decays by -2)

// 1-cycle delayed input for weighted sum (matches original behavior)
reg [24:0] S_in_prev;

// delayed reset flags
reg need_reset_1, need_reset_2;

// weighted sums (9-bit: max 15 * 25 = 375)
reg [8:0] wsum1, wsum2;
integer i;

// spike detection (post-leak threshold check)
wire spike1_now = !need_reset_1 && (V1 + wsum1 >= V_THRESHOLD + V_LEAK);
wire spike2_now = !need_reset_2 && (V2 + wsum2 >= V_THRESHOLD + V_LEAK);

// initial weight maps (scaled by 4x from original 2-bit values)
initial begin
    // Output neuron 1:
    // original: {1,0,0,1,2, 0,3,2,3,0, 2,2,1,3,3, 1,3,0,0,2, 3,1,1,0,1}
    w1[0] = 4'd4;  w1[1] = 4'd0;  w1[2] = 4'd0;  w1[3] = 4'd4;  w1[4] = 4'd8;
    w1[5] = 4'd0;  w1[6] = 4'd12; w1[7] = 4'd8;  w1[8] = 4'd12; w1[9] = 4'd0;
    w1[10] = 4'd8;  w1[11] = 4'd8;  w1[12] = 4'd4;  w1[13] = 4'd12; w1[14] = 4'd12;
    w1[15] = 4'd4;  w1[16] = 4'd12; w1[17] = 4'd0;  w1[18] = 4'd0;  w1[19] = 4'd8;
    w1[20] = 4'd12; w1[21] = 4'd4;  w1[22] = 4'd4;  w1[23] = 4'd0;  w1[24] = 4'd4;

    // Output neuron 2:
    // original: {0,2,3,0,1, 2,0,2,0,0, 1,2,3,1,2, 0,1,1,0,1, 2,3,1,3,0}
    w2[0] = 4'd0;  w2[1] = 4'd8;  w2[2] = 4'd12; w2[3] = 4'd0;  w2[4] = 4'd4;
    w2[5] = 4'd8;  w2[6] = 4'd0;  w2[7] = 4'd8;  w2[8] = 4'd0;  w2[9] = 4'd0;
    w2[10] = 4'd4;  w2[11] = 4'd8;  w2[12] = 4'd12; w2[13] = 4'd4;  w2[14] = 4'd8;
    w2[15] = 4'd0;  w2[16] = 4'd4;  w2[17] = 4'd4;  w2[18] = 4'd0;  w2[19] = 4'd4;
    w2[20] = 4'd8;  w2[21] = 4'd12; w2[22] = 4'd4;  w2[23] = 4'd12; w2[24] = 4'd0;
end

// combinational weighted sums (uses 1-cycle delayed input, same as original)
always @(*) begin
    wsum1 = 9'd0;
    wsum2 = 9'd0;
    for (i = 0; i < 25; i = i + 1) begin
        wsum1 = wsum1 + (K_SYN * w1[i] * S_in_prev[i]);
        wsum2 = wsum2 + (K_SYN * w2[i] * S_in_prev[i]);
    end
end

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
        o1_1 <= 4'd0;
        o1_2 <= 4'd0;
        o2_1 <= 4'd0;
        o2_2 <= 4'd0;
        for (i = 0; i < 25; i = i + 1) begin
            r1[i] <= 4'd0;
            r2[i] <= 4'd0;
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
        // if neuron 1 fires alone, reset neuron 2 next cycle
        if (!need_reset_1 && spike1_now &&
            (need_reset_2 || !spike2_now)) begin
            if (!need_reset_2)
                need_reset_2 <= 1'b1;
        end
        // if neuron 2 fires alone, reset neuron 1 next cycle
        if (!need_reset_2 && spike2_now &&
            (need_reset_1 || !spike1_now)) begin
            if (!need_reset_1)
                need_reset_1 <= 1'b1;
        end

        // --- Triplet STDP weight updates ---
        // Potentiation (on post spike): dw+ = r1[i] * (A2+ + A3+ * (r1[i] * o2) >> 4)
        //   - fast pre trace gates the update
        //   - slow post trace provides triplet modulation
        // Depression (on pre spike):    dw- = o1 * (A2- + A3- * (o1 * r2[i]) >> 4)
        //   - fast post trace gates the update
        //   - slow pre trace provides triplet modulation
        if (train) begin
            for (i = 0; i < 25; i = i + 1) begin : stdp_loop
                reg [11:0] pot_raw1, dep_raw1;
                reg [11:0] pot_raw2, dep_raw2;
                reg [3:0]  pot_scaled1, dep_scaled1;
                reg [3:0]  pot_scaled2, dep_scaled2;
                reg signed [5:0] dw1, dw2;
                reg signed [5:0] new_w1, new_w2;

                // NEURON 1
                pot_raw1 = 12'd0;
                dep_raw1 = 12'd0;

                // potentiation: on post spike, proportional to fast pre trace, modulated by slow post trace
                if (spike1_now)
                    pot_raw1 = r1[i] * A2_PLUS + ((r1[i] * o2_1) >> 4) * A3_PLUS;

                // depression: on pre spike, proportional to fast post trace, modulated by slow pre trace
                if (S_in[i])
                    dep_raw1 = o1_1 * A2_MINUS + ((o1_1 * r2[i]) >> 4) * A3_MINUS;

                // scale and clamp to 4-bit unsigned before computing signed delta
                pot_scaled1 = (pot_raw1 >> DW_SCALE > 12'd15) ? 4'd15 : pot_raw1[3+DW_SCALE:DW_SCALE];
                dep_scaled1 = (dep_raw1 >> DW_SCALE > 12'd15) ? 4'd15 : dep_raw1[3+DW_SCALE:DW_SCALE];

                dw1 = $signed({1'b0, pot_scaled1}) - $signed({1'b0, dep_scaled1});
                new_w1 = $signed({2'b0, w1[i]}) + dw1;

                if (new_w1 < 0)
                    w1[i] <= 4'd0;
                else if (new_w1 > 15)
                    w1[i] <= 4'd15;
                else
                    w1[i] <= new_w1[3:0];

                // NEURON 2
                pot_raw2 = 12'd0;
                dep_raw2 = 12'd0;

                if (spike2_now)
                    pot_raw2 = r1[i] * A2_PLUS + ((r1[i] * o2_2) >> 4) * A3_PLUS;

                if (S_in[i])
                    dep_raw2 = o1_2 * A2_MINUS + ((o1_2 * r2[i]) >> 4) * A3_MINUS;

                pot_scaled2 = (pot_raw2 >> DW_SCALE > 12'd15) ? 4'd15 : pot_raw2[3+DW_SCALE:DW_SCALE];
                dep_scaled2 = (dep_raw2 >> DW_SCALE > 12'd15) ? 4'd15 : dep_raw2[3+DW_SCALE:DW_SCALE];

                dw2 = $signed({1'b0, pot_scaled2}) - $signed({1'b0, dep_scaled2});
                new_w2 = $signed({2'b0, w2[i]}) + dw2;

                if (new_w2 < 0)
                    w2[i] <= 4'd0;
                else if (new_w2 > 15)
                    w2[i] <= 4'd15;
                else
                    w2[i] <= new_w2[3:0];
            end
        end

        // --- Update pre-synaptic traces ---
        for (i = 0; i < 25; i = i + 1) begin : trace_pre_update
            // fast pre trace (r1): fast decay via >>1, bump on input spike
            if (S_in[i]) begin
                if (MODE == 1)  // nearest-neighbor: reset to single-spike value
                    r1[i] <= TRACE_INC;
                else            // all-to-all: saturating add
                    r1[i] <= (r1[i] + TRACE_INC > 4'd15) ? 4'd15 : r1[i] + TRACE_INC;
            end
            else begin
                r1[i] <= r1[i] >> 1;
            end

            // slow pre trace (r2): slow decay via -2, bump on input spike
            if (S_in[i]) begin
                if (MODE == 1)
                    r2[i] <= TRACE_INC;
                else
                    r2[i] <= (r2[i] + TRACE_INC > 4'd15) ? 4'd15 : r2[i] + TRACE_INC;
            end
            else begin
                r2[i] <= (r2[i] > 4'd1) ? r2[i] - 4'd2 : 4'd0;
            end
        end

        // --- Update post-synaptic traces ---
        // Neuron 1
        if (spike1_now) begin
            if (MODE == 1) begin
                o1_1 <= TRACE_INC;
                o2_1 <= TRACE_INC;
            end
            else begin
                o1_1 <= (o1_1 + TRACE_INC > 4'd15) ? 4'd15 : o1_1 + TRACE_INC;
                o2_1 <= (o2_1 + TRACE_INC > 4'd15) ? 4'd15 : o2_1 + TRACE_INC;
            end
        end
        else begin
            o1_1 <= o1_1 >> 1;
            o2_1 <= (o2_1 > 4'd1) ? o2_1 - 4'd2 : 4'd0;
        end

        // Neuron 2
        if (spike2_now) begin
            if (MODE == 1) begin
                o1_2 <= TRACE_INC;
                o2_2 <= TRACE_INC;
            end
            else begin
                o1_2 <= (o1_2 + TRACE_INC > 4'd15) ? 4'd15 : o1_2 + TRACE_INC;
                o2_2 <= (o2_2 + TRACE_INC > 4'd15) ? 4'd15 : o2_2 + TRACE_INC;
            end
        end
        else begin
            o1_2 <= o1_2 >> 1;
            o2_2 <= (o2_2 > 4'd1) ? o2_2 - 4'd2 : 4'd0;
        end

        // shift delayed input
        S_in_prev <= S_in;
    end
end

endmodule
