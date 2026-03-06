// SNN using IF neurons and STDP
module snn_network #(
    parameter SPIKE_FILE = "data/spikes.mem",
    parameter VCD_NAME = "data/wave.vcd",
    parameter INIT_WEIGHTS_PATH = "data/init_weights.mem",
    parameter TRAINED_PATH_N1 = "data/trained_weights.mem",
    parameter N_SIZE = 784,
    parameter NUM_OUT = 10
)
(
    input  wire               clk,
    input  wire               rst,
    input  wire [N_SIZE-1:0]  S_in,      
    input  wire               train,          // boolean for train or test
    output reg  [12:0]        V [0:NUM_OUT-1], // membrane potentials
    output reg  [NUM_OUT-1:0] spike
);

// constants
parameter V_REST      = 13'd6;
parameter V_THRESHOLD = 13'd65;
parameter K_SYN       = 1;

// 1D Array for weights to easily use $readmemb. 
// Index using: [n * N_SIZE + i]
reg [1:0] weights [0:(NUM_OUT*N_SIZE)-1];

// Shared input spike history traces
reg [N_SIZE-1:0] in_spike_prev1;
reg [N_SIZE-1:0] in_spike_prev2;

// Output spike history traces
reg [NUM_OUT-1:0] out_spike_prev1;
reg [NUM_OUT-1:0] out_spike_prev2;

// Delayed reset flags
reg [NUM_OUT-1:0] need_reset;

// Intermediate weight sums
reg [12:0] wsum [0:NUM_OUT-1];

// Loop variables
integer n, i, j;
integer dw, new_w;

// Initialize weights from .mem file
initial begin
    $readmemb(INIT_WEIGHTS_PATH, weights);
end

// Combinational logic to compute weighted sums
always @(*) begin
    for (n = 0; n < NUM_OUT; n = n + 1) begin
        wsum[n] = 13'd0;
        for (i = 0; i < N_SIZE; i = i + 1) begin
            wsum[n] = wsum[n] + (K_SYN * weights[n * N_SIZE + i] * in_spike_prev1[i]);
        end
    end
end

// Sequential logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (n = 0; n < NUM_OUT; n = n + 1) begin
            V[n] <= V_REST;
            spike[n] <= 1'b0;
            need_reset[n] <= 1'b0;
            out_spike_prev1[n] <= 1'b0;
            out_spike_prev2[n] <= 1'b0;
        end
        in_spike_prev1 <= {N_SIZE{1'b0}};
        in_spike_prev2 <= {N_SIZE{1'b0}};
    end
    else begin
        // 1. NEURON UPDATES
        for (n = 0; n < NUM_OUT; n = n + 1) begin
            if (need_reset[n]) begin
                V[n] <= V_REST;
                spike[n] <= 1'b0;
                need_reset[n] <= 1'b0;
            end
            else begin
                if (V[n] + wsum[n] >= V_THRESHOLD) begin
                    V[n] <= V[n] + wsum[n];
                    spike[n] <= 1'b1;
                    need_reset[n] <= 1'b1;
                end
                else if (V[n] + wsum[n] < V_REST) begin
                    V[n] <= V_REST;
                    spike[n] <= 1'b0;
                end
                else begin
                    V[n] <= V[n] + wsum[n];
                    spike[n] <= 1'b0;
                end
            end
        end

        // 2. LATERAL INHIBITION (Winner-Takes-All)
        // If a neuron crosses the threshold, reset all other neurons
        for (n = 0; n < NUM_OUT; n = n + 1) begin
            if (!need_reset[n] && (V[n] + wsum[n] >= V_THRESHOLD)) begin
                for (j = 0; j < NUM_OUT; j = j + 1) begin
                    if (j != n) begin
                        need_reset[j] <= 1'b1;
                    end
                end
            end
        end

        // 3. STDP WEIGHT UPDATES
        if (train) begin
            for (n = 0; n < NUM_OUT; n = n + 1) begin
                for (i = 0; i < N_SIZE; i = i + 1) begin
                    dw = 0;

                    // Potentiation (post-synaptic spike follows pre-synaptic)
                    if (!need_reset[n] && (V[n] + wsum[n] >= V_THRESHOLD) && in_spike_prev1[i])
                        dw = dw + 2;
                    if (!need_reset[n] && (V[n] + wsum[n] >= V_THRESHOLD) && in_spike_prev2[i])
                        dw = dw + 1;
                        
                    // Depression (pre-synaptic spike follows post-synaptic)
                    if (S_in[i] && out_spike_prev1[n])
                        dw = dw - 2;
                    if (S_in[i] && out_spike_prev2[n])
                        dw = dw - 1;

                    // Calculate new weight and clamp
                    new_w = weights[n * N_SIZE + i] + dw;
                    
                    if (new_w < 0)
                        weights[n * N_SIZE + i] <= 6'd0;
                    else if (new_w > 63)
                        weights[n * N_SIZE + i] <= 6'd63;
                    else
                        weights[n * N_SIZE + i] <= new_w[1:0];
                end
            end
        end

        // 4. SHIFT HISTORY REGISTERS
        in_spike_prev2 <= in_spike_prev1;
        in_spike_prev1 <= S_in;

        for (n = 0; n < NUM_OUT; n = n + 1) begin
            out_spike_prev2[n] <= out_spike_prev1[n];
            if (!need_reset[n] && (V[n] + wsum[n] >= V_THRESHOLD))
                out_spike_prev1[n] <= 1'b1;
            else
                out_spike_prev1[n] <= 1'b0;
        end
    end
end

endmodule