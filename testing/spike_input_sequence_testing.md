# Spike Input Sequence Testing

Systematic exploration of BLACK/WHITE spike patterns to find configurations that differentiate triplet STDP from pair-based STDP. All tests use `W_BITS=4, TRACE_BITS=4, MODE=0 (all-to-all), LEAK_EN=1 (LIF), NUM_EPOCHS=1`.

The `SYMMETRIC` flag controls whether LTP and LTD magnitudes are equal (`SYMMETRIC=1`: A2_MINUS = A2_PLUS = 1) or asymmetric (`SYMMETRIC=0`: A2_PLUS=1, A2_MINUS=3). Part 1 tests symmetric pair vs asymmetric triplet. Part 2 tests asymmetric pair vs asymmetric triplet, isolating the triplet mechanism from the asymmetry advantage.

Classification is correct when Test '0' has N1 > N2 and Test '1' has N2 > N1.

---

## Part 1: Symmetric Pair STDP (`SYMMETRIC=1`)

Pair uses `SYMMETRIC=1` (A2_PLUS=1, A2_MINUS=1), giving equal LTP/LTD. Triplet uses `SYMMETRIC=0` (A2_MINUS=3) with triplet terms enabled. This tests the combined effect of asymmetry + triplet modulation vs pure symmetric pair.

### Patterns That Differentiate Triplet from Pair

#### current-bursty (current default)

```
WHITE = 40'b1000000000100000000010000000001000000000  (1 spike every 10 cycles, 4 total)
BLACK = 40'b1100110000001100110000001100110000001100  (2-spike bursts every 5 cycles, 16 total)
```

| Phase | Triplet | Pair |
|---|---|---|
| Test '0' | N1=3, N2=0 | N1=5, N2=0 |
| Test '1' | N1=0, N2=3 | N1=4, N2=1 |

Triplet: PASS, Pair: FAIL. The 2-spike bursts create pre-post-pre triplet interactions. Pair's symmetric updates can't create enough separation — N1 stays dominant for both images.

#### burst3-gap7

```
WHITE = 40'b1000000000100000000010000000001000000000  (1 spike every 10 cycles, 4 total)
BLACK = 40'b1110000000011100000001110000000111000000  (3-spike bursts every 10 cycles, 12 total)
```

| Phase | Triplet | Pair |
|---|---|---|
| Test '0' | N1=4, N2=0 | N1=4, N2=0 |
| Test '1' | N1=0, N2=4 | N1=4, N2=0 |

Triplet: PASS, Pair: FAIL. Starkest differentiation — pair produces identical 4-0 on both test images (completely fails to learn '1'). The 3-spike bursts create richer triplet sequences. After Phase 2 training, triplet depresses W1 for '1' pixels to 0-2 while pair leaves them at 9-13.

#### short-burst-gap

```
WHITE = 40'b1000000000000001000000000000010000000000  (3 spikes, very sparse)
BLACK = 40'b1100000011000000110000001100000011000000  (2-spike bursts every 8 cycles, 10 total)
```

| Phase | Triplet | Pair |
|---|---|---|
| Test '0' | N1=2, N2=0 | N1=3, N2=0 |
| Test '1' | N1=0, N2=3 | N1=3, N2=0 |

Triplet: PASS, Pair: FAIL. Very sparse white means less interference. Pair fails completely — N1=3 on both images.

#### burst2-gap4-w10

```
WHITE = 40'b1000000000100000000010000000001000000000  (1 spike every 10 cycles, 4 total)
BLACK = 40'b1100011000011000110000110001100001100011  (2-spike bursts every 4 cycles, 20 total)
```

| Phase | Triplet | Pair |
|---|---|---|
| Test '0' | N1=4, N2=0 | N1=6, N2=0 |
| Test '1' | N1=0, N2=4 | N1=4, N2=1 |

Triplet: PASS, Pair: FAIL. Highest firing rates of the differentiating patterns. Denser bursts give more STDP updates per epoch.

#### burst2-gap5-w10

```
WHITE = 40'b1000000000100000000010000000001000000000  (1 spike every 10 cycles, 4 total)
BLACK = 40'b1100000110000011000001100000110000011000  (2-spike bursts every 5 cycles, 14 total)
```

| Phase | Triplet | Pair |
|---|---|---|
| Test '0' | N1=3, N2=1 | N1=4, N2=0 |
| Test '1' | N1=1, N2=3 | N1=4, N2=0 |

Triplet: PASS, Pair: FAIL. Wider gap between bursts. Still differentiates but with smaller margins.

#### phase-shift

```
WHITE = 40'b0000010000000001000000000100000000010000  (1 spike every 10, phase-shifted)
BLACK = 40'b1100000011000000110000001100000011000000  (2-spike bursts every 8 cycles)
```

| Phase | Triplet | Pair |
|---|---|---|
| Test '0' | N1=4, N2=0 | N1=4, N2=0 |
| Test '1' | N1=1, N2=2 | N1=4, N2=0 |

Triplet: PASS (narrow margin), Pair: FAIL. Phase-shifting white relative to black changes the relative timing of pre/post spikes.

### Patterns Where Both Succeed

#### quad-burst

```
WHITE = 40'b0000010000000000010000000000010000000000  (3 spikes, very sparse)
BLACK = 40'b1111000000001111000000001111000000001111  (4-spike bursts every 10 cycles, 16 total)
```

Both PASS (Triplet: 4-0 / 0-4, Pair: 4-0 / 0-4). The 4-spike bursts are so dominant that even symmetric pair STDP gets enough potentiation/depression. The extreme spike count ratio (16:3) makes classification easy for any learning rule.

#### dense-burst

```
WHITE = 40'b0000000001000000000010000000000000000001  (3 spikes, sparse)
BLACK = 40'b1110011100011100111000111001110001110011  (dense 3-spike bursts, 26 total)
```

Triplet: FAIL (N2 doesn't fire for '1'), Pair: PASS (7-0 / 0-7). Very high BLACK density saturates weights quickly. Pair benefits from the sheer volume of spikes. Triplet's stronger depression over-suppresses.

#### hi-freq-vs-sparse

```
WHITE = 40'b0000000000000010000000000000100000000000  (2 spikes, very sparse)
BLACK = 40'b1010101010101010101010101010101010101010  (every other cycle, 20 total)
```

Triplet: FAIL (no firing at all), Pair: PASS (7-1 / 2-5). Constant high-frequency input overwhelms triplet — slow traces stay saturated, causing excessive depression that zeroes out all weights.

### Patterns Where Both Fail

#### triplet-triplets

```
WHITE = 40'b0000010000000001000000000100000000010000
BLACK = 40'b1010100000101010000010101000001010100000
```

Both FAIL (tie on Test '1'). The alternating spike pattern doesn't create enough burst structure for triplet, and density is too moderate for pair.

#### overlap

```
WHITE = 40'b1000001000001000001000001000001000001000  (every 6 cycles, 7 total)
BLACK = 40'b1100001100001100001100001100001100001100  (2-spike bursts every 6 cycles, 14 total)
```

Both FAIL (N1=7, N2=0 on both tests). WHITE is too frequent — not enough contrast between foreground and background pixels.

#### burst2-gap3-w5

```
WHITE = 40'b0100010001000100010001000100010001000100  (every 4 cycles, 10 total)
BLACK = 40'b1100110000001100110000001100110000001100  (2-spike bursts, 16 total)
```

Both FAIL. WHITE too dense (10 spikes vs BLACK's 16). Minimal contrast.

### Part 1 Takeaways

1. **Burst structure is essential for triplet advantage**: 2-3 spike bursts with gaps of 5-10 cycles create the pre-post-pre temporal correlations that triplet STDP's slow trace modulation exploits.
2. **WHITE must be sparse relative to BLACK**: A ratio of at least 3:1 (BLACK:WHITE spikes) is needed for either rule to differentiate foreground from background pixels.
3. **Too-dense BLACK hurts triplet**: Very high spike rates keep slow traces saturated, causing triplet's depression to dominate and zero out all weights.
4. **Symmetric pair needs extreme contrast to succeed**: Pair only classifies correctly when the spike count ratio is very large (e.g., quad-burst at ~5:1) or when high-frequency firing drives fast weight saturation.
5. **Recommended pattern**: `burst3-gap7` produces the most dramatic differentiation — pair gives identical outputs for both test images while triplet achieves perfect separation.

---

## Part 2: Asymmetric Pair STDP (`SYMMETRIC=0`)

Both pair and triplet use `SYMMETRIC=0` (A2_PLUS=1, A2_MINUS=3), so the only difference is whether triplet modulation terms (A3_PLUS, A3_MINUS with slow traces) are active. This is a stricter test — it isolates the triplet mechanism itself from the advantage of having asymmetric A parameters.

### Patterns That Differentiate Triplet from Asymmetric Pair

With asymmetric depression, pair now succeeds on many patterns it previously failed (e.g., current-bursty). Only patterns requiring the triplet slow-trace modulation still differentiate.

#### burst3-gap7 (strongest differentiator)

```
WHITE = 40'b1000000000100000000010000000001000000000  (1 spike every 10 cycles, 4 total)
BLACK = 40'b1110000000011100000001110000000111000000  (3-spike bursts every 10 cycles, 12 total)
```

| Phase | Triplet | Pair (asymmetric) |
|---|---|---|
| Train '0' | N1=4, N2=0 | N1=4, N2=0 |
| Train '1' | N1=1, N2=3 | N1=4, N2=0 |
| Test '0' | N1=4, N2=0 | N1=4, N2=0 |
| Test '1' | N1=0, N2=4 | N1=4, N2=0 |

Triplet: PASS, Pair: FAIL. Pair's W2 weights never change from initial values — N2 never fires during Phase 2, so there's no post-synaptic activity to trigger LTP for W2. Triplet's slow-trace modulated depression (A3_MINUS * r2) pushes W1 down enough during Phase 2 that N2 can start firing and bootstrap its own learning.

After Phase 2, W1 weights for '1' pixel positions:
- Triplet: depressed to 0-5 (e.g., positions 1,2,7,12,21,22,23 → 0)
- Pair: stays at 4-14 (barely changed from Phase 1)

#### burst3-gap6

```
WHITE = 40'b1000000000100000000010000000001000000000  (1 spike every 10 cycles, 4 total)
BLACK = 40'b1110000000111000000011100000001110000000  (3-spike bursts every 6 cycles, 12 total)
```

| Phase | Triplet | Pair (asymmetric) |
|---|---|---|
| Test '0' | N1=4, N2=0 | N1=4, N2=0 |
| Test '1' | N1=0, N2=4 | N1=4, N2=0 |

Triplet: PASS, Pair: FAIL. Same mechanism as burst3-gap7 — tighter gap between bursts but still differentiates. Pair's W2 remains unchanged from initial values.

#### burst3-gap5

```
WHITE = 40'b1000000000100000000010000000001000000000  (1 spike every 10 cycles, 4 total)
BLACK = 40'b1110000011100001110000111000011100001110  (3-spike bursts every 5 cycles, 18 total)
```

| Phase | Triplet | Pair (asymmetric) |
|---|---|---|
| Test '0' | N1=5, N2=3 | N1=6, N2=1 |
| Test '1' | N1=0, N2=6 | N1=5, N2=4 |

Triplet: PASS, Pair: FAIL. Higher density variant. Both neurons fire more, but pair can't achieve N2 > N1 on Test '1'.

#### short-burst-gap

```
WHITE = 40'b1000000000000001000000000000010000000000  (3 spikes, very sparse)
BLACK = 40'b1100000011000000110000001100000011000000  (2-spike bursts every 8 cycles, 10 total)
```

| Phase | Triplet | Pair (asymmetric) |
|---|---|---|
| Test '0' | N1=2, N2=0 | N1=3, N2=0 |
| Test '1' | N1=0, N2=3 | N1=3, N2=1 |

Triplet: PASS, Pair: FAIL. Even with asymmetric depression, pair can't suppress N1 enough for N2 to win on Test '1'.

#### 50step-burst3

```
WHITE = 50'b10000000001000000000100000000010000000001000000000  (5 spikes, every 10 cycles)
BLACK = 50'b11100000000011100000000111000000001110000000011100  (3-spike bursts every ~10 cycles, 15 total)
```

| Phase | Triplet | Pair (asymmetric) |
|---|---|---|
| Test '0' | N1=5, N2=0 | N1=5, N2=0 |
| Test '1' | N1=0, N2=5 | N1=5, N2=0 |

Triplet: PASS, Pair: FAIL. Longer 50-step version. Same burst3 structure, same differentiation — confirms the result scales to longer sequences.

### Patterns Where Both Succeed (Asymmetric)

Many patterns that only triplet could solve with symmetric pair now also work with asymmetric pair. The stronger depression (A2_MINUS=3 vs 1) gives pair enough suppression to learn.

#### current-bursty

Previously a differentiator under symmetric pair, now both pass (3-0 / 0-3) with asymmetric pair. The 3x depression asymmetry alone provides sufficient weight suppression.

#### burst2-gap4-w10, burst2-gap5-w10, phase-shift

All now pass with asymmetric pair. 2-spike burst patterns create enough activity for asymmetric depression to work.

#### quad-burst, both-sparse-bursty, low-rate, 30step-burst2

Still pass for both — easy tasks that don't need triplet.

### Patterns Where Pair Succeeds but Triplet Fails (Asymmetric)

#### burst4-gap8

```
WHITE = 40'b1000000000100000000010000000001000000000
BLACK = 40'b1111000000001111000000001111000000001111
```

Triplet: FAIL (0-1 / 1-1), Pair: PASS (4-0 / 0-4). The 4-spike bursts with long gaps cause triplet's slow traces to build up excessively, over-depressing weights. Pair handles it fine with just the asymmetric A2 parameters.

#### burst5-gap5

```
WHITE = 40'b1000000000100000000010000000001000000000
BLACK = 40'b1111100000111110000011111000001111100000
```

Triplet: FAIL (2-0 / 1-0), Pair: PASS (4-0 / 0-4). 5-spike bursts are too long — triplet's slow trace modulation causes catastrophic depression. The triplet term amplifies what is already strong asymmetric depression, overshooting.

### Patterns Where Both Fail (Asymmetric)

dense-burst, triplet-triplets, hi-freq-vs-sparse, triple-burst, overlap, burst2-gap3-w8, burst2-gap3-w5, asymmetric, moderate-burst2, moderate-burst3, sparse-w-med-b, short-burst-gap-v2, short-burst-gap-v3, burst2-gap5-w20, irregular1, irregular2, burst3-gap8, 60step-burst, 30step-burst3.

Most fail because the asymmetric depression is now too strong for patterns that lack sufficient contrast — weights get over-depressed and neither neuron can fire.

### Part 2 Takeaways

1. **Asymmetric A2 parameters close most of the gap**: Many patterns that only triplet could solve with symmetric pair now also work with asymmetric pair. The A2_MINUS=3 asymmetry alone accounts for much of the advantage previously attributed to triplet.

2. **3-spike bursts are the sweet spot for genuine triplet advantage**: The burst3 family (gap5, gap6, gap7) consistently differentiates even with asymmetric pair. 2-spike bursts are generally handled by asymmetric pair alone. 4-5 spike bursts cause triplet to over-depress.

3. **Triplet's unique mechanism — bootstrapping N2**: The key failure mode for asymmetric pair is when N1 dominates so strongly that N2 never fires during Phase 2. Without post-synaptic spikes, pair STDP (even asymmetric) cannot trigger LTP for W2. Triplet's slow-trace depression (A3_MINUS * r2) provides additional W1 suppression beyond what A2_MINUS alone achieves, eventually letting N2 fire and start learning.

4. **Triplet can over-depress with too-long bursts**: With 4-5 spike bursts, the triplet modulation amplifies the already-strong asymmetric depression beyond what's useful. The slow pre-trace (r2) stays high across the entire burst, causing each spike in the burst to contribute more depression than pair would.

5. **Recommended pattern for demonstrating genuine triplet advantage**: `burst3-gap7` remains the strongest differentiator — pair produces identical 4-0 outputs for both test images (W2 never learns) while triplet achieves perfect 4-0 / 0-4 separation. This isolates the triplet mechanism's ability to bootstrap learning for the losing neuron.
