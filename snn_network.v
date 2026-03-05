// SNN using IF neurons and STDP

module snn_network (
    input  wire        clk,
    input  wire        rst,
    input  wire [24:0] S_in,    // input spikes
    input  wire        train,   // boolean to toggle to freeze weights between train and test
    output reg  [7:0]  V1, V2,  // membrane potentials
    output reg         spike1, spike2
);

// constants
parameter V_REST      = 8'd6;
parameter V_THRESHOLD = 8'd65;
parameter K_SYN       = 1;

// weight arrays for the two output neuron synapses (each connected to 25 input neurons)
reg [1:0] w1 [0:24];
reg [1:0] w2 [0:24];

// spike history traces (two steps back; shift registers)
reg [24:0] in_spike_prev1_n1, in_spike_prev2_n1;  // tracks what S_in was one and two cycles ago for potentiation after output neuron 1 fires
reg [24:0] in_spike_prev1_n2, in_spike_prev2_n2;  // tracks what S_in was one and two cycles ago for potentiation after output neuron 2 fires
reg        out1_spike_prev1, out1_spike_prev2;  // tracks if output neuron 1 spike one or two cycles ago for depression after an input spike
reg        out2_spike_prev1, out2_spike_prev2;  // tracks if output neuron 2 spike one or two cycles ago for depression after an input spike

// delayed reset flags
reg need_reset_1, need_reset_2;

// wires to calculate intermediate weight sums
reg [7:0] wsum1, wsum2;
integer i;

// initial weight maps
initial begin
    // Output neuron 1: 
    // {1,0,0,1,2,
    //  0,3,2,3,0,
    //  2,2,1,3,3, 
    //  1,3,0,0,2, 
    //  3,1,1,0,1}

    w1[0] = 2'd1; 
    w1[1] = 2'd0; 
    w1[2] = 2'd0; 
    w1[3] = 2'd1; 
    w1[4] = 2'd2;
    w1[5] = 2'd0; 
    w1[6] = 2'd3; 
    w1[7] = 2'd2; 
    w1[8] = 2'd3; 
    w1[9] = 2'd0;
    w1[10] = 2'd2; 
    w1[11] = 2'd2; 
    w1[12] = 2'd1; 
    w1[13] = 2'd3; 
    w1[14] = 2'd3;
    w1[15] = 2'd1; 
    w1[16] = 2'd3; 
    w1[17] = 2'd0; 
    w1[18] = 2'd0; 
    w1[19] = 2'd2;
    w1[20] = 2'd3; 
    w1[21] = 2'd1; 
    w1[22] = 2'd1; 
    w1[23] = 2'd0; 
    w1[24] = 2'd1;

    // Output neuron 2: 
    // {0,2,3,0,1, 
    //  2,0,2,0,0, 
    //  1,2,3,1,2, 
    //  0,1,1,0,1, 
    //  2,3,1,3,0}

    w2[0] = 2'd0; 
    w2[1] = 2'd2; 
    w2[2] = 2'd3; 
    w2[3] = 2'd0; 
    w2[4] = 2'd1;
    w2[5] = 2'd2; 
    w2[6] = 2'd0; 
    w2[7] = 2'd2; 
    w2[8] = 2'd0; 
    w2[9] = 2'd0;
    w2[10] = 2'd1; 
    w2[11] = 2'd2; 
    w2[12] = 2'd3; 
    w2[13] = 2'd1; 
    w2[14] = 2'd2;
    w2[15] = 2'd0; 
    w2[16] = 2'd1; 
    w2[17] = 2'd1; 
    w2[18] = 2'd0; 
    w2[19] = 2'd1;
    w2[20] = 2'd2; 
    w2[21] = 2'd3; 
    w2[22] = 2'd1; 
    w2[23] = 2'd3; 
    w2[24] = 2'd0;
end

// combinational to compute weighted sums
always @(*) begin
    wsum1 = 8'd0;
    wsum2 = 8'd0;
    for (i = 0; i < 25; i = i + 1) begin
        wsum1 = wsum1 + (K_SYN * w1[i] * in_spike_prev1_n1[i]);
        wsum2 = wsum2 + (K_SYN * w2[i] * in_spike_prev1_n2[i]);
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
        in_spike_prev1_n1 <= 25'b0;
        in_spike_prev2_n1 <= 25'b0;
        in_spike_prev1_n2 <= 25'b0;
        in_spike_prev2_n2 <= 25'b0;
        out1_spike_prev1 <= 1'b0;
        out1_spike_prev2 <= 1'b0;
        out2_spike_prev1 <= 1'b0;
        out2_spike_prev2 <= 1'b0;
    end
    else begin
        // CASE 1: Neuron 1 update
        if (need_reset_1) begin
            V1 <= V_REST;
            spike1 <= 1'b0;
            need_reset_1 <= 1'b0;
        end
        else begin
            // if spike, set flag for reset in cycle n+1
            if (V1 + wsum1 >= V_THRESHOLD) begin
                V1 <= V1 + wsum1;
                spike1 <= 1'b1;
                need_reset_1 <= 1'b1;
            end
            // clamp membrane potential to the resting value
            else if (V1 + wsum1 < V_REST) begin
                V1 <= V_REST;
                spike1 <= 1'b0;
            end
            // simple increment by weight sum
            else begin
                V1 <= V1 + wsum1;
                spike1 <= 1'b0;
            end
        end

        // CASE 2: Neuron 2 update
        if (need_reset_2) begin
            V2 <= V_REST;
            spike2 <= 1'b0;
            need_reset_2 <= 1'b0;
        end
        else begin
            // if spike, set flag for reset in cycle n+1
            if (V2 + wsum2 >= V_THRESHOLD) begin
                V2 <= V2 + wsum2;
                spike2 <= 1'b1;
                need_reset_2 <= 1'b1;
            end
            // clamp membrane potential to the resting value
            else if (V2 + wsum2 < V_REST) begin
                V2 <= V_REST;
                spike2 <= 1'b0;
            end
            // simple increment by weight sum
            else begin
                V2 <= V2 + wsum2;
                spike2 <= 1'b0;
            end
        end

        // lateral inhibition: if neuron 1 fires alone, reset neuron 2 next cycle
        if (!need_reset_1 && (V1 + wsum1 >= V_THRESHOLD) &&
            (need_reset_2 || !(V2 + wsum2 >= V_THRESHOLD))) begin
            // make sure flag wasn't already set
            if (!need_reset_2)
                need_reset_2 <= 1'b1;
        end

        // lateral inhibition: if neuron 2 fires alone, reset neuron 1 next cycle
        if (!need_reset_2 && (V2 + wsum2 >= V_THRESHOLD) &&
            (need_reset_1 || !(V1 + wsum1 >= V_THRESHOLD))) begin
            if (!need_reset_1)
                need_reset_1 <= 1'b1;
        end

        // STDP weight updates
        if (train) begin
            for (i = 0; i < 25; i = i + 1) begin : stdp_loop
                reg signed [3:0] dw1, dw2;
                reg signed [4:0] new_w1, new_w2;

                // NEURON 1
                dw1 = 4'sd0;

                // CASE 1: if postsynaptic spike & presynaptic spike 1 cycle ago, then potentiate +2
                if (!need_reset_1 && (V1 + wsum1 >= V_THRESHOLD) && in_spike_prev1_n1[i])
                    dw1 = dw1 + 4'sd2;
                // CASE 2: if postsynaptic spike & presynaptic spike 2 cycle ago, then potentiate +1
                if (!need_reset_1 && (V1 + wsum1 >= V_THRESHOLD) && in_spike_prev2_n1[i])
                    dw1 = dw1 + 4'sd1;
                // CASE 3: if presynaptic spike & postsynaptic spike 1 cycle ago, then potentiate +2
                if (S_in[i] && out1_spike_prev1)
                    dw1 = dw1 - 4'sd2;
                // CASE 4: if presynaptic spike & postsynaptic spike 2 cycle ago, then potentiate +1
                if (S_in[i] && out1_spike_prev2)
                    dw1 = dw1 - 4'sd1;

                // handle overflow by adding 0 bit to w1 and new_w1 is 5 bits signed
                new_w1 = $signed({1'b0, w1[i]}) + dw1;

                // clamp weights to zero if negative
                if (new_w1 < 0)
                    w1[i] <= 2'd0;
                // clamp to 3 if above
                else if (new_w1 > 3)
                    w1[i] <= 2'd3;
                //use bottom two bits regularly
                else
                    w1[i] <= new_w1[1:0];

                // NEURON 2
                dw2 = 4'sd0;

                // CASE 1: if postsynaptic spike & presynaptic spike 1 cycle ago, then potentiate +2
                if (!need_reset_2 && (V2 + wsum2 >= V_THRESHOLD) && in_spike_prev1_n2[i])
                    dw2 = dw2 + 4'sd2;
                // CASE 2: if postsynaptic spike & presynaptic spike 2 cycle ago, then potentiate +1
                if (!need_reset_2 && (V2 + wsum2 >= V_THRESHOLD) && in_spike_prev2_n2[i])
                    dw2 = dw2 + 4'sd1;
                // CASE 3: if presynaptic spike & postsynaptic spike 1 cycle ago, then potentiate +2
                if (S_in[i] && out2_spike_prev1)
                    dw2 = dw2 - 4'sd2;
                // CASE 4: if presynaptic spike & postsynaptic spike 2 cycle ago, then potentiate +1
                if (S_in[i] && out2_spike_prev2)
                    dw2 = dw2 - 4'sd1;

                // handle overflow and clamping
                new_w2 = $signed({1'b0, w2[i]}) + dw2;
                if (new_w2 < 0)
                    w2[i] <= 2'd0;
                else if (new_w2 > 3)
                    w2[i] <= 2'd3;
                else
                    w2[i] <= new_w2[1:0];
            end
        end

        // shift spike histroy registers

        // INPUT HISTORY (POTENTIATION)
        // neuron 1 shift in from S_in
        in_spike_prev2_n1 <= in_spike_prev1_n1;
        in_spike_prev1_n1 <= S_in;

        // neuron 2 shift in from S_in
        in_spike_prev2_n2 <= in_spike_prev1_n2;
        in_spike_prev1_n2 <= S_in;

        // OUTPUT HISTORY (DEPRESSION)
        // check if output neuron 1 generated a spike this cycle and shift in a 1
        if (!need_reset_1 && (V1 + wsum1 >= V_THRESHOLD)) begin
            out1_spike_prev2 <= out1_spike_prev1;
            out1_spike_prev1 <= 1'b1;
        end
        // if no spike, shift in a 0
        else begin
            out1_spike_prev2 <= out1_spike_prev1;
            out1_spike_prev1 <= 1'b0;
        end

        // check if output neuron 2 generated a spike this cycle and shift in a 1
        if (!need_reset_2 && (V2 + wsum2 >= V_THRESHOLD)) begin
            out2_spike_prev2 <= out2_spike_prev1;
            out2_spike_prev1 <= 1'b1;
        end
        // if no spike, shift in a 0
        else begin
            out2_spike_prev2 <= out2_spike_prev1;
            out2_spike_prev1 <= 1'b0;
        end
    end
end

endmodule
