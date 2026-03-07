# Triplet SNN Project Summary

## Project Goal

Extend a pair-based STDP spiking neural network (SNN) implemented in Verilog into a **triplet STDP** SNN based on the Pfister & Gerstner (2006) triplet learning rule. The network classifies 5x5 binary images of handwritten digits '0' and '1' using two LIF output neurons with lateral inhibition, trained via spike-timing-dependent plasticity.

---

## Starting Point: Pair-Based STDP SNN

### Architecture (`rtl/snn_network.v`)
- **25 input neurons** (one per pixel in a 5x5 image), fully connected to **2 output LIF neurons**.
- **2-bit weights** (range 0--3) per synapse, 25 synapses per output neuron.
- **Integrate-and-Fire neurons** (no leak): membrane potential accumulates weighted input each cycle; fires when V >= V_THRESHOLD (65); resets to V_REST (6) one cycle after firing.
- **Lateral inhibition**: when one output neuron fires, the other is forced to reset the next cycle. This encourages specialization -- one neuron learns '0', the other learns '1'.

### STDP Rule
- Uses a **2-step shift register** for spike history (both input and output sides).
- **Potentiation** (post fires, pre fired recently): +2 if pre fired 1 cycle ago, +1 if pre fired 2 cycles ago.
- **Depression** (pre fires, post fired recently): -2 if post fired 1 cycle ago, -1 if post fired 2 cycles ago.
- This is classic **pair-based STDP** -- it only considers pairs of pre/post spikes.

### Spike Encoding
- BLACK pixels (digit foreground): high spike rate.
- WHITE pixels (digit background): low spike rate.
- Original patterns were 20 bits long (20 timesteps per presentation).

### Initial Weights
- Neuron 1: `{1,0,0,1,2, 0,3,2,3,0, 2,2,1,3,3, 1,3,0,0,2, 3,1,1,0,1}`
- Neuron 2: `{0,2,3,0,1, 2,0,2,0,0, 1,2,3,1,2, 0,1,1,0,1, 2,3,1,3,0}`
- These are random-looking seeds; training shapes them toward digit templates.

### Training/Testing Protocol
- **Phase 1**: Train with '0' image (TRAIN_0 = `00000_01110_01010_01110_00000`).
- **Phase 2**: Train with '1' image (TRAIN_1 = `01100_00100_00100_00100_01110`).
- **Phase 3**: Test with '0' image (TEST_0 = `00000_01010_01010_01110_00000`).
- **Phase 4**: Test with '1' image (TEST_1 = `01100_00100_00100_00100_00100`).
- Classification succeeds if N1 fires more for '0' and N2 fires more for '1' (or vice versa, as long as they differentiate).

### Testbenches
- `tb/snn_network_tb.v`: Standard testbench with BEFORE/AFTER weight printing and firing counts.
- `tb/snn_network_tb_verbose.v`: Debug testbench that prints per-step membrane voltages, spike events, STDP trigger conditions, and individual weight changes.

### Observations with Pair-Based STDP
- The pair-based model works with its original 20-bit evenly-spaced spike patterns.
- With only 2-bit weights, there is very limited dynamic range for learning.
- The STDP rule is hardcoded with fixed +2/+1/-2/-1 deltas based on spike timing offsets of 1 or 2 cycles -- there is no concept of decaying traces.

---

## Initial Triplet STDP Implementation (`rtl/triplet_snn.v`)

The first step was creating `triplet_snn.v` as a copy of `snn_network.v` and converting it from pair-based to triplet STDP. The initial implementation kept the same 2-bit weights and 20-timestep spike trains while making the following structural changes:

### Pre-synaptic Trace Replacement

The original pair-based model uses **25-bit shift registers** (`in_spike_prev1`, `in_spike_prev2`) that store a binary history of which input neurons fired 1 or 2 cycles ago. Each bit is either 0 or 1 -- no amplitude information.

For triplet STDP, these were replaced with **4-bit memory arrays** (`r1[0:24]`, `r2[0:24]`) -- one trace per input synapse. This is the key structural difference: instead of a binary "did it fire?" the trace stores a decaying amplitude that encodes both *when* and *how frequently* the input neuron has been firing. The pre-synaptic traces must be memory arrays (not simple registers) because there are 25 independent input neurons, each needing its own trace value.

- `r1[i]` -- fast pre-synaptic trace: halves each cycle (>>1 decay), bumped on input spike.
- `r2[i]` -- slow pre-synaptic trace: decays linearly each cycle, bumped on input spike.

### Post-synaptic Traces

The original model uses single-bit registers (`out1_spike_prev1`, `out1_spike_prev2`) for output spike history. These were replaced with 4-bit registers:

- `o1_n` -- fast post-synaptic trace per output neuron (decays by >>1).
- `o2_n` -- slow post-synaptic trace per output neuron (decays linearly).

These are simple registers (not memory arrays) because there are only 2 output neurons.

### Leak Parameter (LIF Neuron)

Added `V_LEAK = 1` parameter, converting from Integrate-and-Fire to **Leaky Integrate-and-Fire**. The neuron now subtracts leak each cycle, preventing runaway membrane potential accumulation. Threshold comparison adjusted: `V + wsum >= V_THRESHOLD + V_LEAK`. Membrane potential clamped to V_REST if it would drop below `V_REST + V_LEAK`.

### Triplet STDP Learning Rule

Based on Pfister & Gerstner (2006), the triplet rule extends pair-based STDP by adding a **third spike** modulation term. This captures frequency-dependent plasticity that pair-based rules miss.

**Potentiation (on post-synaptic spike):**
```
dw+ = r1[i] * A2_PLUS + ((r1[i] * o2) >> 4) * A3_PLUS
```
- `r1[i] * A2_PLUS`: standard pair-based LTP, gated by fast pre trace.
- `((r1[i] * o2) >> 4) * A3_PLUS`: triplet modulation -- the slow post trace `o2` scales potentiation up when there was a recent prior post spike (creating a post-pre-post triplet).

**Depression (on pre-synaptic spike):**
```
dw- = o1 * A2_MINUS + ((o1 * r2[i]) >> 4) * A3_MINUS
```
- `o1 * A2_MINUS`: standard pair-based LTD, gated by fast post trace.
- `((o1 * r2[i]) >> 4) * A3_MINUS`: triplet modulation -- the slow pre trace `r2` scales depression up when there was a recent prior pre spike (creating a pre-post-pre triplet).

### Mode Support
- `MODE = 0` (all-to-all): traces accumulate with saturating addition on each spike.
- `MODE = 1` (nearest-neighbor): traces snap to max (15) on each spike, only the nearest spike pair/triplet matters.

---

## Final Triplet SNN Architecture (`rtl/triplet_snn.v`)

After the experimental progression, the final triplet SNN differs from the initial implementation in these key ways:

**Weights**: 4-bit (0--15), initial values scaled 4x from originals. Clamped with signed arithmetic.

**Weighted sum scaling**: 10-bit `wsum_full` accumulator, right-shifted by `W_SCALE = 2` to fit 8-bit membrane.

**STDP Parameters (Winning Configuration)**:
- `A2_PLUS = 1`, `A2_MINUS = 3` -- pair-based LTP/LTD magnitudes.
- `A3_PLUS = 1`, `A3_MINUS = 4` -- triplet LTP/LTD magnitudes.
- `DW_SCALE = 2` -- right-shift applied to raw STDP deltas before clamping.
- `TRACE_INC = 8` -- trace increment on spike (all-to-all mode).

**Slow trace decay**: -2 per cycle (changed from -1 to fit within the 40-step window).

**Scaling and clamping**: Raw potentiation/depression computed in 12 bits, right-shifted by `DW_SCALE`, clamped to 4 bits. Net delta computed as signed value. Final weight clamped to [0, 15].

---

## Spike Pattern Design

### Original Patterns (20-bit, pair-based SNN)
- WHITE: `01000000100000000010` -- 3 spikes in 20 steps, evenly spaced.
- BLACK: `01010100010101000101` -- 9 spikes in 20 steps, bursts of activity.

### Final Patterns (40-bit, both testbenches)
- WHITE: `1000000000100000000010000000001000000000` -- 4 spikes in 40 steps, evenly spaced every 10 cycles.
- BLACK: `1100110000001100110000001100110000001100` -- burst-gap-burst pattern. Pairs of spikes separated by a gap, then another pair, with longer silent periods between groups. Specifically designed to create pre-post-pre triplet motifs.

### Design Rationale
The key insight is that triplet STDP only shows its advantage over pair-based STDP when **triplet spike motifs** (pre-post-pre or post-pre-post) actually occur. Evenly-spaced spikes produce mostly isolated pairs. Bursty patterns with specific timing create the overlapping spike triplets that the triplet rule can exploit.

---

## Testbench Design

### Standard Testbenches (`tb/triplet_snn_tb.v`, `tb/snn_network_tb.v`)
- Support `TEST_ONLY` define: when set, runs all 4 phases (train + test); without it, runs only training phases 1--2.
- VCD waveform dumping with separate files for training vs. testing.
- `apply_image_timestep` task: maps each pixel to BLACK or WHITE spike pattern based on the image bitmap, indexed by the current timestep.
- `print_weights` task: prints all 25 weights in parseable format with BEFORE/AFTER labels.
- `run_phase` task: resets membrane state, runs 40 timesteps, counts spikes, prints weights before and after.

### Verbose Testbenches (`tb/triplet_snn_tb_verbose.v`, `tb/snn_network_tb_verbose.v`)
- Per-timestep display of membrane potential and spike output for both neurons.
- STDP debug: snapshots trace/history state before each clock edge, then after the edge detects and reports:
  - Potentiation events (which neuron, which traces were active).
  - Depression events (which neuron, which traces were active).
  - Individual weight changes with before/after values.
  - Updated 5x5 weight grids after any change.

### Triplet Verbose Testbench Additions
- Prints `r1`, `r2` trace values for active synapses.
- Prints `o1`, `o2` post-synaptic trace values.
- Shows triplet modulation factors alongside pair-based triggers.

---

## Visualization (`viz/plot_weights.py`)
- Runs `make train` and parses BEFORE/AFTER weight lines from stdout.
- Generates 5x5 weight heatmaps using a 4-level grayscale colormap (0=white, 3=black).
- Produces an 8-subplot figure: BEFORE/AFTER for each training phase, for both neurons.
- Note: currently configured for the 2-bit pair-based SNN weight range (0--3). Would need updating for the triplet SNN's 4-bit range (0--15).

---

## Build System (`Makefile`)
- `make train` / `make test`: pair-based SNN training/testing.
- `make verbose`: pair-based SNN with debug output.
- `make triplet-train` / `make triplet-test`: triplet SNN training/testing.
- `make triplet-verbose`: triplet SNN with debug output.
- `make plot`: generate weight heatmaps.
- `make clean`: remove build artifacts and VCD files.
- All use `iverilog` for compilation and `vvp` for simulation.

---

## Repository Structure (final-project branch)

```
triplet-snn/
  rtl/
    snn_network.v          # Pair-based STDP SNN (original, 2-bit weights, IF neurons)
    triplet_snn.v          # Triplet STDP SNN (4-bit weights, LIF neurons, trace-based)
  tb/
    snn_network_tb.v       # Standard testbench for pair-based SNN
    snn_network_tb_verbose.v  # Verbose debug testbench for pair-based SNN
    triplet_snn_tb.v       # Standard testbench for triplet SNN
    triplet_snn_tb_verbose.v  # Verbose debug testbench for triplet SNN
  viz/
    plot_weights.py        # Weight heatmap visualization
  data/
    .gitkeep               # Placeholder for data directory
  Makefile                 # Build targets for both models
  README.md                # Setup and command reference
  requirements.txt         # Python dependencies (numpy, matplotlib)
```

### Predecessor Code (removed in reorganization, originally on main)
- `dakota-code/`: Dakota's SNN STDP implementation and Jupyter analysis notebook.
- `logan-code/`: Logan's neuron implementation with memory-file-based spike matrices, STDP LUT, weight visualization, and GTKWave view files.
- `lif_neuronnetwork_stdp.sv`: SystemVerilog LIF network (another team member's version).
- `tb_lifneuronnetwork_stdp.sv`: Its testbench.

---

## Experimental Progression

The central goal was to find a scenario where pair-based STDP fails but triplet STDP succeeds, demonstrating the advantage of the triplet learning rule. This required several rounds of iteration across spike patterns, weight precision, trace dynamics, and parameters.

### Step 1: Baseline Comparison with Original 20-bit Patterns

We started by running both models (`snn_network.v` and `triplet_snn.v`) with the same original 20-bit evenly-spaced spike patterns and 2-bit weights. The triplet SNN at this stage was structurally different (decaying traces instead of shift registers, LIF instead of IF) but used the same weight resolution.

**Result**: No difference in spike distribution (firing counts) between the two models. The membrane potential accumulated slightly differently due to the leak parameter, but the classification outcome was identical. The evenly-spaced patterns produced mostly isolated spike pairs -- no triplet motifs formed, so the triplet terms had nothing to work with.

### Step 2: Modifying 20-bit Spike Trains

We tried augmenting the 20-bit BLACK spike pattern to be burstier, aiming to create pre-post-pre and post-pre-post triplet motifs that would give the triplet rule an advantage.

**Result**: The pair-based STDP failed on the bursty patterns, but so did the 2-bit triplet STDP. The problem was **weight precision**: with only 4 levels (0--3), the triplet STDP's graded weight updates were quantized to the same coarse steps as the pair-based rule. The triplet contribution was effectively rounded away.

### Step 3: Slow Trace Decay Adjustment

Initially the slow traces (`r2`, `o2`) decayed by -1 per cycle. We realized this was too slow -- a trace bumped to 15 would take 15 cycles to fully decay, spanning nearly the entire 20-cycle spike train. This meant the slow trace was essentially always active, providing no timing selectivity.

**Fix**: Changed slow trace decay from -1 to -2 per cycle. Now a trace bumped to 15 decays to zero in ~8 cycles, providing a meaningful timing window within the spike train.

### Step 4: Weight Expansion to 4-bit

The 2-bit weight saturation was a fundamental limitation. We expanded weights from 2-bit (0--3) to **4-bit (0--15)**, giving the triplet STDP rule 16 levels to work with instead of 4. Initial weights were scaled by 4x from the originals (e.g., original weight 3 became 12).

To prevent membrane potential overflow (4-bit weights × 25 inputs = max 375, exceeding 8 bits), we added a 10-bit `wsum_full` accumulator and a `W_SCALE = 2` right-shift to divide by 4, keeping the membrane dynamics in 8-bit range.

### Step 5: Extending to 40-bit Spike Trains

The 20-timestep window was too short for the triplet traces to build up and interact meaningfully. We extended both BLACK and WHITE spike patterns to **40 bits**:
- WHITE: `1000000000100000000010000000001000000000` -- 4 spikes in 40 steps, evenly spaced every 10 cycles.
- BLACK: bursty patterns designed to create overlapping triplet motifs.

This gave the traces enough time to accumulate, decay, and interact across multiple spike events.

### Step 6: Weight Saturation and Asymmetric Depression

With equal A2/A3 parameters, potentiation and depression roughly balanced out -- except that the bursty patterns drove all weights toward maximum. The weight maps saturated to 15 across the board.

**Fix**: Made depression asymmetrically stronger than potentiation in both pair and triplet components. This ensures that uncorrelated synapses get suppressed, while only strongly correlated synapses (those seeing the right triplet motifs) get potentiated.

### Step 7: Parameter Sweep and Winning Configuration

Tested multiple parameter configurations in parallel, varying A2/A3 ratios, thresholds, trace increments, and spike patterns:

**Winning parameters:**
- `A2_PLUS = 1`, `A2_MINUS = 3` (pair depression 3× stronger than potentiation)
- `A3_PLUS = 1`, `A3_MINUS = 4` (triplet depression 4× stronger than potentiation)
- `DW_SCALE = 2`, `TRACE_INC = 8`
- BLACK pattern: `1100110000001100110000001100110000001100` (burst-gap-burst)
- Slow trace decay: -2 per cycle

### Final Result

**Pair-based STDP** (snn_network.v with same 40-bit burst patterns):
- Phase 1 (Train '0'): N1=3, N2=0 -- correct
- Phase 2 (Train '1'): N1=2, N2=2 -- **TIE, fails to discriminate**
- Phase 3 (Test '0'): N1=3, N2=0
- Phase 4 (Test '1'): N1=2, N2=2 -- **TIE again**

**Triplet STDP** (triplet_snn.v):
- Phase 1 (Train '0'): N1=3, N2=0 -- correct
- Phase 2 (Train '1'): N1=0, N2=3 -- **correct, clear separation**
- Phase 3 (Test '0'): N1=3, N2=0 -- correct
- Phase 4 (Test '1'): N1=0, N2=3 -- **correct, clear separation**

The triplet model achieves perfect 3-0/0-3 classification across all four phases, while the pair-based model ties 2-2 on the '1' digit, failing to differentiate.

### Why the Triplet Rule Wins

The bursty BLACK patterns create pre-post-pre and post-pre-post triplet motifs. The pair-based rule sees each spike pair independently and cannot distinguish between correlated bursts and coincidental timing. The triplet rule's slow traces (`r2`, `o2`) encode the *frequency* of recent spiking, and the asymmetric triplet depression (A3_MINUS=4 >> A3_PLUS=1) selectively suppresses weights for uncorrelated synapses more strongly than the pair-based rule can. Meanwhile, the triplet potentiation term provides a modest boost only when correlated triplets occur. This frequency-dependent modulation gives the triplet rule the finer discrimination needed to classify both digits correctly.