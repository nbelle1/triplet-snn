// testbench for Dynamic SNN; perform training and testing in one run
// All parameters configurable via -D flags at compile time
//
// Usage examples:
//   make ablation                                          # default: 4-bit triplet LIF
//   make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0  # original pair-based IF
//   make ablation NUM_STEPS=80 NUM_EPOCHS=3                # longer training

`timescale 1ns/1ps

// --- Configurable parameters (override with -D flags) ---
`ifndef W_BITS
`define W_BITS 4
`endif

`ifndef MODE
`define MODE 0
`endif

`ifndef TRIPLET_EN
`define TRIPLET_EN 1
`endif

`ifndef TRACE_BITS
`define TRACE_BITS 4
`endif

`ifndef LEAK_EN
`define LEAK_EN 1
`endif

`ifndef SYMMETRIC
`define SYMMETRIC 0
`endif

`ifndef NUM_EPOCHS
`define NUM_EPOCHS 1
`endif

module dynamic_snn_tb;

localparam W_BITS      = `W_BITS;
localparam MODE        = `MODE;
localparam TRIPLET_EN  = `TRIPLET_EN;
localparam TRACE_BITS  = `TRACE_BITS;
localparam LEAK_EN     = `LEAK_EN;
localparam SYMMETRIC   = `SYMMETRIC;
localparam NUM_EPOCHS  = `NUM_EPOCHS;
localparam V_BITS      = W_BITS + 6;

// signals
reg              clk, rst;
reg [24:0]       S_in;
reg              train;
wire [V_BITS-1:0] V1, V2;
wire             spike1, spike2;

// spike patterns for each color pixel (MSB first)
// BLACK: bursts of 2 every 5 cycles (16 spikes in 40 steps)
// WHITE: single spikes every 10 cycles (4 spikes in 40 steps)
// NUM_STEPS is derived from pattern length — change pattern width to adjust
// localparam NUM_STEPS = 40;
// localparam [NUM_STEPS-1:0] WHITE = 40'b1000000000100000000010000000001000000000;
// localparam [NUM_STEPS-1:0] BLACK = 40'b1100110000001100110000001100110000001100;

localparam NUM_STEPS = 20;
localparam [NUM_STEPS-1:0] WHITE = 20'b01000000100000000010;
localparam [NUM_STEPS-1:0] BLACK = 20'b01010100010101000101;


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
snn_dynamic #(.W_BITS(W_BITS), .MODE(MODE), .TRIPLET_EN(TRIPLET_EN), .TRACE_BITS(TRACE_BITS), .LEAK_EN(LEAK_EN), .SYMMETRIC(SYMMETRIC)) dut (
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
                S_in[p] = BLACK[NUM_STEPS - 1 - step];
            else
                S_in[p] = WHITE[NUM_STEPS - 1 - step];
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

        // run NUM_STEPS timesteps
        for (step = 0; step < NUM_STEPS; step = step + 1) begin
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
integer d, epoch;
initial begin
    $dumpfile("dynamic_snn.vcd");
    $dumpvars(0, dynamic_snn_tb);
    for (d = 0; d < 25; d = d + 1) begin
        $dumpvars(0, dut.r1[d]);
        $dumpvars(0, dut.r2[d]);
        $dumpvars(0, dut.w1[d]);
        $dumpvars(0, dut.w2[d]);
    end

    // print configuration
    $display("============================================================");
    $display("CONFIG: W_BITS=%0d  TRACE_BITS=%0d  TRIPLET_EN=%0d  MODE=%0d  LEAK_EN=%0d  SYMMETRIC=%0d",
             W_BITS, TRACE_BITS, TRIPLET_EN, MODE, LEAK_EN, SYMMETRIC);
    $display("CONFIG: NUM_STEPS=%0d (from pattern length)  NUM_EPOCHS=%0d", NUM_STEPS, NUM_EPOCHS);
    $display("============================================================");

    // training: repeat for NUM_EPOCHS
    for (epoch = 0; epoch < NUM_EPOCHS; epoch = epoch + 1) begin
        run_phase({"Train '0' epoch"}, TRAIN_0, 1);
        run_phase({"Train '1' epoch"}, TRAIN_1, 1);
    end

    // testing
    run_phase("Test '0'", TEST_0, 0);
    run_phase("Test '1'", TEST_1, 0);

    $display("============================================================");
    $display("Simulation complete.");
    $display("============================================================");

    #20;
    $finish;
end

endmodule
