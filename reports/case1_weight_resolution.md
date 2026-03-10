# Case 1: Weight Resolution Advantage

## What This Demonstrates

The original SNN uses **2-bit weights** (values 0-3) and **2-bit traces** (values 0-3), giving it only 4 possible weight levels per synapse. When the input patterns require fine-grained weight differentiation to separate two classes, these coarse weights cannot encode the necessary distinctions. The 4-bit configurations (pair STDP and triplet STDP) have **16 weight levels** (0-15), providing enough resolution to learn class-discriminative weight maps.

## Evaluation Criteria

- **PASS**: Different output neurons win for different test digits (Neuron 1 dominates for '0' and Neuron 2 for '1', or vice versa)
- **FAIL**: The same neuron wins for both test digits, or outputs are tied/identical

## Successful Examples

### Example 1 (C1-6)

| Config | WHITE (3 spikes) | BLACK (8 spikes) |
|--------|------------------|-------------------|
| Pattern | `0000000000001000000000000010000000001000` | `0000100001000010000100001000010000100010` |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 3, 3 | 1, 1 | **FAIL** (tied both) |
| **Pair** | 2, 0 | 1, 2 | **PASS** (N1 for 0, N2 for 1) |
| **Triplet** | 2, 0 | 1, 2 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000000000001000000000000010000000001000 SPIKE_BLACK=0000100001000010000100001000010000100010
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000000000001000000000000010000000001000 SPIKE_BLACK=0000100001000010000100001000010000100010
# Triplet
make ablation SPIKE_WHITE=0000000000001000000000000010000000001000 SPIKE_BLACK=0000100001000010000100001000010000100010
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000000000001000000000000010000000001000 SPIKE_BLACK=0000100001000010000100001000010000100010
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000000000001000000000000010000000001000 SPIKE_BLACK=0000100001000010000100001000010000100010
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000000000001000000000000010000000001000 SPIKE_BLACK=0000100001000010000100001000010000100010
```

### Example 2 (C1-9)

| Config | WHITE (3 spikes) | BLACK (9 spikes) |
|--------|------------------|-------------------|
| Pattern | `0000001000000000000100000000000010000000` | `0001000100010001000100010001000100010000` |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 3, 2 | 3, 3 | **FAIL** (no clear separation) |
| **Pair** | 3, 0 | 0, 3 | **PASS** (N1 for 0, N2 for 1) |
| **Triplet** | 3, 0 | 0, 2 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000001000000000000100000000000010000000 SPIKE_BLACK=0001000100010001000100010001000100010000
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000001000000000000100000000000010000000 SPIKE_BLACK=0001000100010001000100010001000100010000
# Triplet
make ablation SPIKE_WHITE=0000001000000000000100000000000010000000 SPIKE_BLACK=0001000100010001000100010001000100010000
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000001000000000000100000000000010000000 SPIKE_BLACK=0001000100010001000100010001000100010000
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000001000000000000100000000000010000000 SPIKE_BLACK=0001000100010001000100010001000100010000
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000001000000000000100000000000010000000 SPIKE_BLACK=0001000100010001000100010001000100010000
```

### Example 3 (C2-7)

| Config | WHITE (2 spikes) | BLACK (3 spikes) |
|--------|------------------|-------------------|
| Pattern | `0000000000100000000000000000100000000000` | `0000000001110000000000000000000000000000` |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 1, 0 | 1, 0 | **FAIL** (N1 wins both) |
| **Pair** | 1, 0 | 0, 1 | **PASS** (N1 for 0, N2 for 1) |
| **Triplet** | 1, 0 | 0, 1 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000000000100000000000000000100000000000 SPIKE_BLACK=0000000001110000000000000000000000000000
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000000000100000000000000000100000000000 SPIKE_BLACK=0000000001110000000000000000000000000000
# Triplet
make ablation SPIKE_WHITE=0000000000100000000000000000100000000000 SPIKE_BLACK=0000000001110000000000000000000000000000
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000000000100000000000000000100000000000 SPIKE_BLACK=0000000001110000000000000000000000000000
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000000000100000000000000000100000000000 SPIKE_BLACK=0000000001110000000000000000000000000000
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000000000100000000000000000100000000000 SPIKE_BLACK=0000000001110000000000000000000000000000
```

### Example 4 (C2-28)

| Config | WHITE (4 spikes) | BLACK (10 spikes) |
|--------|------------------|-------------------|
| Pattern | `0001000000001000000000100000000010000000` | `0010010001001001000100100100100100000000` |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 4, 4 | 4, 4 | **FAIL** (tied both) |
| **Pair** | 3, 0 | 1, 2 | **PASS** (N1 for 0, N2 for 1) |
| **Triplet** | 3, 1 | 0, 3 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0001000000001000000000100000000010000000 SPIKE_BLACK=0010010001001001000100100100100100000000
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0001000000001000000000100000000010000000 SPIKE_BLACK=0010010001001001000100100100100100000000
# Triplet
make ablation SPIKE_WHITE=0001000000001000000000100000000010000000 SPIKE_BLACK=0010010001001001000100100100100100000000
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0001000000001000000000100000000010000000 SPIKE_BLACK=0010010001001001000100100100100100000000
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0001000000001000000000100000000010000000 SPIKE_BLACK=0010010001001001000100100100100100000000
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0001000000001000000000100000000010000000 SPIKE_BLACK=0010010001001001000100100100100100000000
```

### Example 5 (C2-30)

| Config | WHITE (4 spikes) | BLACK (9 spikes) |
|--------|------------------|-------------------|
| Pattern | `0000000000010000000001000000000100000001` | `0010001000100010001000100010001000100000` |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 3, 0 | 3, 0 | **FAIL** (N1 wins both) |
| **Pair** | 3, 0 | 0, 3 | **PASS** (N1 for 0, N2 for 1) |
| **Triplet** | 3, 0 | 0, 2 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000000000010000000001000000000100000001 SPIKE_BLACK=0010001000100010001000100010001000100000
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000000000010000000001000000000100000001 SPIKE_BLACK=0010001000100010001000100010001000100000
# Triplet
make ablation SPIKE_WHITE=0000000000010000000001000000000100000001 SPIKE_BLACK=0010001000100010001000100010001000100000
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000000000010000000001000000000100000001 SPIKE_BLACK=0010001000100010001000100010001000100000
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000000000010000000001000000000100000001 SPIKE_BLACK=0010001000100010001000100010001000100000
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000000000010000000001000000000100000001 SPIKE_BLACK=0010001000100010001000100010001000100000
```

### Example 6 (C2-32)

| Config | WHITE (4 spikes) | BLACK (12 spikes) |
|--------|------------------|-------------------|
| Pattern | `0000100000000010000000001000000000100000` | `0010010010010010010010010010010010010000` |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 4, 4 | 4, 4 | **FAIL** (tied both) |
| **Pair** | 4, 0 | 0, 4 | **PASS** (N1 for 0, N2 for 1) |
| **Triplet** | 2, 0 | 0, 1 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000100000000010000000001000000000100000 SPIKE_BLACK=0010010010010010010010010010010010010000
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000100000000010000000001000000000100000 SPIKE_BLACK=0010010010010010010010010010010010010000
# Triplet
make ablation SPIKE_WHITE=0000100000000010000000001000000000100000 SPIKE_BLACK=0010010010010010010010010010010010010000
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000100000000010000000001000000000100000 SPIKE_BLACK=0010010010010010010010010010010010010000
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000100000000010000000001000000000100000 SPIKE_BLACK=0010010010010010010010010010010010010000
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000100000000010000000001000000000100000 SPIKE_BLACK=0010010010010010010010010010010010010000
```

## Analysis

### Why the Original (2-bit) Fails

1. **Weight saturation**: With only 4 weight levels (0-3), STDP quickly drives weights to the extremes (0 or 3). Both output neurons end up with nearly identical weight maps because there aren't enough intermediate values to encode subtle differences between the '0' and '1' digit patterns.

2. **Coarse traces**: The 2-bit traces (0-3) provide very limited temporal memory. The trace decays in just 1-2 cycles, so the STDP window is extremely narrow. This prevents the network from learning meaningful timing-based correlations between pre and post-synaptic spikes.

3. **Quantization noise**: When the STDP rule computes a weight update (e.g., potentiate by 0.7), the 2-bit system must round to 0 or 1. This rounding error accumulates over training, washing out the small but important differences between the two digit classes.

### Why 4-bit Pair and Triplet Both Succeed

With 16 weight levels and 16-level traces, both 4-bit configurations can:
- Maintain distinct weight gradients between black (high-frequency) and white (low-frequency) input pixels
- Accumulate small, precise weight changes that gradually differentiate the two output neurons
- Use longer-lived traces (4-bit traces persist for ~4 decay steps) to capture spike correlations over a wider temporal window

The patterns in this case don't specifically require triplet interactions — the advantage comes purely from increased precision. This confirms that **weight and trace resolution is the foundational requirement** for STDP-based learning.
