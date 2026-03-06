#!/bin/bash

# 1. Compile the design and testbench
iverilog -o sim_test2 neuron.v tbs.v -s testbench_test_2

# 2. Run the first training pass
vvp sim_test2

# 3. Open in GTKWave
gtkwave test_2_output.vcd test_2_view.gtkw