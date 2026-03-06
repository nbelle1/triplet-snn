// testbench for Dynamic SNN; perform training and testing in one run
// Set W_BITS via -DW_BITS=2 or -DW_BITS=4 at compile time (default: 4)

`timescale 1ns/1ps

`ifndef W_BITS
`define W_BITS 4
`endif

module dynamic_snn_tb;

localparam W_BITS = `W_BITS;
localparam V_BITS = W_BITS + 6;

// signals
reg              clk, rst;
reg [24:0]       S_in;
reg              train;
wire [V_BITS-1:0] V1, V2;
wire             spike1, spike2;

// spike patterns for each color pixel (40 bits each, MSB first)
// bursty patterns to showcase triplet STDP (pre-post-pre / post-pre-post)
// BLACK: bursts of 2 every 5 cycles (16 spikes in 40 steps)
// WHITE: single spikes every 10 cycles (4 spikes in 40 steps)
localparam [39:0] WHITE = 40'b1000000000100000000010000000001000000000;
localparam [39:0] BLACK = 40'b1100110000001100110000001100110000001100;

// zero training image
localparam [24:0] TRAIN_0 = 25'b00000_01110_01010_01110_00000;

// one training image
localparam [24:0] TRAIN_1 = 25'b01100_00100_00100_00100_01110;

// zero testing image
localparam [24:0] TEST_0  = 25'b00000_01010_01010_01110_00000;

// one testing image
localparam [24:0] TEST_1  = 25'b01100_00100_00100_00100_00100;

// spike firing counters
integer count1, count2;

// instantiate dut with parameterized weight precision
snn_dynamic #(.W_BITS(W_BITS)) dut (
    .clk(clk),
    .rst(rst),
    .S_in(S_in),
    .train(train),
    .V1(V1),
    .V2(V2),
    .spike1(spike1),
    .spike2(spike2)
);

// clock
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

// task: generate spike input for one timestep from an image
task apply_image_timestep;
    input [24:0] image;
    input integer step;
    integer p;
    begin
        for (p = 0; p < 25; p = p + 1) begin
            if (image[24 - p])
                S_in[p] = BLACK[39 - step];
            else
                S_in[p] = WHITE[39 - step];
        end
    end
endtask

// task: print weights in parseable format
task print_weights;
    input [80*8:1] label;
    integer wi;
    begin
        $write("%0s W1:", label);
        for (wi = 0; wi < 25; wi = wi + 1)
            $write(" %0d", dut.w1[wi]);
        $write("\n");
        $write("%0s W2:", label);
        for (wi = 0; wi < 25; wi = wi + 1)
            $write(" %0d", dut.w2[wi]);
        $write("\n");
    end
endtask

// task: run one phase
task run_phase;
    input [80*8:1] phase_name;
    input [24:0]   image;
    input          is_train;
    integer step;
    begin
        $display("============================================================");
        $display("%0s", phase_name);
        $display("============================================================");

        // print weights before this phase
        print_weights("BEFORE");

        // reset membrane state
        train = is_train;
        rst = 1;
        S_in = 25'b0;
        @(posedge clk);
        #1;
        rst = 0;

        // init counters
        count1 = 0;
        count2 = 0;

        // run 40 timesteps
        for (step = 0; step < 40; step = step + 1) begin
            apply_image_timestep(image, step);
            @(posedge clk);
            #1;

            if (spike1) count1 = count1 + 1;
            if (spike2) count2 = count2 + 1;
        end

        // print weights after this phase
        print_weights("AFTER");

        // display results
        $display("Firing counts: Neuron 1 = %0d, Neuron 2 = %0d", count1, count2);
        $display("");
    end
endtask

// main simulation
integer d;
initial begin
    `ifdef TEST_ONLY
    $dumpfile("dynamic_snn_testing.vcd");
    $dumpvars(0, dynamic_snn_tb);
    for (d = 0; d < 25; d = d + 1) begin
        $dumpvars(0, dut.r1[d]);
        $dumpvars(0, dut.r2[d]);
        $dumpvars(0, dut.w1[d]);
        $dumpvars(0, dut.w2[d]);
    end
    $dumpoff;
    `else
    $dumpfile("dynamic_snn_training.vcd");
    $dumpvars(0, dynamic_snn_tb);
    for (d = 0; d < 25; d = d + 1) begin
        $dumpvars(0, dut.r1[d]);
        $dumpvars(0, dut.r2[d]);
        $dumpvars(0, dut.w1[d]);
        $dumpvars(0, dut.w2[d]);
    end
    `endif

    // Phase 1: Train with '0' image
    run_phase("Phase 1: Training with '0'", TRAIN_0, 1);

    // Phase 2: Train with '1' image
    run_phase("Phase 2: Training with '1'", TRAIN_1, 1);

    `ifdef TEST_ONLY
    $dumpon;
    // Phase 3: Test with '0' image
    run_phase("Phase 3: Testing with '0'", TEST_0, 0);

    // Phase 4: Test with '1' image
    run_phase("Phase 4: Testing with '1'", TEST_1, 0);
    `endif

    $display("============================================================");
    $display("Simulation complete.");
    $display("============================================================");

    #20;
    $finish;
end

endmodule
