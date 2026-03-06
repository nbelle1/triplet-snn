#!/bin/bash

# 1. Compile the design and testbench
iverilog -o sim_pass2 neuron.v tbs.v -s testbench_train_2

# 2. Run the first training pass
vvp sim_pass2

# 3. Open in GTKWave
gtkwave train_2_output.vcd train_2_view.gtkw