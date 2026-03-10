# Case 3: Burst Asymmetry Advantage of Triplet STDP

## What This Demonstrates

This case demonstrates the **triplet interaction asymmetry** described in Pfister & Gerstner (2006). When input spike patterns contain burst structure (clusters of 2-3 consecutive spikes), triplet STDP can extract information from the resulting pre-post-pre and post-pre-post spike triplets that pair-based STDP cannot.

### Key Insight from the Paper

- **Pair STDP**: A pre-post-pre triplet produces one LTP event (pre-before-post) and one LTD event (post-before-pre), which largely cancel. Similarly, post-pre-post produces one LTD and one LTP that cancel. With symmetric parameters (A2_PLUS = A2_MINUS), bursts are effectively "neutral" to pair STDP.
- **Triplet STDP**: These triplets do NOT cancel:
  - **Post-pre-post**: The second post spike's potentiation is amplified by the slow post-synaptic trace (`o2`) left by the first post spike. Net result: **enhanced LTP**.
  - **Pre-post-pre**: The second pre spike's depression is amplified by the slow pre-synaptic trace (`r2`) left by the first pre spike. Net result: **enhanced LTD** (amplified 4x via A3_MINUS=4).
- This asymmetry means triplet STDP can leverage burst patterns for learning, while pair STDP sees bursts as roughly neutral.

## Evaluation Criteria

- **PASS**: Different output neurons win for different test digits (strictly more spikes)
- **FAIL**: The same neuron wins for both test digits, or outputs are tied/identical

## Configuration Parameters

| Config | W_BITS | TRACE_BITS | TRIPLET_EN | LEAK_EN | SYMMETRIC |
|--------|--------|------------|------------|---------|-----------|
| `ablation-original` | 2 | 2 | 0 | 0 | 1 |
| `ablation-pair` | 4 | 4 | 0 | 1 | 1 |
| `ablation-triplet` | 4 | 4 | 1 | 1 | 1 |

## Successful Examples: Burst-of-3 Patterns

These patterns use BLACK with 3 consecutive spikes (`111`) separated by gaps.

### Example 1 (Burst-of-3, regular spacing)

| Signal | Pattern (40-bit) | Spike count |
|--------|------------------|-------------|
| WHITE | `0000100000001000000010000000100000001000` | 5 |
| BLACK | `0001110000000011100000000111000000011100` | 12 |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 1, 5 | 0, 5 | **FAIL** (N2 wins both) |
| **Pair** | 4, 0 | 4, 0 | **FAIL** (N1 wins both) |
| **Triplet** | 4, 1 | 1, 4 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000100000001000000010000000100000001000 SPIKE_BLACK=0001110000000011100000000111000000011100
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000100000001000000010000000100000001000 SPIKE_BLACK=0001110000000011100000000111000000011100
# Triplet
make ablation SPIKE_WHITE=0000100000001000000010000000100000001000 SPIKE_BLACK=0001110000000011100000000111000000011100
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000100000001000000010000000100000001000 SPIKE_BLACK=0001110000000011100000000111000000011100
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000100000001000000010000000100000001000 SPIKE_BLACK=0001110000000011100000000111000000011100
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000100000001000000010000000100000001000 SPIKE_BLACK=0001110000000011100000000111000000011100
```

### Example 2 (Burst-of-3, shifted timing) (BEST)

| Signal | Pattern (40-bit) | Spike count |
|--------|------------------|-------------|
| WHITE | `0000100000001000000010000000100000000000` | 4 |
| BLACK | `0001110000000111000000011100000001110000` | 12 |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 2, 4 | 0, 4 | **FAIL** (N2 wins both) |
| **Pair** | 5, 0 | 4, 0 | **FAIL** (N1 wins both) |
| **Triplet** | 4, 0 | 0, 4 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000100000001000000010000000100000000000 SPIKE_BLACK=0001110000000111000000011100000001110000
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000100000001000000010000000100000000000 SPIKE_BLACK=0001110000000111000000011100000001110000
# Triplet
make ablation SPIKE_WHITE=0000100000001000000010000000100000000000 SPIKE_BLACK=0001110000000111000000011100000001110000
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000100000001000000010000000100000000000 SPIKE_BLACK=0001110000000111000000011100000001110000
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000100000001000000010000000100000000000 SPIKE_BLACK=0001110000000111000000011100000001110000
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000100000001000000010000000100000000000 SPIKE_BLACK=0001110000000111000000011100000001110000
```

### Example 3 (Burst-of-3, alternate WHITE spacing)

| Signal | Pattern (40-bit) | Spike count |
|--------|------------------|-------------|
| WHITE | `0000100000010000001000000100000010000000` | 5 |
| BLACK | `0001110000000011100000000111000000011100` | 12 |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 4, 4 | 2, 2 | **FAIL** (tied both) |
| **Pair** | 6, 0 | 5, 0 | **FAIL** (N1 wins both) |
| **Triplet** | 4, 1 | 1, 3 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000100000010000001000000100000010000000 SPIKE_BLACK=0001110000000011100000000111000000011100
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000100000010000001000000100000010000000 SPIKE_BLACK=0001110000000011100000000111000000011100
# Triplet
make ablation SPIKE_WHITE=0000100000010000001000000100000010000000 SPIKE_BLACK=0001110000000011100000000111000000011100
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000100000010000001000000100000010000000 SPIKE_BLACK=0001110000000011100000000111000000011100
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000100000010000001000000100000010000000 SPIKE_BLACK=0001110000000011100000000111000000011100
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000100000010000001000000100000010000000 SPIKE_BLACK=0001110000000011100000000111000000011100
```

## Successful Examples: Burst-of-2 (Doublet) Patterns

A key finding: **doublet bursts (`11`) also exploit triplet asymmetry** when properly spaced. This challenges the assumption that burst-of-3 is strictly required. The doublet creates enough slow trace accumulation for the triplet terms to amplify weight updates asymmetrically.

### Example 4 (Doublet, regular spacing)

| Signal | Pattern (40-bit) | Spike count |
|--------|------------------|-------------|
| WHITE | `0000010000000001000000000100000000010000` | 4 |
| BLACK | `0110001100001100011000011000110000110001` | 16 |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 5, 5 | 4, 4 | **FAIL** (tied both) |
| **Pair** | 4, 0 | 3, 3 | **FAIL** (N1/tie) |
| **Triplet** | 4, 3 | 0, 3 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=0110001100001100011000011000110000110001
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=0110001100001100011000011000110000110001
# Triplet
make ablation SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=0110001100001100011000011000110000110001
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=0110001100001100011000011000110000110001
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=0110001100001100011000011000110000110001
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=0110001100001100011000011000110000110001
```

**Weight evolution (Triplet):**
- After Train '0': W1 develops moderate values (2-15), W2 stays at initial. N1=3, N2=1.
- After Train '1': W1 develops asymmetric pattern (high on corners, low on center), W2 develops complementary pattern. N1=2, N2=2.
- Test '0': N1=4 > N2=3. Test '1': N2=3 > N1=0.

### Example 5 (Doublet, shifted BLACK phase)

| Signal | Pattern (40-bit) | Spike count |
|--------|------------------|-------------|
| WHITE | `0000010000000001000000000100000000010000` | 4 |
| BLACK | `1100001100001100011000110000110000110001` | 16 |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 5, 5 | 2, 2 | **FAIL** (tied both) |
| **Pair** | 5, 0 | 4, 2 | **FAIL** (N1 wins both) |
| **Triplet** | 4, 3 | 1, 2 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=1100001100001100011000110000110000110001
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=1100001100001100011000110000110000110001
# Triplet
make ablation SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=1100001100001100011000110000110000110001
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=1100001100001100011000110000110000110001
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=1100001100001100011000110000110000110001
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=1100001100001100011000110000110000110001
```

### Example 6 (Doublet, irregular spacing)

| Signal | Pattern (40-bit) | Spike count |
|--------|------------------|-------------|
| WHITE | `0000010000000001000000000100000000010000` | 4 |
| BLACK | `0110001100000110001100001100011000001100` | 14 |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 4, 4 | 4, 4 | **FAIL** (tied both) |
| **Pair** | 4, 1 | 4, 2 | **FAIL** (N1 wins both) |
| **Triplet** | 3, 0 | 0, 4 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=0110001100000110001100001100011000001100
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=0110001100000110001100001100011000001100
# Triplet
make ablation SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=0110001100000110001100001100011000001100
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=0110001100000110001100001100011000001100
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=0110001100000110001100001100011000001100
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=0110001100000110001100001100011000001100
```

**Weight evolution (Triplet):**
- After Train '0': W1 depressed at BLACK center pixels, W2 unchanged (N2 never fires). N1=4, N2=0.
- After Train '1': W1 develops strong discrimination pattern. W2 gains moderate values via LTP from N2 firing. N1=1, N2=3.
- Test '0': N1=3 > N2=0. Test '1': N2=4 > N1=0. **Strongest separation found.**

### Example 7 (Doublet, shifted WHITE phase)

| Signal | Pattern (40-bit) | Spike count |
|--------|------------------|-------------|
| WHITE | `0000001000000000100000000010000000001000` | 4 |
| BLACK | `0110001100001100011000011000110000110001` | 16 |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 4, 4 | 2, 2 | **FAIL** (tied both) |
| **Pair** | 4, 3 | 4, 4 | **FAIL** (N1/tie) |
| **Triplet** | 3, 0 | 1, 2 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000001000000000100000000010000000001000 SPIKE_BLACK=0110001100001100011000011000110000110001
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000001000000000100000000010000000001000 SPIKE_BLACK=0110001100001100011000011000110000110001
# Triplet
make ablation SPIKE_WHITE=0000001000000000100000000010000000001000 SPIKE_BLACK=0110001100001100011000011000110000110001
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000001000000000100000000010000000001000 SPIKE_BLACK=0110001100001100011000011000110000110001
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000001000000000100000000010000000001000 SPIKE_BLACK=0110001100001100011000011000110000110001
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000001000000000100000000010000000001000 SPIKE_BLACK=0110001100001100011000011000110000110001
```

### Example 8 (Doublet, alternate spacing)

| Signal | Pattern (40-bit) | Spike count |
|--------|------------------|-------------|
| WHITE | `0000010000000001000000000100000000010000` | 4 |
| BLACK | `1100011000011000011000110001100001100011` | 16 |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 5, 5 | 2, 2 | **FAIL** (tied both) |
| **Pair** | 5, 2 | 4, 4 | **FAIL** (N1/tie) |
| **Triplet** | 5, 0 | 1, 2 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=1100011000011000011000110001100001100011
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=1100011000011000011000110001100001100011
# Triplet
make ablation SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=1100011000011000011000110001100001100011
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=1100011000011000011000110001100001100011
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=1100011000011000011000110001100001100011
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000010000000001000000000100000000010000 SPIKE_BLACK=1100011000011000011000110001100001100011
```

### Example 9 (Doublet, sparse BLACK)

| Signal | Pattern (40-bit) | Spike count |
|--------|------------------|-------------|
| WHITE | `0000001000000000100000000010000000001000` | 4 |
| BLACK | `1100001100001100011000110000110000110001` | 16 |

| Config | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|-------------------|-------------------|--------|
| **Original** | 4, 4 | 2, 2 | **FAIL** (tied both) |
| **Pair** | 4, 3 | 4, 4 | **FAIL** (N1/tie) |
| **Triplet** | 3, 0 | 1, 2 | **PASS** (N1 for 0, N2 for 1) |

```bash
# Original
make ablation W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000001000000000100000000010000000001000 SPIKE_BLACK=1100001100001100011000110000110000110001
# Pair
make ablation TRIPLET_EN=0 SPIKE_WHITE=0000001000000000100000000010000000001000 SPIKE_BLACK=1100001100001100011000110000110000110001
# Triplet
make ablation SPIKE_WHITE=0000001000000000100000000010000000001000 SPIKE_BLACK=1100001100001100011000110000110000110001
# Visualize (Original)
make plot-dynamic W_BITS=2 TRACE_BITS=2 TRIPLET_EN=0 LEAK_EN=0 SPIKE_WHITE=0000001000000000100000000010000000001000 SPIKE_BLACK=1100001100001100011000110000110000110001
# Visualize (Pair)
make plot-dynamic TRIPLET_EN=0 SPIKE_WHITE=0000001000000000100000000010000000001000 SPIKE_BLACK=1100001100001100011000110000110000110001
# Visualize (Triplet)
make plot-dynamic SPIKE_WHITE=0000001000000000100000000010000000001000 SPIKE_BLACK=1100001100001100011000110000110000110001
```

## Failed Patterns (Instructive)

### Alternating single spikes (Pattern 15)

| Signal | Pattern | Spike count |
|--------|---------|-------------|
| WHITE | `0000100000001000000010000000100000001000` | 5 |
| BLACK | `0001010001010001010001010001010001010000` | 13 |

All three configs failed. The alternating pattern lacks burst structure -- every spike is isolated, so no triplet interactions form. Both pair and triplet STDP see only individual spike pairs.

### Dense bursts-of-4 (Pattern 13)

| Signal | Pattern | Spike count |
|--------|---------|-------------|
| WHITE | `0100010001000100010001000100010001000100` | 10 |
| BLACK | `1111000000000011110000000000111100000000` | 12 |

All three configs failed. The burst-of-4 pattern overloads the network: BLACK pixels fire so intensely during bursts that the membrane potential overshoots on every burst, creating identical responses to both digit images.

### Near-miss: Pair almost succeeds (Pattern 19)

| Signal | Pattern | Spike count |
|--------|---------|-------------|
| WHITE | `0000100000000100000000010000000010000000` | 4 |
| BLACK | `0110001100001100011000011000110000110001` | 16 |

Original: FAIL (N2 wins 4-2, tie 2-2). Pair: FAIL (N1=4>N2=3, tie 4-4). Triplet: FAIL (N2=2>N1=1, tie 2-2).

This shows sensitivity to WHITE spike timing -- shifting the WHITE phase by 1-2 positions relative to the BLACK doublets can swing from pass to fail. The triplet mechanism requires specific timing alignment between pre-synaptic bursts and post-synaptic activity.

## Analysis

### Why Pair STDP Fails with Doublet Bursts

With SYMMETRIC=1, the pair STDP has A2_PLUS = A2_MINUS = 1 (equal LTP and LTD magnitudes). When a doublet burst `11` occurs:
- The first pre spike sets r1 = 8. On the next cycle, if no post spike fires, r1 decays to 4.
- The second pre spike bumps r1 back up.
- Any post spike arriving near the doublet sees r1-gated LTP, while pre spikes see o1-gated LTD.
- Because LTP and LTD magnitudes are equal, these contributions tend to cancel, leaving weights relatively unchanged.

After training, pair STDP produces weight maps that are too similar between the two neurons. N1 typically dominates (due to favorable initial weights) and wins for both digit classes.

### Why Triplet STDP Succeeds with Doublet Bursts

The doublet burst creates enough slow trace accumulation for triplet modulation:

1. **Slow pre-trace (r2) accumulation**: The first spike in a doublet sets r2 = 8. The second spike (1 cycle later) sees r2 still at 6 (decayed by -2) and bumps it to 14. This elevated r2 modulates LTD via A3_MINUS = 4, creating **4x amplified depression** for BLACK pixels.

2. **Slow post-trace (o2) accumulation**: When a post neuron fires during or just after a doublet, o2 accumulates. If another post spike occurs before o2 decays, the LTP for currently active pre-synapses is amplified via A3_PLUS = 1.

3. **Asymmetric amplification**: A3_MINUS (4) >> A3_PLUS (1). This means doublet-driven depression is amplified far more than potentiation. BLACK pixels (with doublets) experience stronger net depression, while WHITE pixels (with isolated spikes, low r2) experience moderate balanced updates. This creates weight differentiation that aligns with the digit structure.

4. **Competitive learning emerges**: During Train '0', N1 wins first (better initial weights for digit-0 shape), and its firing triggers lateral inhibition of N2. The triplet LTD selectively depresses BLACK-pixel weights for N1 where they don't match the digit-0 pattern. During Train '1', N2 gets a chance to fire, and the asymmetric triplet updates create complementary weight maps.

### Why Original Also Fails

The original configuration (W_BITS=2, TRACE_BITS=2, LEAK_EN=0, TRIPLET_EN=0) fails for an additional reason: 2-bit weights (range 0-3) saturate quickly. After one training epoch, most weights converge to the maximum value (3), erasing any learned discrimination. The 4-bit weights used by pair and triplet STDP preserve more granularity, but only triplet STDP has the mechanism to leverage burst structure for asymmetric learning.

### The Burst-of-2 vs Burst-of-3 Distinction

Initial experiments suggested burst-of-3 was necessary, but systematic exploration reveals that **doublet bursts work as well**, given appropriate timing. The critical factor is not the burst length per se but whether:

1. The slow traces (r2, o2) accumulate above the threshold where the triplet multiplicative terms (`r1 * o2`, `o1 * r2`) become significant after the right-shift by TRACE_BITS.
2. The timing of the doublets relative to WHITE spikes creates sufficient rate-code difference to drive different post-synaptic firing for different digit images.

Doublets work because with TRACE_INC=8 and TRACE_BITS=4 (max=15), two spikes 1 cycle apart yield r2 ~= 14 on the second spike, which after the `>> TRACE_BITS` normalization still produces a non-zero triplet modulation.

### Connection to Pfister & Gerstner (2006)

The paper demonstrates that triplet STDP captures the experimentally-observed asymmetry between pre-post-pre and post-pre-post spike triplets (Wang et al. 2005). In biological neurons, these two triplet configurations produce markedly different plasticity outcomes -- an asymmetry that pair-based models cannot explain.

Our hardware implementation successfully reproduces this effect with both burst-of-3 and burst-of-2 input patterns. The doublet-burst finding is particularly relevant because biological cortical neurons commonly fire doublets during sensory processing. The A3_MINUS >> A3_PLUS asymmetry (4:1 ratio) means the system preferentially amplifies depression at high-frequency synapses, implementing a form of homeostatic regulation that pair STDP lacks.

## Summary of All Tested Patterns

| # | WHITE | BLACK | Burst type | Original | Pair | Triplet |
|---|-------|-------|------------|----------|------|---------|
| 1 | 4 spikes, ~10-apart | 16 spikes, doublets every 5 | doublet | FAIL | FAIL | FAIL |
| 2 | 3 spikes, ~13-apart | 12 spikes, triplets every 10 | triplet | FAIL | FAIL | FAIL |
| 3 | 3 spikes, ~13-apart | 16 spikes, doublets every 5 | doublet | FAIL | PASS | PASS |
| 4 | 4 spikes, ~10-apart | 16 spikes, doublet+single | mixed | FAIL | FAIL | FAIL |
| 5 | 4 spikes, ~10-apart | 15 spikes, triplets every 8 | triplet | FAIL | FAIL | FAIL |
| 6 | 6 spikes, pairs | 18 spikes, triplet pairs | mixed | FAIL | PASS | FAIL |
| 7 | 5 spikes, every 8 | 20 spikes, triplet+single | mixed | FAIL | FAIL | FAIL |
| 8 | 5 spikes, every 8 | 12 spikes, triplets every 10 | triplet | PASS | PASS | PASS |
| 9 | 4 spikes, ~10-apart | 15 spikes, doublet+single | doublet | PASS | PASS | PASS |
| 10 | 6 spikes, every 7 | 16 spikes, 4-doublets | doublet | FAIL | FAIL | FAIL |
| 11 | 4 spikes, irregular | 18 spikes, doublets every 5 | doublet | FAIL | FAIL | FAIL |
| 13 | 10 spikes, every 4 | 12 spikes, burst-of-4 | quad | FAIL | FAIL | FAIL |
| 14 | 6 spikes, irregular | 15 spikes, triplets every 8 | triplet | FAIL | FAIL | FAIL |
| 15 | 5 spikes, every 8 | 13 spikes, alternating | single | FAIL | FAIL | FAIL |
| **17** | **4 spikes, every 10** | **16 spikes, doublets every 5** | **doublet** | **FAIL** | **FAIL** | **PASS** |
| **23** | **4 spikes, every 10 (shifted)** | **16 spikes, doublets every 5** | **doublet** | **FAIL** | **FAIL** | **PASS** |
| **28** | **4 spikes, every 10** | **16 spikes, doublets (shifted)** | **doublet** | **FAIL** | **FAIL** | **PASS** |
| **31** | **4 spikes, every 10** | **16 spikes, doublets varied spacing** | **doublet** | **FAIL** | **FAIL** | **PASS** |
| **32** | **4 spikes, every 10 (shifted)** | **16 spikes, doublets (shifted)** | **doublet** | **FAIL** | **FAIL** | **PASS** |
| **35** | **4 spikes, every 10** | **14 spikes, irregular doublets** | **doublet** | **FAIL** | **FAIL** | **PASS** |
| Ex1 | 5 spikes, every 8 | 12 spikes, triplets every 10 | triplet | FAIL | FAIL | PASS |
| Ex2 | 4 spikes, irregular | 12 spikes, triplets shifted | triplet | FAIL | FAIL | PASS |
| Ex3 | 5 spikes, irregular | 12 spikes, triplets every 10 | triplet | FAIL | FAIL | PASS |

**Bold rows**: New doublet-burst patterns where original AND pair fail but triplet passes (9 total triplet-only success cases).
