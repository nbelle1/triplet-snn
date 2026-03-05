module tb_lifneuronnetwork_stdp;
    localparam int N_IN = 25;
    localparam logic [19:0] WHITE_SEQ = 20'b01000000100000000010;
    localparam logic [19:0] BLACK_SEQ = 20'b01010100010101000101;

    logic clk = 0;
    logic rst;
    logic train_en;
    logic [N_IN-1:0] in_spikes;

    logic [7:0] V_out1, V_out2;
    logic spike_out1, spike_out2;
    logic [6:0] fire_count1, fire_count2;


    // Bit i corresponds to one input neuron (pixel).
    //localparam logic [N_IN-1:0] TRAIN_IMG_0 = 25'b1111111100000010111011011;
    localparam logic [N_IN-1:0] TRAIN_IMG_0 = 25'b0000001110010100111000000;
    localparam logic [N_IN-1:0] TRAIN_IMG_1 = 25'b0110000100001000010001110;
    localparam logic [N_IN-1:0] TEST_IMG_0  = 25'b0000001010010100111000000;
    localparam logic [N_IN-1:0] TEST_IMG_1  = 25'b0110000100001000010000100;

    lif_neuronnetwork_stdp #(
        .N_IN(N_IN)
    ) dut (
        .clk(clk),
        .rst(rst),
        .train_en(train_en),
        .in_spikes(in_spikes),
        .V_out1(V_out1),
        .V_out2(V_out2),
        .spike_out1(spike_out1),
        .spike_out2(spike_out2),
        .fire_count1(fire_count1),
        .fire_count2(fire_count2)
    );

    always #5 clk = ~clk;

    task automatic dump_weight_map_csv_1(input string fname);
        int fd;
        int r, c, idx;
        begin
            fd = $fopen(fname, "w");
            if (fd == 0) begin
                $display("ERROR: cannot open %s for writing", fname);
            end else begin
                for (r = 0; r < 5; r = r + 1) begin
                    for (c = 0; c < 5; c = c + 1) begin
                        idx = (r * 5) + c;
                        $fwrite(fd, "%0d", dut.w1[idx]);
                        if (c != 4) $fwrite(fd, ",");
                    end
                    $fwrite(fd, "\n");
                end
                $fclose(fd);
            end
        end
    endtask

    task automatic dump_weight_map_csv_2(input string fname);
        int fd;
        int r, c, idx;
        begin
            fd = $fopen(fname, "w");
            if (fd == 0) begin
                $display("ERROR: cannot open %s for writing", fname);
            end else begin
                for (r = 0; r < 5; r = r + 1) begin
                    for (c = 0; c < 5; c = c + 1) begin
                        idx = (r * 5) + c;
                        $fwrite(fd, "%0d", dut.w2[idx]);
                        if (c != 4) $fwrite(fd, ",");
                    end
                    $fwrite(fd, "\n");
                end
                $fclose(fd);
            end
        end
    endtask

    task automatic save_weight_snapshot(input int stage);
        begin
            case (stage)
                0: begin
                    dump_weight_map_csv_1("wmap1_before.csv");
                    dump_weight_map_csv_2("wmap2_before.csv");
                end
                1: begin
                    dump_weight_map_csv_1("wmap1_after_train0.csv");
                    dump_weight_map_csv_2("wmap2_after_train0.csv");
                end
                2: begin
                    dump_weight_map_csv_1("wmap1_after_train1.csv");
                    dump_weight_map_csv_2("wmap2_after_train1.csv");
                end
                default: begin
                end
            endcase
        end
    endtask

    task automatic drive_sample(input logic [N_IN-1:0] img_mask);
        int t, i;
        begin
            for (t = 0; t < 20; t = t + 1) begin
                for (i = 0; i < N_IN; i = i + 1) begin
                    in_spikes[i] <= img_mask[i] ? BLACK_SEQ[19 - t] : WHITE_SEQ[19 - t];
                end
                @(posedge clk);
            end
            in_spikes <= '0;
            @(posedge clk);
        end
    endtask

    task automatic run_segment(
        input string seg_name,
        input logic [N_IN-1:0] img_mask
    );
        int start1, start2;
        int seg_count1, seg_count2;
        begin
            start1 = fire_count1;
            start2 = fire_count2;
            drive_sample(img_mask);
            seg_count1 = fire_count1 - start1;
            seg_count2 = fire_count2 - start2;
            $display("%s: segment_count1=%0d segment_count2=%0d (total1=%0d total2=%0d)",
                     seg_name, seg_count1, seg_count2, fire_count1, fire_count2);
        end
    endtask

    initial begin
        $dumpfile("waves_lifneuronnetwork_stdp.vcd");
        $dumpvars(0, tb_lifneuronnetwork_stdp);

        rst = 1'b1;
        train_en = 1'b0;
        in_spikes = '0;
        repeat (2) @(posedge clk);
        rst = 1'b0;
        repeat (1) @(posedge clk);
        save_weight_snapshot(0);

        // Training pass (one iteration): digit 0 then digit 1.
        train_en = 1'b1;
        $display("\n=== Training sample: digit 0 ===");
        run_segment("train_0", TRAIN_IMG_0);
        save_weight_snapshot(1);

        $display("\n=== Training sample: digit 1 ===");
        run_segment("train_1", TRAIN_IMG_1);
        save_weight_snapshot(2);

        // Freeze weights for testing.
        train_en = 1'b0;
        $display("\n=== Testing sample: digit 0 ===");
        run_segment("test_0", TEST_IMG_0);

        $display("\n=== Testing sample: digit 1 ===");
        run_segment("test_1", TEST_IMG_1);

        $finish;
    end
endmodule
