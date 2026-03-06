#!/bin/bash

# 1. Compile the design and testbench
iverilog -o sim_pass1 neuron.v tbs.v -s testbench_train_1

# 2. Run the first training pass
vvp sim_pass1

# 3. Open in GTKWave
gtkwave train_1_output.vcd train_1_view.gtkw