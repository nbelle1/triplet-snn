`timescale 1ns/1ps

module snn_network_tb #(
    parameter COLOR_PATHS = "mem-generation/param.mem"
)
;

    parameter N_SIZE = 784;
    parameter NUM_OUT = 10;

    // signals
    reg        clk, rst;
    reg [N_SIZE-1:0] S_in;
    reg        train;
    wire [12:0] V [0:NUM_OUT-1];
    wire [NUM_OUT-1:0] spike;

    // spike patterns for each color pixel (20 bits each, MSB first)
    reg [19:0] spike_patterns [0:1]; // [0] = Black, [1] = White
    wire [19:0] BLACK = spike_patterns[0];
    wire [19:0] WHITE = spike_patterns[1];

    // Registers to hold current image being processed
    reg [N_SIZE-1:0] current_image;
    reg [19:0] image_mem [0:N_SIZE-1];
    

    // spike firing counters
    integer spike_counts [0:NUM_OUT-1];

    // timestep counter
    integer t;

    // STDP debug storage
    reg [5:0] weights_snap [0:(NUM_OUT*N_SIZE)-1];
    reg [N_SIZE-1:0] save_in_prev1, save_in_prev2;
    reg [NUM_OUT-1:0] save_out_prev1, save_out_prev2;
    reg [NUM_OUT-1:0] save_need_reset;
    
    integer n, p, dbg_i, step, k;
    reg weight_changed;

    // instantiate dut
    snn_network #(
        .N_SIZE(N_SIZE),
        .NUM_OUT(NUM_OUT),
        .INIT_WEIGHTS_PATH("mem-generation/weights/init_weights.mem")
    ) dut (
        .clk(clk),
        .rst(rst),
        .S_in(S_in),
        .train(train),
        .V(V),
        .spike(spike)
    );

    // clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // task: generate spike input for one timestep from an image
    task apply_image_timestep;
        input integer step;
        begin
            for (p = 0; p < N_SIZE; p = p + 1) begin
                // Pull the specific bit for the current timestep directly from memory
                // Assuming MSB (bit 19) is step 0
                S_in[p] = image_mem[p][19 - step]; 
            end
        end
    endtask

    task dump_weights_for_python;
        input [47:0] tag; // "BEFORE" or "AFTER "
        integer n_idx, w_idx;
        begin
            for (n_idx = 0; n_idx < NUM_OUT; n_idx = n_idx + 1) begin
                // $write("%0s N%0d: ", tag, n_idx);
                for (w_idx = 0; w_idx < N_SIZE; w_idx = w_idx + 1) begin
                    // $write("%0d ", dut.weights[n_idx * N_SIZE + w_idx]);
                end
                // $write("\n");
            end
        end
    endtask

    // task: run one phase
    task run_phase;
        input [80*8:1] phase_name;
        input [80*8:1] image_file_path;
        input          is_train;
        begin
            $display("============================================================");
            $display("%0s", phase_name);
            $display("============================================================");
            
            // Load image for this phase
            $readmemb(image_file_path, image_mem);

            // reset membrane state
            train = is_train;

            // reset membrane state
            train = is_train;
            rst = 1;
            S_in = {N_SIZE{1'b0}};
            @(posedge clk);
            #1;
            rst = 0;

            // init counters
            for (n = 0; n < NUM_OUT; n = n + 1) begin
                spike_counts[n] = 0;
            end

            $display("Starting 20 timesteps...");
            if (is_train) dump_weights_for_python("BEFORE");
            // run 20 timesteps
            for (step = 0; step < 20; step = step + 1) begin
                apply_image_timestep(step);

                // snapshot weights and STDP state before clock edge
                if (is_train) begin
                    for (dbg_i = 0; dbg_i < (NUM_OUT*N_SIZE); dbg_i = dbg_i + 1) begin
                        weights_snap[dbg_i] = dut.weights[dbg_i];
                    end
                    save_in_prev1 = dut.in_spike_prev1;
                    save_in_prev2 = dut.in_spike_prev2;
                    
                    for (n = 0; n < NUM_OUT; n = n + 1) begin
                        save_out_prev1[n] = dut.out_spike_prev1[n];
                        save_out_prev2[n] = dut.out_spike_prev2[n];
                        save_need_reset[n] = dut.need_reset[n];
                    end
                end

                @(posedge clk);
                #1; // sample after clock edge

                // count spikes
                for (n = 0; n < NUM_OUT; n = n + 1) begin
                    if (spike[n]) spike_counts[n] = spike_counts[n] + 1;
                end

                // --- STDP debug output during training ---
                if (is_train) begin
                    for (n = 0; n < NUM_OUT; n = n + 1) begin
                        // Potentiation
                        if (spike[n] && !save_need_reset[n]) begin
                            // $display("      >>> N%0d POTENTIATION at step %0d:", n, step);
                            // Note: Printing full N_SIZE bits may crowd console.
                        end

                        // Depression
                        // if ((|S_in) && save_out_prev1[n])
                        //     $display("      >>> N%0d DEPRESSION dt=-1 (each dw=-1)", n);
                        // if ((|S_in) && save_out_prev2[n])
                        //     $display("      >>> N%0d DEPRESSION dt=-2 (each dw=-2)", n);
                    end

                    // Detect and report weight changes
                    for (n = 0; n < NUM_OUT; n = n + 1) begin
                        weight_changed = 0;
                        for (dbg_i = 0; dbg_i < N_SIZE; dbg_i = dbg_i + 1) begin
                            if (dut.weights[n * N_SIZE + dbg_i] !== weights_snap[n * N_SIZE + dbg_i]) begin
                                if (!weight_changed) begin
                                    // $write("      N%0d W changes:", n);
                                    weight_changed = 1;
                                end
                                // $write(" [%0d]:%0d->%0d", dbg_i, weights_snap[n * N_SIZE + dbg_i], dut.weights[n * N_SIZE + dbg_i]);
                            end
                        end
                        if (weight_changed) $write("\n");
                    end
                end
            end
            if (is_train) dump_weights_for_python("AFTER ");

            // display results
            $display("\nPhase Complete. Firing counts:");
            for (n = 0; n < NUM_OUT; n = n + 1) begin
                $display("Neuron %0d = %0d", n, spike_counts[n]);
            end
            $display("");
        end
    endtask

    // main simulation
    initial begin
        $dumpfile("snn_network.vcd");
        $dumpvars(0, snn_network_tb);

        // Run phases, passing the file path to the corresponding .mem image file
        run_phase("Phase 1: Training with '0'", "mem-generation/dataset/zero.mem", 1);
        run_phase("Phase 2: Training with '1'", "mem-generation/dataset/one.mem", 1);
        run_phase("Phase 3: Testing with '0'",  "mem-generation/dataset/zero.mem",  0);
        run_phase("Phase 4: Testing with '1'",  "mem-generation/dataset/one.mem",  0);

        $display("============================================================");
        $display("Simulation complete.");
        $display("============================================================");

        #20;
        $finish;
    end

endmodule