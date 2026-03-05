`timescale 1ns / 1ps

module snn_stdp (
    input  wire        clk,
    input  wire        rst,          // Resets V_mem, spike state, history; NOT weights
    input  wire        train_en,     // 1 = training (STDP active), 0 = testing
    input  wire [24:0] S_in,         // N_SYN input spikes (S_in[0]=pixel0 ... S_in[24]=pixel24)
    output reg  [7:0]  V_mem1,       // Output neuron 1 membrane potential
    output reg  [7:0]  V_mem2,       // Output neuron 2 membrane potential
    output reg         spike_out1,   // Output neuron 1 spike
    output reg         spike_out2    // Output neuron 2 spike
);

    // IF neuron parameters (no leak)
    localparam [7:0] V_REST  = 8'd6;
    localparam [7:0] V_THETA = 8'd65;
    localparam       N_SYN   = 25;  // Number of input synapses (5x5 pixel grid)

    // Weight storage: N_SYN synapses per output neuron, 2-bit each (0-3)
    reg [1:0] w1 [0:N_SYN-1];       // Weights to output neuron 1
    reg [1:0] w2 [0:N_SYN-1];       // Weights to output neuron 2

    // Spike history for STDP
    reg [N_SYN-1:0] S_in_prev1;     // Input spikes 1 cycle ago
    reg [N_SYN-1:0] S_in_prev2;     // Input spikes 2 cycles ago
    reg        spike1_prev1;        // Output neuron 1 spike 1 cycle ago
    reg        spike1_prev2;        // Output neuron 1 spike 2 cycles ago
    reg        spike2_prev1;        // Output neuron 2 spike 1 cycle ago
    reg        spike2_prev2;        // Output neuron 2 spike 2 cycles ago

    // Lateral inhibition pending flags
    reg inhibit1_pending;
    reg inhibit2_pending;

    // Combinational intermediates
    reg [7:0] I_syn1, I_syn2;
    reg [8:0] V_new1, V_new2;       // 9 bits for safe addition
    reg       fire1, fire2;

    // STDP intermediates
    reg signed [4:0] dw1, dw2;
    reg signed [4:0] new_w1_s, new_w2_s;

    integer k;

    // Weight initialization (NOT reset by rst)
    // Layout matches Fig. 3 as a 5x5 grid (row-major, top-to-bottom)
    initial begin
        // Output neuron 1 weights (Fig. 3)
        w1[ 0]=2'd1; w1[ 1]=2'd0; w1[ 2]=2'd0; w1[ 3]=2'd1; w1[ 4]=2'd2;
        w1[ 5]=2'd0; w1[ 6]=2'd3; w1[ 7]=2'd2; w1[ 8]=2'd3; w1[ 9]=2'd0;
        w1[10]=2'd2; w1[11]=2'd2; w1[12]=2'd1; w1[13]=2'd3; w1[14]=2'd3;
        w1[15]=2'd1; w1[16]=2'd3; w1[17]=2'd0; w1[18]=2'd0; w1[19]=2'd2;
        w1[20]=2'd3; w1[21]=2'd1; w1[22]=2'd1; w1[23]=2'd0; w1[24]=2'd1;

        // Output neuron 2 weights (Fig. 3)
        w2[ 0]=2'd0; w2[ 1]=2'd2; w2[ 2]=2'd3; w2[ 3]=2'd0; w2[ 4]=2'd1;
        w2[ 5]=2'd2; w2[ 6]=2'd0; w2[ 7]=2'd2; w2[ 8]=2'd0; w2[ 9]=2'd0;
        w2[10]=2'd1; w2[11]=2'd2; w2[12]=2'd3; w2[13]=2'd1; w2[14]=2'd2;
        w2[15]=2'd0; w2[16]=2'd1; w2[17]=2'd1; w2[18]=2'd0; w2[19]=2'd1;
        w2[20]=2'd2; w2[21]=2'd3; w2[22]=2'd1; w2[23]=2'd3; w2[24]=2'd0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            V_mem1       <= V_REST;
            V_mem2       <= V_REST;
            spike_out1   <= 1'b0;
            spike_out2   <= 1'b0;
            S_in_prev1   <= {N_SYN{1'b0}};
            S_in_prev2   <= {N_SYN{1'b0}};
            spike1_prev1 <= 1'b0;
            spike1_prev2 <= 1'b0;
            spike2_prev1 <= 1'b0;
            spike2_prev2 <= 1'b0;
            inhibit1_pending <= 1'b0;
            inhibit2_pending <= 1'b0;
        end else begin

            // STEP 1: Compute synaptic currents (blocking)
            // I_syn = K_SYN * sum(w_ij * S_j), K_SYN = 1
            // Uses the spikes 1 cycle ago
            I_syn1 = 8'd0;
            I_syn2 = 8'd0;
            for (k = 0; k < N_SYN; k = k + 1) begin
                if (S_in_prev1[k]) begin
                    I_syn1 = I_syn1 + {6'b0, w1[k]};
                    I_syn2 = I_syn2 + {6'b0, w2[k]};
                end
            end

            // STEP 2: Compute V_new
            // If pending reset (fired or inhibited last cycle): V_new = V_REST + I_syn
            // Otherwise: V_new = V_mem + I_syn
            // Make sure to allow for bit addition overflow
            if (spike_out1 || inhibit1_pending)
                V_new1 = {1'b0, V_REST} + {1'b0, I_syn1};
            else
                V_new1 = {1'b0, V_mem1} + {1'b0, I_syn1};

            if (spike_out2 || inhibit2_pending)
                V_new2 = {1'b0, V_REST} + {1'b0, I_syn2};
            else
                V_new2 = {1'b0, V_mem2} + {1'b0, I_syn2};

            // STEP 3: Threshold check (blocking)
            fire1 = (V_new1 >= {1'b0, V_THETA});
            fire2 = (V_new2 >= {1'b0, V_THETA});

            // STEP 4: Update V_mem and spike_out
            // On fire: maintain V_new (reset happens next cycle)
            if (fire1) begin
                V_mem1     <= V_new1[7:0];
                spike_out1 <= 1'b1;
            end else begin
                V_mem1     <= V_new1[7:0];
                spike_out1 <= 1'b0;
            end

            if (fire2) begin
                V_mem2     <= V_new2[7:0];
                spike_out2 <= 1'b1;
            end else begin
                V_mem2     <= V_new2[7:0];
                spike_out2 <= 1'b0;
            end

            // STEP 5: Lateral inhibition (sets flags for next cycle)
            // Only one fires -> inhibit the other
            // Both fire or neither -> no inhibition
            if (fire1 && !fire2) begin
                inhibit2_pending <= 1'b1;
                inhibit1_pending <= 1'b0;
            end else if (!fire1 && fire2) begin
                inhibit1_pending <= 1'b1;
                inhibit2_pending <= 1'b0;
            end else begin
                inhibit1_pending <= 1'b0;
                inhibit2_pending <= 1'b0;
            end

            // STEP 6: Update spike history (shift registers)
            S_in_prev2   <= S_in_prev1;
            S_in_prev1   <= S_in;
            spike1_prev2 <= spike1_prev1;
            spike1_prev1 <= fire1;
            spike2_prev2 <= spike2_prev1;
            spike2_prev1 <= fire2;

            // STEP 7: STDP weight updates (training only)
            // dt = t_post - t_pre
            //   dt=+1: dw=+2
            //   dt=+2: dw=+1
            //   dt=-1: dw=-2
            //   dt=-2: dw=-1
            if (train_en) begin
                for (k = 0; k < N_SYN; k = k + 1) begin
                    // --- Output neuron 1 ---
                    // Update weights with STDP curve values
                    dw1 = 5'sd0;
                    if (fire1) begin
                        if (S_in_prev1[k]) dw1 = dw1 + 5'sd2;
                        if (S_in_prev2[k]) dw1 = dw1 + 5'sd1;
                    end
                    if (S_in[k]) begin
                        if (spike1_prev1) dw1 = dw1 - 5'sd2;
                        if (spike1_prev2) dw1 = dw1 - 5'sd1;
                    end

                    // If nonzero dw, update the weight and clamp to [0:3]
                    if (dw1 != 5'sd0) begin
                        new_w1_s = $signed({3'b0, w1[k]}) + dw1;
                        if (new_w1_s > 5'sd3)
                            w1[k] <= 2'd3;
                        else if (new_w1_s < 5'sd0)
                            w1[k] <= 2'd0;
                        else
                            w1[k] <= new_w1_s[1:0];
                    end

                    // --- Output neuron 2 ---
                    // Update weights with STDP curve values
                    dw2 = 5'sd0;
                    if (fire2) begin
                        if (S_in_prev1[k]) dw2 = dw2 + 5'sd2;
                        if (S_in_prev2[k]) dw2 = dw2 + 5'sd1;
                    end
                    if (S_in[k]) begin
                        if (spike2_prev1) dw2 = dw2 - 5'sd2;
                        if (spike2_prev2) dw2 = dw2 - 5'sd1;
                    end

                    // If nonzero dw, update the weight and clamp to [0:3]
                    if (dw2 != 5'sd0) begin
                        new_w2_s = $signed({3'b0, w2[k]}) + dw2;
                        if (new_w2_s > 5'sd3)
                            w2[k] <= 2'd3;
                        else if (new_w2_s < 5'sd0)
                            w2[k] <= 2'd0;
                        else
                            w2[k] <= new_w2_s[1:0];
                    end
                end
            end

        end
    end

endmodule
