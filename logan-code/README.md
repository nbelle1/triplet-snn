iverilog -o sim_pass1 neuron.v tbs.v -s testbench_train_1
vvp sim_pass1
iverilog -o sim_pass2 neuron.v tbs.v -s testbench_train_2
vvp sim_pass2
python map_weights.py