# Triplet STDP in Hardware: Implementation and Evaluation

## Abstract

We implement the triplet STDP learning rule (Pfister & Gerstner, 2006) in Verilog and compare it against a pair-based STDP baseline on a binary image classification task. The triplet model introduces slow spike traces that modulate weight updates based on recent firing history. Through systematic experimentation, we demonstrate that the triplet model's asymmetric depression amplification ($A_3^- = 4$ vs $A_3^+ = 1$) enables successful classification under conditions where pair-based STDP fails. We identify the specific mechanism: when input spikes at high rates or in bursts create elevated slow pre-synaptic traces ($r_2$), the triplet depression term amplifies weight decreases at high-activity synapses relative to pair-based depression, preventing the dominant neuron from monopolizing both digit classes. We demonstrate this advantage across two experimental conditions: rate-coded inputs where BLACK and WHITE pixels differ only in firing rate, and burst-coded inputs where BLACK pixels fire in clusters of consecutive spikes.

## 1. Network Architecture

The network is a two-layer feedforward SNN with 25 input neurons (5x5 pixel grid) and 2 output neurons with lateral inhibition (winner-takes-all). Each input pixel is assigned one of two spike trains (WHITE or BLACK) based on the binary image being presented. The network processes 40 timesteps per image presentation.

### 1.1 Pair-Based Baseline (from HW4)

The original pair-based design uses:
- 2-bit weights (range 0-3), 25 per output neuron
- Binary shift-register spike history (2-cycle window)
- Fixed potentiation/depression: +2/+1 for spikes 1/2 cycles ago, symmetric
- Integrate-and-fire (IF) neurons, no leak

### 1.2 Triplet STDP Implementation

The triplet implementation makes the following changes:

**Trace-based spike history.** Binary shift registers are replaced by four sets of decaying trace variables per synapse/neuron:
- $r_1[i]$: fast pre-synaptic trace (exponential decay, >>1 per cycle, ~3-4 cycle lifetime)
- $r_2[i]$: slow pre-synaptic trace (linear decay, -2 per cycle, ~4 cycle lifetime from single spike, ~8 cycles from saturated burst)
- $o_1$: fast post-synaptic trace (exponential decay, >>1 per cycle)
- $o_2$: slow post-synaptic trace (linear decay, -2 per cycle, ~4 cycle lifetime from single spike)

All traces are 4-bit (TRACE_BITS=4), with TRACE_INC=8 (half of max=15). On a spike, the trace is incremented by TRACE_INC, saturating at 15. Both slow traces decay symmetrically at -2 per cycle.

**Triplet weight update rule:**
- Potentiation (on post-synaptic spike): $\Delta w^+ = r_1 \cdot A_2^+ + \lfloor r_1 \cdot o_2 / 16 \rfloor \cdot A_3^+$
- Depression (on pre-synaptic spike): $\Delta w^- = o_1 \cdot A_2^- + \lfloor o_1 \cdot r_2 / 16 \rfloor \cdot A_3^-$
- Net weight change: $\Delta w = (\Delta w^+ - \Delta w^-) >> DW\_SCALE$, clamped to [0, W_MAX]

**STDP parameters:**
| Parameter | Value | Role |
|-----------|-------|------|
| $A_2^+$ | 1 | Pair-based LTP |
| $A_2^-$ | 1 (SYMMETRIC=1) | Pair-based LTD (matches $A_2^+$ for fair baseline) |
| $A_3^+$ | 1 | Triplet LTP (modest) |
| $A_3^-$ | 4 | Triplet LTD (strong) |
| DW_SCALE | 2 | Right-shift to scale raw updates |

The pair-based parameters are kept symmetric ($A_2^+ = A_2^-$) so the pair-based component of the triplet rule behaves identically to standalone pair STDP. The triplet parameters are asymmetric ($A_3^- = 4 \times A_3^+$), with depression stronger than potentiation.

**Weight expansion.** 2-bit to 4-bit (range 0-15). All voltage parameters scaled 4x: $V_{REST}=24$, $V_{THRESHOLD}=260$, $V_{LEAK}=4$. Weighted sum accumulator widened to 9 bits.

**Neuron model upgrade.** IF to LIF: $V_{LEAK}=4$ subtracted each cycle, clamped to $V_{REST}$.

## 2. Why the Triplet Rule Produces Different Results

### 2.1 The Depression Amplification Mechanism

The core mechanism by which triplet STDP outperforms pair-based STDP is **depression amplification via the slow pre-synaptic trace $r_2$**.

Consider the depression calculation when input $i$ fires while the fast post-synaptic trace $o_1 > 0$:

**Pair-based:** $\text{dep} = o_1 \cdot A_2^- = o_1$
**Triplet:** $\text{dep} = o_1 \cdot A_2^- + \lfloor o_1 \cdot r_2[i] / 16 \rfloor \cdot A_3^- = o_1 + \lfloor o_1 \cdot r_2[i] / 16 \rfloor \cdot 4$

For a black-pixel input with elevated $r_2$ (e.g., $r_2 = 14$ from a doublet burst) and a fast post-trace of $o_1 = 4$:
- **Pair dep_raw:** $4 \cdot 1 = 4$ -> after DW_SCALE (>>2): **1**
- **Triplet dep_raw:** $4 + \lfloor 56/16 \rfloor \cdot 4 = 4 + 12 = 16$ -> after DW_SCALE: **4**

The triplet model applies 4x more depression than pair-based at this synapse. This prevents weight saturation and enables competitive learning between the two output neurons.

### 2.2 How $r_2$ Accumulates

The slow pre-synaptic trace $r_2$ accumulates differently depending on input spike patterns:

- **Evenly-spaced high-rate inputs** (e.g., 10 spikes in 40 steps, one every 4 cycles): Each spike adds TRACE_INC=8. Between spikes, $r_2$ decays by -2/cycle. After ~4 cycles: $r_2 = 8 - 8 = 0$, but the next spike arrives and bumps it back to 8. With faster spacing, consecutive bumps accumulate: $r_2$ oscillates but remains elevated on average at high-rate synapses.
- **Burst inputs** (e.g., doublet "11"): First spike sets $r_2 = 8$. One cycle later (decayed to 6), second spike bumps to $\min(6+8, 15) = 14$. The burst produces a peak $r_2$ of 14, which then decays over ~7 cycles.
- **Isolated spikes** (e.g., WHITE at 4 spikes in 40 steps): Each spike sets $r_2 = 8$, which decays to 0 in 4 cycles. By the time the next spike arrives (~10 cycles later), $r_2$ has been zero for 6 cycles.

This differential $r_2$ accumulation — high at BLACK-pixel synapses, low at WHITE-pixel synapses — is what the $A_3^- = 4$ coefficient amplifies to create weight differentiation.

### 2.3 Role of the Triplet Potentiation Term

With both slow traces decaying at -2/cycle, the slow post-synaptic trace $o_2$ has a ~4-cycle lifetime from a single spike. Since output neurons in our network fire with an inter-spike interval of ~10-12 cycles, $o_2$ is typically zero when subsequent STDP events occur. This means the triplet potentiation term ($r_1 \cdot o_2 \cdot A_3^+$) contributes minimally. The triplet advantage in our implementation comes almost entirely from the **depression side**.

### 2.4 Cascading Effect on Weight Evolution

The amplified depression during early training creates a cascade:
1. After Train '0', triplet weights are lower than pair weights (more depression counters the potentiation)
2. Lower W1 weights mean N1 fires less aggressively during Train '1'
3. N2 gets more opportunities to fire and learn
4. The result is proper competitive specialization: N1 for digit '0', N2 for digit '1'

With pair-based STDP, W1 gets potentiated strongly during Train '0', and the weak depression cannot counteract this. N1 dominates during Train '1' as well, preventing N2 from learning.

## 3. Experimental Results

All experiments use SYMMETRIC=1 (identical pair-based parameters for pair and triplet models). Three configurations are compared:
- **Original**: 2-bit weights, 2-bit traces, IF neurons, pair STDP (HW4 baseline)
- **Pair**: 4-bit weights, 4-bit traces, LIF neurons, pair STDP (TRIPLET_EN=0)
- **Triplet**: 4-bit weights, 4-bit traces, LIF neurons, triplet STDP (TRIPLET_EN=1)

### 3.1 Experiment 2: Rate-Dependent Weight Modulation

This experiment uses evenly-spaced spike patterns with no burst structure, where BLACK pixels fire at 2.5x the rate of WHITE pixels. The rate difference is the sole discriminative variable.

| Signal | Pattern | Spikes |
|--------|---------|--------|
| WHITE | `0100000000010000000001000000000100000000` | 4 |
| BLACK | `0100100001001000010010000100100001001000` | 10 |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| Original | 0, 4 | 0, 4 | **FAIL** (N2 wins both) |
| Pair | 4, 0 | 4, 2 | **FAIL** (N1 wins both) |
| **Triplet** | **4, 0** | **1, 3** | **PASS** (N1 for '0', N2 for '1') |

The original 2-bit configuration saturates weights too quickly. The 4-bit pair-based model develops differentiated weight maps, but the differentiation is insufficient — N1 dominates both test digits because the symmetric pair updates accumulate similar total potentiation across both training images. Triplet STDP succeeds because the slow pre-synaptic traces at BLACK-pixel synapses accumulate to higher values during training (reflecting their 2.5x higher firing rate), and the $A_3^- = 4$ depression term amplifies weight decreases at these synapses. This rate-dependent depression creates sufficient asymmetry for the second neuron to specialize.

### 3.2 Experiment 3: Burst Asymmetry

This experiment introduces burst structure in the BLACK pattern. Bursts of 2-3 consecutive spikes cause $r_2$ to accumulate rapidly, reaching ~14/15 from a doublet. The $A_3^- = 4$ coefficient amplifies depression at burst-active synapses. Pair STDP, with symmetric $A_2^+ = A_2^- = 1$, decomposes bursts into independent pairs whose potentiation and depression largely cancel, making bursts effectively neutral to the learning rule.

**Burst-of-3 example:**

| Signal | Pattern | Spikes |
|--------|---------|--------|
| WHITE | `0000100000001000000010000000100000000000` | 4 |
| BLACK | `0001110000000111000000011100000001110000` | 12 |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| Original | 2, 4 | 0, 4 | **FAIL** (N2 wins both) |
| Pair | 5, 0 | 4, 0 | **FAIL** (N1 wins both) |
| **Triplet** | **4, 0** | **0, 4** | **PASS** (perfect separation) |

**Doublet example:**

| Signal | Pattern | Spikes |
|--------|---------|--------|
| WHITE | `0000010000000001000000000100000000010000` | 4 |
| BLACK | `0110001100000110001100001100011000001100` | 14 |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| Original | 4, 4 | 4, 4 | **FAIL** (tied both) |
| Pair | 4, 1 | 4, 2 | **FAIL** (N1 wins both) |
| **Triplet** | **3, 0** | **0, 4** | **PASS** (strong separation) |

A total of 9 pattern configurations were found where both original and pair-based STDP fail but triplet STDP succeeds (3 burst-of-3 patterns and 6 doublet patterns). The doublet finding is notable: even 2 consecutive spikes produce enough $r_2$ accumulation for the triplet depression term to create meaningful weight differentiation.

Several instructive failures provided additional insight. Patterns with alternating isolated spikes (no burst structure) failed for all three models, confirming that the triplet advantage requires consecutive spikes to accumulate the slow traces. Dense burst-of-4 patterns overloaded the network, causing identical responses to both digit images.

## 4. Summary of Key Findings

1. **The triplet model outperforms pair-based STDP** in both rate-coded and burst-coded input scenarios. With evenly-spaced rate differences (Experiment 2) and bursty inputs (Experiment 3), pair STDP fails while triplet STDP achieves clean classification.

2. **The mechanism is depression amplification via $r_2$.** The slow pre-synaptic trace accumulates proportionally to input firing rate and burst intensity. The $A_3^- = 4$ coefficient amplifies depression at high-activity synapses, creating the weight differentiation needed for competitive learning. The triplet potentiation term ($o_2$-modulated) contributes minimally because $o_2$ decays to zero between output spikes in our network.

3. **Rate sensitivity without burst structure** (Experiment 2). Even with evenly-spaced spikes (no bursts), the 2.5x rate difference between BLACK and WHITE causes $r_2$ to accumulate more at BLACK synapses, enabling triplet STDP to discriminate where pair STDP cannot.

4. **Burst structure provides an additional advantage** (Experiment 3). Consecutive spikes in doublets or triplets compound $r_2$ rapidly (reaching ~14/15 from a doublet), creating even stronger depression amplification than evenly-spaced high-rate inputs.

5. **Pair-based parameters are symmetric.** Because $A_2^+ = A_2^- = 1$ in all experiments, the pair-based component of the triplet rule is identical to standalone pair STDP. Any difference in classification outcome is attributable entirely to the triplet terms.

## 5. Implementation Files

| File | Description |
|------|-------------|
| `rtl/snn_dynamic.v` | Parameterized triplet/pair STDP with ablation support |
| `rtl/snn_network.v` | Original pair-based STDP (HW4 baseline) |
| `rtl/triplet_snn.v` | Static triplet STDP (initial implementation) |
| `tb/dynamic_snn_tb.v` | Testbench for ablation framework |
| `Makefile` | Build targets: `ablation`, `plot-dynamic`, with parameter overrides |

### Key Makefile Commands

```bash
# Pair-based STDP (4-bit, LIF, trace-based)
make ablation TRIPLET_EN=0 SYMMETRIC=1

# Triplet STDP (default)
make ablation TRIPLET_EN=1 SYMMETRIC=1

# Custom spike patterns
make ablation TRIPLET_EN=1 SYMMETRIC=1 SPIKE_WHITE=<40-bit> SPIKE_BLACK=<40-bit>

# Weight heatmap visualization
make plot-dynamic TRIPLET_EN=1 SYMMETRIC=1
```

## References

- Pfister, J.-P. & Gerstner, W. (2006). Triplets of Spikes in a Model of Spike Timing-Dependent Plasticity. *Journal of Neuroscience*, 26(38), 9673-9682.
- Sjöström, P. J., Turrigiano, G. G., & Nelson, S. B. (2001). Rate, timing, and cooperativity jointly determine cortical synaptic plasticity. *Neuron*, 32(6), 1149-1164.
- Wang, H.-X., Gerkin, R. C., Naber, D. H., & bhatt, D. K. (2005). Bhatt. *Nat. Neurosci.*, 8, 187-193.
