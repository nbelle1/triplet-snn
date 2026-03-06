// Time unit: 1ns
// Time precision: 1ns
`timescale 1ns/1ns

module base_testbench_train #(
  parameter SPIKE_FILE = "spikes.mem",
  parameter VCD_NAME = "wave.vcd",
  parameter INIT_WEIGHTS_N1_PATH = "init_weights_n1.mem",
  parameter INIT_WEIGHTS_N2_PATH = "init_weights_n2.mem",
  parameter TRAINED_PATH_N1 = "trained_weights_n1.mem",
  parameter TRAINED_PATH_N2 = "trained_weights_n2.mem",
  parameter [0:0] IS_TRAIN = 1'b1
) ();

  reg clk;
  reg rst;
  reg [24:0] input_bus;
  reg [19:0] spike_mat [0:24];

  // Training-specific outputs (Shift Registers)
  wire [2:0] out_spike_sr_1;
  wire [2:0] out_spike_sr_2;
  
  // Standard monitoring outputs
  wire [6:0] v_memb_l2_1;
  wire [6:0] spike_cnt_l2_1;
  wire [6:0] v_memb_l2_2;
  wire [6:0] spike_cnt_l2_2;

  // Instantiate the training-enabled SNN
  snn_train_1 #(
    .INIT_WEIGHTS_N1_PATH(INIT_WEIGHTS_N1_PATH),
    .INIT_WEIGHTS_N2_PATH(INIT_WEIGHTS_N2_PATH)
  ) snn0 ( 
    .input_spikes   (input_bus),
    .clk            (clk),
    .rst            (rst),
    .train_en       (IS_TRAIN),
    .out_spike_sr_1 (out_spike_sr_1),
    .v_memb_l2_1    (v_memb_l2_1),
    .spike_cnt_l2_1 (spike_cnt_l2_1),
    .out_spike_sr_2 (out_spike_sr_2),
    .v_memb_l2_2    (v_memb_l2_2),
    .spike_cnt_l2_2 (spike_cnt_l2_2)
  );

  // Clock flips polarity every 5ns (10ns period / 100MHz)
  always begin
    #5 clk = ~clk;
  end

  initial begin
    // Setup waveform dumping using parameters
    $dumpfile(VCD_NAME);
    $dumpvars(0, base_testbench_train);

    // Load the stimulus matrix from the provided file parameter
    $readmemb(SPIKE_FILE, spike_mat);

    // Initial State
    input_bus     = 25'b0;
    clk           = 1'b0;
    
    // Assert reset for 2 clock cycles
    rst           = 1'b1;
    #20;
    rst           = 1'b0;

    // Loop through the 20 time steps (columns of the matrix)
    // starting from MSB (index 19) down to LSB (index 0)
    // to get the input_bus
    for (integer i = 19; i >= 0; i = i - 1) begin
      @(posedge clk);
      for (integer j = 0; j < 25; j = j + 1) begin
        // Feed the j-th neuron the bit for time-step i
        input_bus[j] <= spike_mat[j][i];
      end
    end
    input_bus = 25'b0;
    // Simulation cooldown period
    #70;
    if (IS_TRAIN) begin
      $writememb(TRAINED_PATH_N1, snn0.w_1i);
      $writememb(TRAINED_PATH_N2, snn0.w_2i);
      #50;
    end
    $display("Simulation finished. Check %s for results.", VCD_NAME);
    $finish;
  end
endmodule

module testbench_train_1;
  base_testbench_train #(
    .SPIKE_FILE("spike_mat_train_1.mem"),
    .VCD_NAME("train_1_output.vcd"),
    .INIT_WEIGHTS_N1_PATH("init_weights_n1.mem"),
    .INIT_WEIGHTS_N2_PATH("init_weights_n2.mem"),
    .TRAINED_PATH_N1("trained_weights_pass1_n1.mem"),
    .TRAINED_PATH_N2("trained_weights_pass1_n2.mem"),
    .IS_TRAIN(1)
  ) test_inst ();
endmodule

module testbench_train_2;
  base_testbench_train #(
    .SPIKE_FILE("spike_mat_train_2.mem"),
    .VCD_NAME("train_2_output.vcd"),
    .INIT_WEIGHTS_N1_PATH("trained_weights_pass1_n1.mem"),
    .INIT_WEIGHTS_N2_PATH("trained_weights_pass1_n2.mem"),
    .TRAINED_PATH_N1("trained_weights_pass2_n1.mem"),
    .TRAINED_PATH_N2("trained_weights_pass2_n2.mem"),
    .IS_TRAIN(1)
  ) test_inst ();
endmodule

module testbench_test_1;
  base_testbench_train #(
    .SPIKE_FILE("spike_mat_test_1.mem"),
    .VCD_NAME("test_1_output.vcd"),
    .INIT_WEIGHTS_N1_PATH("trained_weights_pass2_n1.mem"),
    .INIT_WEIGHTS_N2_PATH("trained_weights_pass2_n2.mem"),
    .IS_TRAIN(0)
  ) test_inst ();
endmodule

module testbench_test_2;
  base_testbench_train #(
    .SPIKE_FILE("spike_mat_test_2.mem"),
    .VCD_NAME("test_2_output.vcd"),
    .INIT_WEIGHTS_N1_PATH("trained_weights_pass2_n1.mem"),
    .INIT_WEIGHTS_N2_PATH("trained_weights_pass2_n2.mem"),
    .IS_TRAIN(0)
  ) test_inst ();
endmodule

// Run this
// ./run_train.sh
// ./view_train.sh (wip)
// ./view_test.sh (wip) 