`timescale 1ns / 1ps

module tb_snn_stdp;

    reg         clk;
    reg         rst;
    reg         train_en;
    reg  [24:0] S_in;
    wire [7:0]  V_mem1, V_mem2;
    wire        spike_out1, spike_out2;

    // Instantiate DUT
    snn_stdp uut (
        .clk(clk), .rst(rst), .train_en(train_en),
        .S_in(S_in),
        .V_mem1(V_mem1), .V_mem2(V_mem2),
        .spike_out1(spike_out1), .spike_out2(spike_out2)
    );

    // Clock: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Firing sequences (20 bits, MSB first)
    localparam [19:0] WHITE_SEQ = 20'b01000000100000000010;
    localparam [19:0] BLACK_SEQ = 20'b01010100010101000101;

    // Pixel maps for training and testing images (Fig. 4)
    // 1 = black pixel, 0 = white pixel
    // Bit ordering: {row4[4:0], row3[4:0], row2[4:0], row1[4:0], row0[4:0]}

    // Training digit '0'
    localparam [24:0] TRAIN_0 = {
        5'b00000,  // row 4
        5'b01110,  // row 3
        5'b01010,  // row 2
        5'b01110,  // row 1
        5'b00000   // row 0
    };

    // Training digit '1'
    localparam [24:0] TRAIN_1 = {
        5'b01110,  // row 4
        5'b00100,  // row 3
        5'b00100,  // row 2
        5'b00100,  // row 1
        5'b00110   // row 0
    };

    // Testing digit '0'
    localparam [24:0] TEST_0 = {
        5'b00000,  // row 4
        5'b01110,  // row 3
        5'b01010,  // row 2
        5'b01010,  // row 1
        5'b00000   // row 0
    };

    // Testing digit '1'
    localparam [24:0] TEST_1 = {
        5'b00100,  // row 4
        5'b00100,  // row 3
        5'b00100,  // row 2
        5'b00100,  // row 1
        5'b00110   // row 0
    };

    // Spike counters
    integer cnt1, cnt2;

    // Firing sequence storage for 25 input neurons
    reg [19:0] seq [0:24];

    integer i, t, r, c, idx;

    // Task: Load an image's pixel map into firing sequences
    task load_image;
        input [24:0] pixels;
        integer li;
        begin
            for (li = 0; li < 25; li = li + 1) begin
                if (pixels[li])
                    seq[li] = BLACK_SEQ;
                else
                    seq[li] = WHITE_SEQ;
            end
        end
    endtask

    // Task: Print weight maps in 5x5 grid format
    task print_weights;
        input [255:0] label;
        integer pr, pc, pidx;
        begin
            $display("  Weight map to Output Neuron 1:");
            for (pr = 0; pr < 5; pr = pr + 1) begin
                $write("    ");
                for (pc = 0; pc < 5; pc = pc + 1) begin
                    pidx = pr * 5 + pc;
                    $write("%0d ", uut.w1[pidx]);
                end
                $write("\n");
            end
            $display("  Weight map to Output Neuron 2:");
            for (pr = 0; pr < 5; pr = pr + 1) begin
                $write("    ");
                for (pc = 0; pc < 5; pc = pc + 1) begin
                    pidx = pr * 5 + pc;
                    $write("%0d ", uut.w2[pidx]);
                end
                $write("\n");
            end
            // Machine-readable lines for Python parsing
            $write("DATA_W1 %0s", label);
            for (pidx = 0; pidx < 25; pidx = pidx + 1)
                $write(" %0d", uut.w1[pidx]);
            $write("\n");
            $write("DATA_W2 %0s", label);
            for (pidx = 0; pidx < 25; pidx = pidx + 1)
                $write(" %0d", uut.w2[pidx]);
            $write("\n");
        end
    endtask

    // Task: Run one 20-cycle phase
    task run_phase;
        input is_training;
        input [24:0] pixels;
        integer pt, pi;
        begin
            // Reset neuron state (preserves weights)
            rst = 1;
            train_en = is_training;
            S_in = 25'b0;
            cnt1 = 0; cnt2 = 0;
            @(posedge clk); #1;
            rst = 0;

            // Load firing sequences from pixel map
            load_image(pixels);

            // Run 20 input cycles
            for (pt = 0; pt < 20; pt = pt + 1) begin
                // Pack S_in from each neuron's firing sequence (MSB first)
                for (pi = 0; pi < 25; pi = pi + 1) begin
                    S_in[pi] = seq[pi][19 - pt];
                end
                @(posedge clk); #1;

                // Count spikes
                cnt1 = cnt1 + spike_out1;
                cnt2 = cnt2 + spike_out2;

                // Per-cycle display
                $display("  t=%2d: V1=%3d V2=%3d spike1=%b spike2=%b", pt+1, V_mem1, V_mem2, spike_out1, spike_out2);
            end

            // Final report
            $display("  --------------------------------------");
            $display("  Spike counts: Neuron1=%0d  Neuron2=%0d", cnt1, cnt2);
            $display("DATA_SPIKES %0d %0d", cnt1, cnt2);
        end
    endtask

    // Main test sequence
    initial begin
        $dumpfile("snn_stdp.vcd");
        $dumpvars(0, tb_snn_stdp);

        // Print initial random weights
        $display("\n========================================");
        $display("========= Initial Weight Maps ==========");
        $display("========================================");
        print_weights("initial");

        // Phase 1: Train with digit '0' (random weights)
        $display("\n========================================");
        $display("==== Phase 1: Training with digit 0 ====");
        $display("========================================");
        run_phase(1, TRAIN_0);
        $display("\n  Weight maps after training on digit 0:");
        print_weights("after_train0");

        // Phase 2: Train with digit '1' (weights carry over)
        $display("\n========================================");
        $display("==== Phase 2: Training with digit 1 ====");
        $display("========================================");
        run_phase(1, TRAIN_1);
        $display("\n  Weight maps after training on digit 1:");
        print_weights("after_train1");

        // Phase 3: Test with digit '0' (weights frozen)
        $display("\n========================================");
        $display("==== Phase 3: Testing with digit 0  ====");
        $display("========================================");
        run_phase(0, TEST_0);

        // Phase 4: Test with digit '1' (weights frozen)
        $display("\n========================================");
        $display("==== Phase 4: Testing with digit 1  ====");
        $display("========================================");
        run_phase(0, TEST_1);

        $display("\n========================================");
        $display("========= SIMULATION COMPLETE  =========");
        $display("========================================");
        $finish;
    end

endmodule
