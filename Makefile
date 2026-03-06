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
TRIPLET_RTL_SRC = $(RTL_DIR)/triplet_snn.v
TRIPLET_TB_SRC  = $(TB_DIR)/triplet_snn_tb.v
TRIPLET_TB_VERBOSE_SRC = $(TB_DIR)/triplet_snn_tb_verbose.v
DYNAMIC_RTL_SRC = $(RTL_DIR)/snn_dynamic.v
DYNAMIC_TB_SRC  = $(TB_DIR)/dynamic_snn_tb.v

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
	$(IVERILOG) -o snn_verbose $(RTL_SRC) $(TB_VERBOSE_SRC)
	$(VVP) snn_verbose

# Triplet SNN: compile and run training
triplet-train: $(TRIPLET_RTL_SRC) $(TRIPLET_TB_SRC)
	$(IVERILOG) -o triplet_snn_train $(TRIPLET_RTL_SRC) $(TRIPLET_TB_SRC)
	$(VVP) triplet_snn_train

# Triplet SNN: compile and run testing
triplet-test: $(TRIPLET_RTL_SRC) $(TRIPLET_TB_SRC)
	$(IVERILOG) -DTEST_ONLY -o triplet_snn_test $(TRIPLET_RTL_SRC) $(TRIPLET_TB_SRC)
	$(VVP) triplet_snn_test

# Triplet SNN: view waveforms
wave-triplet-train: triplet_snn_training.vcd
	gtkwave triplet_snn_training.vcd &

wave-triplet-test: triplet_snn_testing.vcd
	gtkwave triplet_snn_testing.vcd &

# Triplet SNN: verbose debug run
triplet-verbose: $(TRIPLET_RTL_SRC) $(TRIPLET_TB_VERBOSE_SRC)
	$(IVERILOG) -o triplet_snn_verbose $(TRIPLET_RTL_SRC) $(TRIPLET_TB_VERBOSE_SRC)
	$(VVP) triplet_snn_verbose

# Dynamic SNN: compile and run training (default W_BITS=4)
dynamic-train: $(DYNAMIC_RTL_SRC) $(DYNAMIC_TB_SRC)
	$(IVERILOG) -o dynamic_snn_train $(DYNAMIC_RTL_SRC) $(DYNAMIC_TB_SRC)
	$(VVP) dynamic_snn_train

# Dynamic SNN: compile and run testing (default W_BITS=4)
dynamic-test: $(DYNAMIC_RTL_SRC) $(DYNAMIC_TB_SRC)
	$(IVERILOG) -DTEST_ONLY -o dynamic_snn_test $(DYNAMIC_RTL_SRC) $(DYNAMIC_TB_SRC)
	$(VVP) dynamic_snn_test

# Dynamic SNN: 2-bit weight ablation
dynamic-test-2bit: $(DYNAMIC_RTL_SRC) $(DYNAMIC_TB_SRC)
	$(IVERILOG) -DTEST_ONLY -DW_BITS=2 -o dynamic_snn_test_2bit $(DYNAMIC_RTL_SRC) $(DYNAMIC_TB_SRC)
	$(VVP) dynamic_snn_test_2bit

# Generate weight heatmaps
plot:
	python3 $(VIZ_DIR)/plot_weights.py

# Clean build artifacts
clean:
	rm -f snn_train snn_test snn_verbose triplet_snn_train triplet_snn_test triplet_snn_verbose dynamic_snn_train dynamic_snn_test dynamic_snn_test_2bit *.vcd *.png

.PHONY: all train test wave-train wave-test verbose triplet-train triplet-test wave-triplet-train wave-triplet-test triplet-verbose dynamic-train dynamic-test dynamic-test-2bit plot clean
