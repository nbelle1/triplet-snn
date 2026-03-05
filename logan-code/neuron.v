// Time unit: 1ns
// Time precision: 1ns
`timescale 1ns/1ns

module neuron ( input       [6:0] excitation,
                input             clk,
                input             rst,
                input             inhibit_in,
                output reg        output_spike,
                output reg  [6:0] v_membrane,
                output reg  [6:0] spike_count);
  // Set fixed parameters
  localparam  [6:0] V_rest    = 7'b0000110;
  localparam  [6:0] V_thresh  = 7'b1000001;
  
  // Initialize output_spike and v_membrane registers
  initial begin
    output_spike  <=  1'b0;
    v_membrane    <=  V_rest;
    spike_count   <=  7'b0000000;
  end
  // Main logic
  always @ (posedge clk or posedge rst) begin
    // If reset or inhibit signal from other neuron, reset
    // to the rest voltage and clear the output spike
    if (rst || inhibit_in) begin
      output_spike  <=  1'b0;
      v_membrane    <=  V_rest;
      spike_count   <=  7'b0000000;
    // end else if (v_membrane <= 1'b0) begin
    //   v_membrane  <=  V_rest;
    end else begin
      // If the next step will bring the voltage to below rest, put the 
      // neuron voltage to rest
      if (v_membrane + excitation <= V_rest) begin
        v_membrane    <=  V_rest;
        output_spike  <=  1'b0;
      // Otherwise, update the neuron voltage using the FE rule
      // If v_membrane (updated value) is over threshold, output spike and
      // make the next value of v_membrane be V_rest
      end else begin
        if ((v_membrane + excitation) >= V_thresh) begin
          v_membrane    <=  V_rest;
          output_spike  <=  1'b1;
          spike_count   <=  spike_count + 7'b0000001;
          // Otherwise, put the output_spike to 0 and update v_membrane 
          // using the FE rule
        end else begin
          v_membrane <= v_membrane + excitation;
          output_spike  <=  1'b0;
        end
      end
    end
  end
endmodule

module snn_input_hidden ( input  [24:0] input_spikes,
                          input         clk,
                          input         rst,
                          output        out_spike_l2_1,
                          output [6:0]  v_memb_l2_1,
                          output [6:0]  spike_cnt_l2_1,
                          output        out_spike_l2_2,
                          output [6:0]  v_memb_l2_2,
                          output [6:0]  spike_cnt_l2_2); 
  // Set K_syn
  localparam  [6:0] K_syn = 7'b0000001;

  // Set weights from first layer to hidden layer
  reg [1:0] w_1i [0:24];
  reg [1:0] w_2i [0:24];

  initial begin
    $readmemb("init_weights_n1.mem", w_1i);
    $readmemb("init_weights_n2.mem", w_2i);
  end
  
  // Make excitations 7-bit wires
  reg  [6:0]  excite_l2_1;
  reg  [6:0]  excite_l2_2;
  
  wire inhibit_1;
  wire inhibit_2;
  // Logic for inhibiting layer 2 neuron 1
  // Only inhibit if you get a spike from neuron 2 and not from neuron 1
  assign inhibit_1 = out_spike_l2_2 && !out_spike_l2_1;

  // Logic for inhibiting layer 2 neuron 2
  // Only inhibit if you get a spike from neuron 1 and not from neuron 2
  assign inhibit_2 = out_spike_l2_1 && !out_spike_l2_2;

  integer i;

  always @(*) begin
    excite_l2_1 = 7'b0000000;
    excite_l2_2 = 7'b0000000;

    for(i = 0;  i < 25; i = i + 1) begin
      // Use blocking assignment because we want each of these to immediately
      excite_l2_1 = excite_l2_1 + input_spikes[i] * w_1i[i] * K_syn;
      excite_l2_2 = excite_l2_2 + input_spikes[i] * w_2i[i] * K_syn;
    end

  end

  // Transfer excitation to neuron module
  neuron n_l2_1  (.excitation(excite_l2_1), 
                  .clk(clk),
                  .rst(rst),
                  .inhibit_in(inhibit_1),
                  .output_spike(out_spike_l2_1),
                  .v_membrane(v_memb_l2_1),
                  .spike_count(spike_cnt_l2_1));
  neuron n_l2_2  (.excitation(excite_l2_2), 
                  .clk(clk),
                  .rst(rst),
                  .inhibit_in(inhibit_2),
                  .output_spike(out_spike_l2_2),
                  .v_membrane(v_memb_l2_2),
                  .spike_count(spike_cnt_l2_2));
endmodule

module update_neuron_sr(input             input_val,
                        input             clk,
                        input             rst,
                        output reg  [2:0] spike_sr);
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      spike_sr <= 3'b000;
    end else begin
      spike_sr <= {spike_sr[1:0], input_val};
    end
  end
endmodule

module neuron_train ( input       [6:0] excitation,
                      input             clk,
                      input             rst,
                      input             inhibit_in,
                      output reg  [2:0] spike_sr,
                      output reg  [6:0] v_membrane,
                      output reg  [6:0] spike_count);
  // Set fixed parameters
  localparam  [6:0] V_rest    = 7'b0000110;
  localparam  [6:0] V_thresh  = 7'b1000001;
  
  // Initialize spike_sr and v_membrane registers
  initial begin
    spike_sr      <=  3'b000;
    v_membrane    <=  V_rest;
    spike_count   <=  7'b0000000;
  end
  // Main logic
  always @ (posedge clk or posedge rst) begin
    // If reset or inhibit signal from other neuron, reset
    // to the rest voltage and clear the output spike
    if (rst) begin
      spike_sr      <=  3'b000;
      v_membrane    <=  V_rest;
      spike_count   <=  7'b0000000;
    end else if (inhibit_in) begin
      spike_sr      <=  {spike_sr[1:0], 1'b0};
      v_membrane    <=  V_rest;
    // end else if (v_membrane <= 1'b0) begin
    //   v_membrane  <=  V_rest;
    end else begin
      // If the next step will bring the voltage to below rest, put the 
      // neuron voltage to rest
      if (v_membrane + excitation <= V_rest) begin
        v_membrane    <=  V_rest;
        spike_sr      <=  {spike_sr[1:0], 1'b0};
      // Otherwise, update the neuron voltage using the FE rule
      // If v_membrane (updated value) is over threshold, output spike and
      // make the next value of v_membrane be V_rest
      end else begin
        if ((v_membrane + excitation) >= V_thresh) begin
          v_membrane    <=  V_rest;
          spike_sr      <=  {spike_sr[1:0], 1'b1};
          spike_count   <=  spike_count + 7'b0000001;
          // Otherwise, put the output_spike to 0 and update v_membrane 
          // using the FE rule
        end else begin
          v_membrane    <= v_membrane + excitation;
          spike_sr      <=  {spike_sr[1:0], 1'b0};
        end
      end
    end
  end
endmodule

// TODO: change this to have the output spikes as registers
// and to have the updated weights as an output
module snn_train_1 #(
  parameter     INIT_WEIGHTS_N1_PATH = "init_weights_n1.mem",
  parameter     INIT_WEIGHTS_N2_PATH = "init_weights_n2.mem"
)                   ( input  [24:0] input_spikes,
                      input         clk,
                      input         rst,
                      input         train_en,
                      output [2:0]  out_spike_sr_1,
                      output [6:0]  v_memb_l2_1,
                      output [6:0]  spike_cnt_l2_1,
                      output [2:0]  out_spike_sr_2,
                      output [6:0]  v_memb_l2_2,
                      output [6:0]  spike_cnt_l2_2
                      ); 
  // Set K_syn
  localparam  [6:0] K_syn = 7'b0000001;

  // Set weights from first layer to hidden layer
  reg [1:0] w_1i [0:24];
  reg [1:0] w_2i [0:24];

  reg [1:0] stdp_lut [0:4][0:3];

  initial begin
    $readmemb(INIT_WEIGHTS_N1_PATH, w_1i);
    $readmemb(INIT_WEIGHTS_N2_PATH, w_2i);
    $readmemb("stdp_lut.mem", stdp_lut);
  end
  
  // Register for the spike SRs
  reg  [2:0] pre_spike_sr [0:24];
  // Make excitations 7-bit wires
  reg  [6:0]  excite_l2_1;
  reg  [6:0]  excite_l2_2;
  
  wire inhibit_1;
  wire inhibit_2;
  // Logic for inhibiting layer 2 neuron 1
  // Only inhibit if you get a spike from neuron 2 and not from neuron 1
  assign inhibit_1 = out_spike_sr_2[0] && !out_spike_sr_1[0];

  // Logic for inhibiting layer 2 neuron 2
  // Only inhibit if you get a spike from neuron 1 and not from neuron 2
  assign inhibit_2 = out_spike_sr_1[0] && !out_spike_sr_2[0];
  
  integer k;
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      for (k = 0; k < 25; k = k + 1) begin
        pre_spike_sr[k] <= 3'b000;
      end
    end else begin
      for (k = 0; k < 25; k = k + 1) begin
        pre_spike_sr[k] <= {pre_spike_sr[k][1:0], input_spikes[k]};
      end
    end
  end

  integer j;
  integer temp_w1, temp_w2;
  integer dw1, dw2;
  reg train_en_d;
  // always @(posedge clk) begin
  //   train_en_d <= train_en;
  // end
  always @(posedge clk) begin
    if (rst) begin
      // Don't actually use this ever
      // for (j = 0; j < 25; j = j + 1) begin
      //     w_1i[j] <= 2'b01; // Or your preferred default [cite: 34]
      //     w_2i[j] <= 2'b01;
      // end
    // Only update the weights if we have enabled training
    end else if (train_en) begin
      // Inside your always @(posedge clk) block
      for (j = 0; j < 25; j = j + 1) begin
        // Inside your always @(posedge clk) block for (j = 0; j < 25...)
        
        temp_w1 = w_1i[j]; 
        temp_w2 = w_2i[j];
        dw1 = 0;
        dw2 = 0;

        // --- Neuron 1 Delta Accumulation ---
        
        // LTP (Pre-Post) - Prioritize the strongest (closest) spike
        // if      (out_spike_sr_1[0] && pre_spike_sr[j][1]) dw1 = dw1 + 2; 
        // else if (out_spike_sr_1[0] && pre_spike_sr[j][2]) dw1 = dw1 + 1; 

        // // LTD (Post-Pre) - Prioritize the strongest (closest) spike
        // if      (pre_spike_sr[j][0] && out_spike_sr_1[1]) dw1 = dw1 - 2;
        // else if (pre_spike_sr[j][0] && out_spike_sr_1[2]) dw1 = dw1 - 1;
        // if      (out_spike_sr_1[0] && pre_spike_sr[j][1]) dw1 = dw1 + 2;  // LTP close
        // else if (out_spike_sr_1[0] && pre_spike_sr[j][2]) dw1 = dw1 + 1;  // LTP far
        // else if (pre_spike_sr[j][0] && out_spike_sr_1[1]) dw1 = dw1 - 2;  // LTD close
        // else if (pre_spike_sr[j][0] && out_spike_sr_1[2]) dw1 = dw1 - 1;  // LTD far


        if (out_spike_sr_1[0] && !out_spike_sr_1[1]) begin
            // LTP: check if pre fired 1 or 2 cycles ago
            if      (pre_spike_sr[j][1]) dw1 = dw1 + 2;
            else if (pre_spike_sr[j][2]) dw1 = dw1 + 1;
        end
        // Only evaluate LTD when a pre-spike occurs and post fired recently
        if (pre_spike_sr[j][0]) begin
            if      (out_spike_sr_1[1]) dw1 = dw1 - 2;
            else if (out_spike_sr_1[2]) dw1 = dw1 - 1;
        end

        // --- Neuron 2 Delta Accumulation ---
        
        // LTP (Pre-Post) - Prioritize the strongest (closest) spike
        // if      (out_spike_sr_2[0] && pre_spike_sr[j][1]) dw2 = dw2 + 2; 
        // else if (out_spike_sr_2[0] && pre_spike_sr[j][2]) dw2 = dw2 + 1; 

        // // LTD (Post-Pre) - Prioritize the strongest (closest) spike
        // if      (pre_spike_sr[j][0] && out_spike_sr_2[1]) dw2 = dw2 - 2;
        // else if (pre_spike_sr[j][0] && out_spike_sr_2[2]) dw2 = dw2 - 1;



        // if      (out_spike_sr_2[0] && pre_spike_sr[j][1]) dw2 = dw2 + 2;  // LTP close
        // else if (out_spike_sr_2[0] && pre_spike_sr[j][2]) dw2 = dw2 + 1;  // LTP far
        // else if (pre_spike_sr[j][0] && out_spike_sr_2[1]) dw2 = dw2 - 2;  // LTD close
        // else if (pre_spike_sr[j][0] && out_spike_sr_2[2]) dw2 = dw2 - 1;  // LTD far

        if (out_spike_sr_2[0] && !out_spike_sr_2[1]) begin
            // LTP: check if pre fired 1 or 2 cycles ago
            if      (pre_spike_sr[j][1]) dw2 = dw2 + 2;
            else if (pre_spike_sr[j][2]) dw2 = dw2 + 1;
        end
        // Only evaluate LTD when a pre-spike occurs and post fired recently
        if (pre_spike_sr[j][0]) begin
            if      (out_spike_sr_2[1]) dw2 = dw2 - 2;
            else if (out_spike_sr_2[2]) dw2 = dw2 - 1;
        end


        // // --- Neuron 2 Delta Accumulation ---
        // // LTP (Pre-Post)
        // if (out_spike_sr_2[0] && pre_spike_sr[j][1]) dw2 = dw2 + 2; // t = 1
        // if (out_spike_sr_2[0] && pre_spike_sr[j][2]) dw2 = dw2 + 1; // t = 2
        // // LTD (Post-Pre)
        // if (pre_spike_sr[j][0] && out_spike_sr_2[1]) dw2 = dw2 - 2; // t = -1
        // if (pre_spike_sr[j][0] && out_spike_sr_2[2]) dw2 = dw2 - 1; // t = -2

        // if (dw1 != 0 || dw2 != 0) begin
        //   $display("[%0t] Synapse %0d updated | dw1: %0d, dw2: %0d | pre_SR: %b | out_SR1: %b | out_SR2: %b", 
        //            $time, j, dw1, dw2, pre_spike_sr[j], out_spike_sr_1, out_spike_sr_2);
        // end
        if (j == 11) begin
          $display("[%0t] Synapse %0d updated | dw1: %0d, dw2: %0d | pre_SR: %b | out_SR1: %b | out_SR2: %b", 
                   $time, j, dw1, dw2, pre_spike_sr[j], out_spike_sr_1, out_spike_sr_2);
        end
        // $display("[%0t] Synapse %0d updated | dw1: %0d, dw2: %0d | pre_SR: %b | out_SR1: %b | out_SR2: %b", 
        //            $time, j, dw1, dw2, pre_spike_sr[j], out_spike_sr_1, out_spike_sr_2);
        temp_w1 = temp_w1 + dw1;
        temp_w2 = temp_w2 + dw2;

        if (temp_w1 > 3) w_1i[j] <= 2'b11;
        else if (temp_w1 < 0) w_1i[j] <= 2'b00;
        else w_1i[j] <= temp_w1[1:0];

        if (temp_w2 > 3) w_2i[j] <= 2'b11;
        else if (temp_w2 < 0) w_2i[j] <= 2'b00;
        else w_2i[j] <= temp_w2[1:0];
      end
    end
  end
  integer i;
  always @(*) begin
    excite_l2_1 = 7'b0000000;
    excite_l2_2 = 7'b0000000;

    for(i = 0;  i < 25; i = i + 1) begin
      // Use blocking assignment because we want each of these to immediately
      excite_l2_1 = excite_l2_1 + pre_spike_sr[i][0] * w_1i[i] * K_syn;
      excite_l2_2 = excite_l2_2 + pre_spike_sr[i][0] * w_2i[i] * K_syn;
    end

  end

  // Transfer excitation to neuron module
  neuron_train n_1  ( .excitation(excite_l2_1), 
                      .clk(clk),
                      .rst(rst),
                      .inhibit_in(inhibit_1),
                      .spike_sr(out_spike_sr_1),
                      .v_membrane(v_memb_l2_1),
                      .spike_count(spike_cnt_l2_1));
  neuron_train n_2  ( .excitation(excite_l2_2), 
                      .clk(clk),
                      .rst(rst),
                      .inhibit_in(inhibit_2),
                      .spike_sr(out_spike_sr_2),
                      .v_membrane(v_memb_l2_2),
                      .spike_count(spike_cnt_l2_2));
  // Add this to the bottom of neuron.v
// always @(posedge clk) begin
//     $display("[%0t] | Pixel 12 Spike! SR History: [0]=%b, [1]=%b, [2]=%b", 
//                  $time, pre_spike_sr[12][0], pre_spike_sr[12][1], pre_spike_sr[12][2]);
// end
endmodule
