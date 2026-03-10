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

# ============================================================
# Dynamic SNN ablation framework
# ============================================================
# Defaults (override on command line)
W_BITS     ?= 4
TRACE_BITS ?= 4
TRIPLET_EN ?= 1
MODE       ?= 0
LEAK_EN    ?= 1
SYMMETRIC  ?= 1
NUM_EPOCHS ?= 1
SPIKE_WHITE ?= 1000000000100000000010000000001000000000
SPIKE_BLACK ?= 1100110000001100110000001100110000001100
OUT_PATH	?= out.png

# Build -D flags from variables
DFLAGS = -DW_BITS=$(W_BITS) -DTRACE_BITS=$(TRACE_BITS) -DTRIPLET_EN=$(TRIPLET_EN) \
         -DMODE=$(MODE) -DLEAK_EN=$(LEAK_EN) -DSYMMETRIC=$(SYMMETRIC) -DNUM_EPOCHS=$(NUM_EPOCHS) \
         "-DSPIKE_WHITE=40'b$(SPIKE_WHITE)" "-DSPIKE_BLACK=40'b$(SPIKE_BLACK)"

# Generic ablation target: pass any combination of parameters
#   make ablation W_BITS=2 TRIPLET_EN=0 TRACE_BITS=2 LEAK_EN=0
ablation: $(DYNAMIC_RTL_SRC) $(DYNAMIC_TB_SRC)
	$(IVERILOG) $(DFLAGS) -o dynamic_snn_ablation $(DYNAMIC_RTL_SRC) $(DYNAMIC_TB_SRC)
	$(VVP) dynamic_snn_ablation

# Named presets for common configurations
ablation-original: ## Original snn_network equivalent
	$(MAKE) ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SYMMETRIC=1

ablation-pair: ## Trace-based pair STDP (4-bit, LIF)
	$(MAKE) ablation TRIPLET_EN=0

ablation-triplet: ## Triplet STDP (4-bit, LIF) — default
	$(MAKE) ablation

ablation-nn: ## Nearest-neighbor triplet
	$(MAKE) ablation MODE=1

# Generate weight heatmaps (use: make plot, make plot-triplet, make plot-dynamic)
plot:
	python3 $(VIZ_DIR)/plot_weights.py snn

plot-triplet:
	python3 $(VIZ_DIR)/plot_weights.py triplet

plot-dynamic:
	python3 $(VIZ_DIR)/plot_weights.py dynamic --make-args W_BITS=$(W_BITS) TRACE_BITS=$(TRACE_BITS) TRIPLET_EN=$(TRIPLET_EN) MODE=$(MODE) LEAK_EN=$(LEAK_EN) SYMMETRIC=$(SYMMETRIC) NUM_EPOCHS=$(NUM_EPOCHS) SPIKE_BLACK=$(SPIKE_BLACK) SPIKE_WHITE=$(SPIKE_WHITE) OUT_PATH=$(VIZ_DIR)/$(OUT_PATH)

plot-dynamic-original:
	$(MAKE) plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SYMMETRIC=1

plot-dynamic-pair:
	$(MAKE) plot-dynamic TRIPLET_EN=0

plot-dynamic-triplet:
	$(MAKE) plot-dynamic

plot-dynamic-nn:
	$(MAKE) plot-dynamic MODE=1

# Clean build artifacts
clean:
	rm -f snn_train snn_test snn_verbose triplet_snn_train triplet_snn_test triplet_snn_verbose dynamic_snn_ablation *.vcd *.png

.PHONY: all train test wave-train wave-test verbose triplet-train triplet-test wave-triplet-train wave-triplet-test triplet-verbose ablation ablation-original ablation-pair ablation-triplet ablation-nn plot plot-triplet plot-dynamic plot-dynamic-original plot-dynamic-pair plot-dynamic-triplet plot-dynamic-nn clean
