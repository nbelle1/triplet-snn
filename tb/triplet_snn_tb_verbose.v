// verbose testbench for Triplet SNN; perform training and testing in one run

`timescale 1ns/1ps

module triplet_snn_tb;

// signals
reg        clk, rst;
reg [24:0] S_in;
reg        train;
wire [9:0] V1, V2;
wire       spike1, spike2;

// spike patterns for each color pixel (40 bits each, MSB first)
// original evenly-spaced patterns (20-bit)
// localparam [19:0] WHITE = 20'b01000000100000000010;
// localparam [19:0] BLACK = 20'b01010100010101000101;

// bursty patterns to showcase triplet STDP (pre-post-pre / post-pre-post)
// BLACK: bursts of 2 every 5 cycles (16 spikes in 40 steps)
// WHITE: single spikes every 10 cycles (4 spikes in 40 steps)
localparam [39:0] WHITE = 40'b1000000000100000000010000000001000000000;
localparam [39:0] BLACK = 40'b1100011000110001100011000110001100011000;

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

// timestep counter
integer t;

// STDP debug storage
reg [3:0] w1_snap [0:24];
reg [3:0] w2_snap [0:24];
reg [3:0] save_r1 [0:24];
reg [3:0] save_r2 [0:24];
reg [3:0] save_o1_1, save_o1_2;
reg [3:0] save_o2_1, save_o2_2;
reg       save_need_reset_1, save_need_reset_2;
integer   dbg_i;
reg       w1_changed, w2_changed;

// instantiate dut
triplet_snn dut (
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

// task: display 5x5 weight map
task display_weights;
    input [80*8:1] label;
    integer r, c, idx;
    begin
        $display("%0s", label);
        for (r = 0; r < 5; r = r + 1) begin
            $write("  ");
            for (c = 0; c < 5; c = c + 1) begin
                idx = r * 5 + c;
                $write("%0d ", dut.w1[idx]);
            end
            $write("  |  ");
            for (c = 0; c < 5; c = c + 1) begin
                idx = r * 5 + c;
                $write("%0d ", dut.w2[idx]);
            end
            $write("\n");
        end
        $display("");
    end
endtask

// task: generate spike input for one timestep from an image
task apply_image_timestep;
    input [24:0] image;
    input integer step;
    integer p;
    begin
        for (p = 0; p < 25; p = p + 1) begin
            if (image[24 - p])  // row-major: pixel 0 is bit 24
                S_in[p] = BLACK[39 - step];
            else
                S_in[p] = WHITE[39 - step];
        end
    end
endtask

// task: print trace values for active synapses
task print_traces;
    input [80*8:1] label;
    integer ti;
    begin
        $write("      %0s r1:", label);
        for (ti = 0; ti < 25; ti = ti + 1) begin
            if (save_r1[ti] > 0)
                $write(" [%0d]=%0d", ti, save_r1[ti]);
        end
        $write("\n");
        $write("      %0s r2:", label);
        for (ti = 0; ti < 25; ti = ti + 1) begin
            if (save_r2[ti] > 0)
                $write(" [%0d]=%0d", ti, save_r2[ti]);
        end
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

        // display weights before this phase
        $write("  W1 weights         |  W2 weights\n");
        display_weights("Weights BEFORE:");

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

        // display header
        $display("Step | V1    spike1 | V2    spike2");
        $display("-----|--------------|-------------");

        // run 40 timesteps
        for (step = 0; step < 40; step = step + 1) begin
            apply_image_timestep(image, step);

            // snapshot weights and trace state before clock edge
            if (is_train) begin
                for (dbg_i = 0; dbg_i < 25; dbg_i = dbg_i + 1) begin
                    w1_snap[dbg_i] = dut.w1[dbg_i];
                    w2_snap[dbg_i] = dut.w2[dbg_i];
                    save_r1[dbg_i] = dut.r1[dbg_i];
                    save_r2[dbg_i] = dut.r2[dbg_i];
                end
                save_o1_1 = dut.o1_1;
                save_o1_2 = dut.o1_2;
                save_o2_1 = dut.o2_1;
                save_o2_2 = dut.o2_2;
                save_need_reset_1 = dut.need_reset_1;
                save_need_reset_2 = dut.need_reset_2;
            end

            @(posedge clk);
            #1;  // sample after clock edge

            // count spikes
            if (spike1) count1 = count1 + 1;
            if (spike2) count2 = count2 + 1;

            $display("  %2d | %3d     %b     | %3d     %b",
                     step, V1, spike1, V2, spike2);

            // --- Triplet STDP debug output during training ---
            if (is_train) begin
                // Potentiation: output neuron fires (not in reset)
                if (spike1 && !save_need_reset_1) begin
                    $display("      >>> N1 POTENTIATION at step %0d:", step);
                    print_traces("pre traces");
                    $display("          o2_1 (slow post, triplet mod): %0d", save_o2_1);
                end
                if (spike2 && !save_need_reset_2) begin
                    $display("      >>> N2 POTENTIATION at step %0d:", step);
                    print_traces("pre traces");
                    $display("          o2_2 (slow post, triplet mod): %0d", save_o2_2);
                end

                // Depression: pre fires now while post trace is active
                if ((|S_in) && save_o1_1 > 0) begin
                    $display("      >>> N1 DEPRESSION at step %0d:", step);
                    $display("          o1_1 (fast post): %0d", save_o1_1);
                    $write("          active r2 (triplet mod):");
                    for (dbg_i = 0; dbg_i < 25; dbg_i = dbg_i + 1) begin
                        if (S_in[dbg_i] && save_r2[dbg_i] > 0)
                            $write(" [%0d]=%0d", dbg_i, save_r2[dbg_i]);
                    end
                    $write("\n");
                end
                if ((|S_in) && save_o1_2 > 0) begin
                    $display("      >>> N2 DEPRESSION at step %0d:", step);
                    $display("          o1_2 (fast post): %0d", save_o1_2);
                    $write("          active r2 (triplet mod):");
                    for (dbg_i = 0; dbg_i < 25; dbg_i = dbg_i + 1) begin
                        if (S_in[dbg_i] && save_r2[dbg_i] > 0)
                            $write(" [%0d]=%0d", dbg_i, save_r2[dbg_i]);
                    end
                    $write("\n");
                end

                // Detect and report weight changes
                w1_changed = 0;
                w2_changed = 0;
                for (dbg_i = 0; dbg_i < 25; dbg_i = dbg_i + 1) begin
                    if (dut.w1[dbg_i] !== w1_snap[dbg_i]) w1_changed = 1;
                    if (dut.w2[dbg_i] !== w2_snap[dbg_i]) w2_changed = 1;
                end

                if (w1_changed) begin
                    $write("      W1 changes:");
                    for (dbg_i = 0; dbg_i < 25; dbg_i = dbg_i + 1) begin
                        if (dut.w1[dbg_i] !== w1_snap[dbg_i])
                            $write(" [%0d]:%0d->%0d", dbg_i, w1_snap[dbg_i], dut.w1[dbg_i]);
                    end
                    $write("\n");
                end
                if (w2_changed) begin
                    $write("      W2 changes:");
                    for (dbg_i = 0; dbg_i < 25; dbg_i = dbg_i + 1) begin
                        if (dut.w2[dbg_i] !== w2_snap[dbg_i])
                            $write(" [%0d]:%0d->%0d", dbg_i, w2_snap[dbg_i], dut.w2[dbg_i]);
                    end
                    $write("\n");
                end

                if (w1_changed || w2_changed)
                    display_weights("      Updated weights:");
            end
        end

        // display results
        $display("");
        $display("Firing counts: Neuron 1 = %0d, Neuron 2 = %0d", count1, count2);

        if (is_train) begin
            $write("  W1 weights         |  W2 weights\n");
            display_weights("Weights AFTER:");
        end

        $display("");
    end
endtask

// main simulation
initial begin
    $dumpfile("triplet_snn_verbose.vcd");
    $dumpvars(0, triplet_snn_tb);

    // Phase 1: Train with '0' image
    run_phase("Phase 1: Training with '0'", TRAIN_0, 1);

    // Phase 2: Train with '1' image
    run_phase("Phase 2: Training with '1'", TRAIN_1, 1);

    // Phase 3: Test with '0' image
    run_phase("Phase 3: Testing with '0'", TEST_0, 0);

    // Phase 4: Test with '1' image
    run_phase("Phase 4: Testing with '1'", TEST_1, 0);

    $display("============================================================");
    $display("Simulation complete.");
    $display("============================================================");

    #20;
    $finish;
end

endmodule
