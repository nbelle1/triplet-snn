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
