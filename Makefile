# Verilog compiler
IVERILOG = iverilog
VVP = vvp

# Source files
SOURCES = snn_network.v snn_network_tb.v

# Default target: build both waveforms
all: train test

# Compile and run training
train: $(SOURCES)
	$(IVERILOG) -o snn_train $(SOURCES)
	$(VVP) snn_train

# Compile and run testing
test: $(SOURCES)
	$(IVERILOG) -DTEST_ONLY -o snn_test $(SOURCES)
	$(VVP) snn_test

# View waveforms
wave-train: snn_training.vcd
	gtkwave snn_training.vcd &

wave-test: snn_testing.vcd
	gtkwave snn_testing.vcd &

# Verbose debug run (uses snn_network_tb_verbose.v)
verbose: snn_network.v snn_network_tb_verbose.v
	$(IVERILOG) -o snn_verbose snn_network.v snn_network_tb_verbose.v
	$(VVP) snn_verbose

# Generate weight heatmaps
plot: $(SOURCES)
	python3 plot_weights.py

# Clean build artifacts
clean:
	rm -f snn_train snn_test snn_verbose *.vcd *.png

.PHONY: all train test wave-train wave-test verbose plot clean
