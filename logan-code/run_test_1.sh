#!/bin/bash

# 1. Compile the design and testbench
iverilog -o sim_test1 neuron.v tbs.v -s testbench_test_1

# 2. Run the first training pass
vvp sim_test1

# 3. Open in GTKWave
gtkwave test_1_output.vcd test_1_view.gtkw