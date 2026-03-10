# Case 2: Low-Frequency / Rate-Dependent Advantage of Triplet STDP

## What This Demonstrates

This case demonstrates the **frequency-dependent modulation** advantage of triplet STDP described in Pfister & Gerstner (2006). At moderate firing rates with subtle rate differences between BLACK and WHITE pixels, pair-based STDP treats each pre-post spike pair independently, applying a fixed-magnitude weight update regardless of the broader firing context. Triplet STDP's additional slow traces (o2 for post-synaptic, r2 for pre-synaptic) provide a form of **rate memory** that scales the weight update by recent activity, enabling finer discrimination.

### Key Insight from the Paper

Pair STDP's weight change is frequency-independent: doubling the firing rate doubles the number of spike pairs but each pair contributes the same fixed delta-w. Triplet STDP breaks this symmetry because the slow traces accumulate proportionally to the firing rate, amplifying potentiation at higher rates and modulating depression. This rate-dependent scaling allows triplet STDP to distinguish patterns that differ primarily in their temporal density.

## Evaluation Criteria

- **PASS**: Different output neurons win for different test digits
- **FAIL**: The same neuron wins for both test digits, or outputs are tied/identical

## Successful Examples

### Example 1 (C1-2)

| Config | WHITE (4 spikes) | BLACK (10 spikes) |
|--------|------------------|-------------------|
| Pattern | `0100000000010000000001000000000100000000` | `0100100001001000010010000100100001001000` |

Both patterns are **evenly spaced** (no bursts), differing only in rate (4 vs 10 spikes in 40 steps).

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 0, 4 | 0, 4 | **FAIL** (N2 wins both) |
| **Pair** | 4, 0 | 4, 2 | **FAIL** (N1 wins both) |
| **Triplet** | 4, 0 | 1, 3 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0100000000010000000001000000000100000000 SPIKE_BLACK=0100100001001000010010000100100001001000
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0100000000010000000001000000000100000000 SPIKE_BLACK=0100100001001000010010000100100001001000
# Triplet
make ablation SPIKE_WHITE=0100000000010000000001000000000100000000 SPIKE_BLACK=0100100001001000010010000100100001001000
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0100000000010000000001000000000100000000 SPIKE_BLACK=0100100001001000010010000100100001001000
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0100000000010000000001000000000100000000 SPIKE_BLACK=0100100001001000010010000100100001001000
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0100000000010000000001000000000100000000 SPIKE_BLACK=0100100001001000010010000100100001001000
```

### Example 2 (C2-31)

| Config | WHITE (4 spikes) | BLACK (10 spikes) |
|--------|------------------|-------------------|
| Pattern | `0010000000001000000000100000000010000000` | `0010010000100100001001000010010000100100` |

Again, both patterns are **evenly spaced** with no burst structure. The BLACK pattern has 2.5x the rate of WHITE.

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 0, 4 | 0, 4 | **FAIL** (N2 wins both) |
| **Pair** | 4, 0 | 4, 2 | **FAIL** (N1 wins both) |
| **Triplet** | 4, 0 | 1, 3 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0010000000001000000000100000000010000000 SPIKE_BLACK=0010010000100100001001000010010000100100
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0010000000001000000000100000000010000000 SPIKE_BLACK=0010010000100100001001000010010000100100
# Triplet
make ablation SPIKE_WHITE=0010000000001000000000100000000010000000 SPIKE_BLACK=0010010000100100001001000010010000100100
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0010000000001000000000100000000010000000 SPIKE_BLACK=0010010000100100001001000010010000100100
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0010000000001000000000100000000010000000 SPIKE_BLACK=0010010000100100001001000010010000100100
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0010000000001000000000100000000010000000 SPIKE_BLACK=0010010000100100001001000010010000100100
```

## Patterns That Failed (Instructive)

### Ultra-sparse patterns (C2-1 through C2-10)

With only 1-3 spikes per 40 steps, the network often couldn't generate enough post-synaptic spikes during training to trigger meaningful STDP learning. Most configurations produced 0-1 output spikes per test, making classification impossible for all three configurations.

**Lesson**: The triplet advantage requires enough baseline activity for the slow traces to accumulate differently between the two patterns. Below ~4 spikes per 40 steps, even triplet STDP lacks sufficient learning signal.

### High-contrast patterns (C2-32: 4 vs 12)

When the rate difference is very large (3:1 ratio), even pair STDP can differentiate — the sheer volume of spike pairs at the higher rate drives weights to different regimes.

**Lesson**: The triplet advantage is most pronounced at **moderate rate ratios** (~2:1 to 2.5:1) where pair STDP's fixed-magnitude updates fail to accumulate sufficient differential change.

## Analysis

### Why Pair STDP Fails

In both successful examples, pair STDP drives one neuron to dominate for *both* digit classes. The pair rule applies `A2_PLUS * r1[i]` for potentiation and `A2_MINUS * o1` for depression. With SYMMETRIC=1 (A2_PLUS = A2_MINUS = 1), the pair rule's potentiation and depression magnitudes are identical. At the moderate rates used here, the pair rule accumulates weight changes that are too similar across the two training images — the fixed delta-w per spike pair doesn't capture the rate difference well enough to create distinct weight maps.

### Why Triplet STDP Succeeds

Triplet STDP adds rate-sensitive modulation:
- **Potentiation**: `r1[i] * A2_PLUS + (r1[i] * o2) >> 4 * A3_PLUS` — the `o2` (slow post-synaptic trace) term amplifies potentiation when the post-neuron has been recently active. At higher input rates, the output neuron fires more, building up `o2`, which further enhances learning for the dominant pattern.
- **Depression**: `o1 * A2_MINUS + (o1 * r2[i]) >> 4 * A3_MINUS` — the `r2` (slow pre-synaptic trace) term provides memory of how active a given input has been.

This rate-dependent feedback loop means:
1. During '0' training, if Neuron 1 starts winning (more '0'-pattern inputs), its `o2` trace builds up, amplifying potentiation for '0'-correlated synapses while pair-based depression holds back '1'-correlated ones.
2. During '1' training, the same mechanism enables Neuron 2 to selectively strengthen '1'-correlated synapses.
3. The slow traces provide the critical **asymmetry** that allows the two neurons to specialize — something the rate-blind pair rule cannot achieve at these moderate rates.

### Connection to Pfister & Gerstner (2006)

The paper shows that triplet STDP reproduces the experimentally-observed frequency dependence of synaptic plasticity (Sjostrom et al. 2001), where the sign and magnitude of plasticity depend on the firing rate. Pair STDP predicts rate-independent plasticity, which contradicts experimental data. Our results confirm this: at the moderate rates tested here, the frequency-dependent triplet terms are essential for successful learning.
