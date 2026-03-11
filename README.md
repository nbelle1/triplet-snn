# Triplet STDP Spiking Neural Network

Verilog implementation of triplet STDP (Pfister & Gerstner, 2006) for a 2-layer SNN that classifies 5x5 binary images of digits '0' and '1'.

## RTL Modules

**`rtl/snn_network.v`** — Static pair-based STDP (HW4 baseline). 2-bit weights, shift-register spike history, IF neurons.

**`rtl/triplet_snn.v`** — Static triplet STDP. 4-bit weights, decaying trace variables, LIF neurons, asymmetric A3 parameters.

**`rtl/snn_dynamic.v`** — Parameterized design that can replicate both modules above. All architecture choices exposed as parameters. This is the primary module used for experiments.

## Setup

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Requires `iverilog` and `vvp` for simulation.

## Running the Parameterized Model (`snn_dynamic.v`)

### Train + Test (ablation)

```bash
make ablation                          # default: triplet STDP, 4-bit, LIF
make ablation TRIPLET_EN=0             # pair-based STDP (same architecture, triplet terms off)
```

### With custom spike patterns

```bash
make ablation TRIPLET_EN=1 SPIKE_WHITE=0100000000010000000001000000000100000000 SPIKE_BLACK=0100100001001000010010000100100001001000
```

### Weight heatmap visualization

```bash
make plot-dynamic                      # default triplet config
make plot-dynamic TRIPLET_EN=0         # pair-based
make plot-dynamic SPIKE_WHITE=... SPIKE_BLACK=...   # custom patterns
```

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `W_BITS` | 4 | Weight bit-width (2 = HW4 original, 4 = extended) |
| `TRACE_BITS` | 4 | Trace register width |
| `TRIPLET_EN` | 1 | 1 = triplet STDP, 0 = pair-based only |
| `MODE` | 0 | 0 = all-to-all, 1 = nearest-neighbor |
| `LEAK_EN` | 1 | 1 = LIF, 0 = IF |
| `SYMMETRIC` | 1 | 1 = A2_PLUS = A2_MINUS, 0 = asymmetric pair params |
| `SPIKE_WHITE` | (4 spikes, evenly spaced) | 40-bit spike train for white pixels |
| `SPIKE_BLACK` | (14 spikes, doublet bursts) | 40-bit spike train for black pixels |

### Named presets

```bash
make ablation-original    # replicates snn_network.v (2-bit, pair, IF)
make ablation-pair        # trace-based pair STDP (4-bit, LIF)
make ablation-triplet     # triplet STDP (4-bit, LIF)
```

## Data Collection

### Generic Spike Trains

#### Case 0.1: Pair-based, 2-bit weights, 20-bit spike trains

```bash
make ablation-original SPIKE_WHITE=01000000100000000010 SPIKE_BLACK=01000000100000000010
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=01000000100000000010 SPIKE_BLACK=01010100010101000101
```

#### Case 0.2: Pair-based, 2-bit weights, 40-bit spike trains

```bash
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000000000001000000000000010000000001000 SPIKE_BLACK=0000100001000010000100001000010000100010
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000000000001000000000000010000000001000 SPIKE_BLACK=0000100001000010000100001000010000100010
```

#### Case 1.1: Pair-based, 4-bit weights, 40-bit spike trains

```bash
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000000000001000000000000010000000001000 SPIKE_BLACK=0000100001000010000100001000010000100010
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000000000001000000000000010000000001000 SPIKE_BLACK=0000100001000010000100001000010000100010
```

#### Case 1.2: Triplet, 4-bit weights, 40-bit spike trains

```bash
make ablation SPIKE_WHITE=0000000000001000000000000010000000001000 SPIKE_BLACK=0000100001000010000100001000010000100010
make plot-dynamic SPIKE_WHITE=0000000000001000000000000010000000001000 SPIKE_BLACK=0000100001000010000100001000010000100010
```

### Spike Frequency Changes

#### Case 2.1: Pair-based, 4-bit weights, 40-bit spike trains

```bash
make ablation TRIPLET_EN=0 SPIKE_WHITE=0010000000001000000000100000000010000000 SPIKE_BLACK=0010010000100100001001000010010000100100
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0010000000001000000000100000000010000000 SPIKE_BLACK=0010010000100100001001000010010000100100
```

#### Case 2.2: Triplet, 4-bit weights, 40-bit spike trains

```bash
make ablation SPIKE_WHITE=0010000000001000000000100000000010000000 SPIKE_BLACK=0010010000100100001001000010010000100100
make plot-dynamic SPIKE_WHITE=0010000000001000000000100000000010000000 SPIKE_BLACK=0010010000100100001001000010010000100100
```

### High-Frequency Burst Spike Trains

#### Case 3.1: Pair-based, 4-bit weights, 40-bit spike trains

```bash
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000100000001000000010000000100000000000 SPIKE_BLACK=0001110000000111000000011100000001110000
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000100000001000000010000000100000000000 SPIKE_BLACK=0001110000000111000000011100000001110000
```

#### Case 3.2: Triplet, 4-bit weights, 40-bit spike trains

```bash
make ablation SPIKE_WHITE=0000100000001000000010000000100000000000 SPIKE_BLACK=0001110000000111000000011100000001110000
make plot-dynamic SPIKE_WHITE=0000100000001000000010000000100000000000 SPIKE_BLACK=0001110000000111000000011100000001110000
```

## Complete Results

Complete results can be found in the directory **`results/`**.
