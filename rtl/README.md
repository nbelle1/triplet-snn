# RTL Modules

## snn_network.v

Pair-based STDP spiking neural network from Homework 4. Uses 2-bit weights, shift-register traces (2-cycle memory), and integrate-and-fire (IF) neurons with no leak. Classifies 5x5 binary images of "0" and "1" using two output neurons with lateral inhibition. This is the baseline for comparison.

```bash
make test      # train + test
make verbose   # detailed per-cycle output
```

## triplet_snn.v

Fixed-parameter triplet STDP implementation (Pfister & Gerstner 2006). Extends the pair-based rule with slow traces that modulate weight updates based on recent spike history. Uses 4-bit weights, 4-bit trace registers, LIF neurons with widened 10-bit membrane potential, and asymmetric A parameters (stronger depression). Classifies the same 5x5 "0"/"1" images.

```bash
make triplet-test      # train + test
make triplet-verbose   # detailed per-cycle output
```

## snn_dynamic.v

Parameterized SNN that can replicate both modules above and explore configurations in between. All architecture choices are exposed as parameters:

| Parameter | Default | Description |
|---|---|---|
| `W_BITS` | 4 | Weight bit-width (2 = original, 4 = extended, 8 = high precision) |
| `TRACE_BITS` | 4 | Trace register width (2 = 2-cycle window like original, 4 = 4-cycle) |
| `TRIPLET_EN` | 1 | 1 = triplet STDP, 0 = pair-based only |
| `MODE` | 0 | 0 = all-to-all, 1 = nearest-neighbor |
| `LEAK_EN` | 1 | 1 = LIF (leaky), 0 = IF (no leak, like original) |
| `SYMMETRIC` | 0 | 1 = symmetric LTP/LTD (A2_MINUS = A2_PLUS), 0 = asymmetric (A2_MINUS = 3) |

Membrane potential, thresholds, and STDP scaling all derive automatically from these parameters.

### Running ablations

Pass any combination of parameters on the command line:

```bash
# custom configuration
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SYMMETRIC=1

# asymmetric pair vs asymmetric triplet
make ablation TRIPLET_EN=0 SYMMETRIC=0
make ablation TRIPLET_EN=1 SYMMETRIC=0

# symmetric pair (isolate triplet advantage from asymmetry advantage)
make ablation TRIPLET_EN=0 SYMMETRIC=1

# multiple training epochs
make ablation NUM_EPOCHS=3

# mix and match
make ablation W_BITS=8 MODE=1 TRIPLET_EN=0
```

### Named presets

```bash
make ablation-original   # replicates snn_network.v  (2-bit, pair, IF, symmetric)
make ablation-pair       # trace-based pair STDP      (4-bit, LIF, asymmetric)
make ablation-triplet    # triplet STDP               (4-bit, LIF, asymmetric)
make ablation-nn         # nearest-neighbor triplet   (4-bit, LIF, asymmetric)
```

Each run prints its configuration at the top of the output for easy comparison. Spike train length is determined by the pattern definitions in the testbench (`tb/dynamic_snn_tb.v`) — change the patterns there to experiment with different input encodings.
