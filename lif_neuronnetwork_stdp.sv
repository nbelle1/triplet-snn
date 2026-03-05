module lif_neuronnetwork_stdp #(
    parameter int N_IN = 25,
    parameter int V_REST = 6,
    parameter int V_TH = 65,
    parameter int STDP_WINDOW = 3,
    parameter int STDP_INC = 1,
    parameter int STDP_DEC = 1
) (
    input  logic                   clk,
    input  logic                   rst,
    input  logic                   train_en,
    input  logic [N_IN-1:0]        in_spikes,
    output logic [7:0]             V_out1,
    output logic [7:0]             V_out2,
    output logic                   spike_out1,
    output logic                   spike_out2,
    output logic [6:0]             fire_count1,
    output logic [6:0]             fire_count2
);
    logic [1:0] w1 [0:N_IN-1];
    logic [1:0] w2 [0:N_IN-1];
    logic [4:0] pre_age [0:N_IN-1];
    logic [4:0] post_age1;
    logic [4:0] post_age2;
    logic       reset_pending1;
    logic       reset_pending2;

    integer i;
    always_ff @(posedge clk or posedge rst) begin
        int sum1;
        int sum2;
        int v1_base;
        int v2_base;
        int v1_next;
        int v2_next;
        logic s1_new;
        logic s2_new;
        int nw1;
        int nw2;
        if (rst) begin
            V_out1 <= V_REST[7:0];
            V_out2 <= V_REST[7:0];
            spike_out1 <= 1'b0;
            spike_out2 <= 1'b0;
            fire_count1 <= '0;
            fire_count2 <= '0;
            reset_pending1 <= 1'b0;
            reset_pending2 <= 1'b0;
            post_age1 <= 5'd31;
            post_age2 <= 5'd31;

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

        end else begin
            sum1 = 0;
            sum2 = 0;
            for (i = 0; i < N_IN; i = i + 1) begin
                if (in_spikes[i]) begin
                    sum1 = sum1 + w1[i];
                    sum2 = sum2 + w2[i];
                end
            end

            v1_base = reset_pending1 ? V_REST : V_out1;
            v2_base = reset_pending2 ? V_REST : V_out2;
            v1_next = v1_base + sum1;
            v2_next = v2_base + sum2;

            if (v1_next < V_REST) v1_next = V_REST;
            if (v2_next < V_REST) v2_next = V_REST;

            s1_new = (v1_next >= V_TH);
            s2_new = (v2_next >= V_TH);

            spike_out1 <= s1_new;
            spike_out2 <= s2_new;
            V_out1 <= v1_next[7:0];
            V_out2 <= v2_next[7:0];

            if (s1_new) fire_count1 <= fire_count1 + 1'b1;
            if (s2_new) fire_count2 <= fire_count2 + 1'b1;

            // If one neuron spikes alone, reset the other at the next cycle.
            // If both spike together, no lateral inhibition.
            reset_pending1 <= s1_new || (s2_new && !s1_new);
            reset_pending2 <= s2_new || (s1_new && !s2_new);

            for (i = 0; i < N_IN; i = i + 1) begin
                nw1 = w1[i];
                nw2 = w2[i];
                if (train_en) begin
                    // LTD rule: on an input spike, decrease by post age.
                    if (in_spikes[i]) begin
                        if      (post_age1 == 1) nw1 -= 2;
                        else if (post_age1 == 2) nw1 -= 1;

                        if      (post_age2 == 1) nw2 -= 2; 
                        else if (post_age2 == 2) nw2 -= 1;
                    end

                    // LTP rule: on an output spike, increase by pre age.
                    if (s1_new) begin
                        if      (pre_age[i] == 1) nw1 += 2;
                        else if (pre_age[i] == 2) nw1 += 1;
                    end
                    if (s2_new) begin
                        if      (pre_age[i] == 1) nw2 += 2;
                        else if (pre_age[i] == 2) nw2 += 1;
                    end
                end

                if (nw1 > 3) nw1 = 3;
                if (nw2 > 3) nw2 = 3;
                if (nw1 < 0) nw1 = 0;
                if (nw2 < 0) nw2 = 0;

                w1[i] <= nw1;
                w2[i] <= nw2;

                if (in_spikes[i]) pre_age[i] <= 5'd0;
                else if (pre_age[i] != 5'd31) pre_age[i] <= pre_age[i] + 1'b1;
            end

            if (s1_new) post_age1 <= 5'd0;
            else if (post_age1 != 5'd31) post_age1 <= post_age1 + 1'b1;

            if (s2_new) post_age2 <= 5'd0;
            else if (post_age2 != 5'd31) post_age2 <= post_age2 + 1'b1;
        end
    end

endmodule
