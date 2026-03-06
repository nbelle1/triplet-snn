# Verilog compiler
IVERILOG = iverilog
VVP = vvp

# Directories
RTL_DIR = rtl
TB_DIR  = tb
VIZ_DIR = viz
DATA_DIR = data

# Source files
RTL_SRC = $(RTL_DIR)/snn_network.v
TB_SRC  = $(TB_DIR)/snn_network_tb.v
TB_VERBOSE_SRC = $(TB_DIR)/snn_network_tb_verbose.v

# Default target: build both waveforms
all: train test

# Compile and run training
train: $(RTL_SRC) $(TB_SRC)
	$(IVERILOG) -o snn_train $(RTL_SRC) $(TB_SRC)
	$(VVP) snn_train

# Compile and run testing
test: $(RTL_SRC) $(TB_SRC)
	$(IVERILOG) -DTEST_ONLY -o snn_test $(RTL_SRC) $(TB_SRC)
	$(VVP) snn_test

# View waveforms
wave-train: snn_training.vcd
	gtkwave snn_training.vcd &

wave-test: snn_testing.vcd
	gtkwave snn_testing.vcd &

# Verbose debug run (uses snn_network_tb_verbose.v)
verbose: $(RTL_SRC) $(TB_VERBOSE_SRC)
	$(IVERILOG) -g2012 -o snn_verbose $(RTL_SRC) $(TB_VERBOSE_SRC)
	$(VVP) snn_verbose

# Generate weight heatmaps
plot:
	python3 $(VIZ_DIR)/plot_weights.py

# Clean build artifacts
clean:
	rm -f snn_train snn_test snn_verbose *.vcd *.png

.PHONY: all train test wave-train wave-test verbose plot clean
