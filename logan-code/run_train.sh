#!/bin/bash

# 1. Compile the design and testbench
iverilog -o sim_pass1 neuron.v tbs.v -s testbench_train_1

# 2. Run the first training pass
vvp sim_pass1

# 3. Compile the second training pass (using updated weights)
iverilog -o sim_pass2 neuron.v tbs.v -s testbench_train_2

# 4. Run the second training pass
vvp sim_pass2

# 5. Make training weights plots
python map_weights.py