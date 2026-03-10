## Abstract
Spike-timing-dependent plasticity (STDP) is a widely used local learning rule for spiking neural networks (SNNs), but classic pair-based formulations update synaptic weights using only the relative timing of isolated pre-post spike pairs. Pfister and Gerstner (2006) show that this pair-only assumption fails to account for frequency-dependent plasticity and asymmetric responses to spike triplets observed in biological synapses, and propose a triplet STDP rule that introduces additional slow spike traces whose accumulation depends on recent firing history. In this work, we implement a two-layer spiking neural network with triplet STDP in Verilog and compare it against a pair-based STDP baseline on a binary image classification task. We design input spike patterns that vary in rate and burst structure, and show that the triplet implementation's slow-trace-modulated learning rule -- particularly its asymmetric depression term, which amplifies weight decreases at high-activity synapses -- enables successful classification under conditions where pair-based STDP fails. These results demonstrate that the additional expressiveness of the triplet rule translates into practical learning advantages beyond what pair-based timing alone can achieve.

## Introduction
In classical spike-timing-dependent plasticity, synaptic potentiation (LTP) or depression (LTD) depends on whether the postsynaptic spike occurs shortly after or shortly before a presynaptic spike. This pair-based formulation captures the core timing dependence observed in biological synapses, but Pfister and Gerstner (2006) argue that it is not sufficient to explain experimental data from the visual cortex and hippocampus. They identify two major shortcomings: (1) frequency dependency, where repeating the same pre-post timing at different repetition rates produces weight changes that pair-only rules cannot predict, and (2) triplet asymmetry, where pre-post-pre and post-pre-post spike patterns produce different effects on synaptic strength that pair-based STDP, which considers each pair independently, would treat identically. Their proposed triplet rule addresses both through slow trace variables that accumulate in proportion to recent firing activity, introducing a rate-dependent and history-dependent modulation of weight updates that pair-based rules lack.

To address these limitations, Pfister and Gerstner propose a triplet STDP model that augments the pair-based rule with additional spike trace variables. Each synapse maintains two presynaptic traces ($r_1$ and $r_2$) and each postsynaptic neuron maintains two postsynaptic traces ($o_1$ and $o_2$), where the subscript 1 denotes a fast-decaying trace and subscript 2 denotes a slow-decaying trace. The pair-based component of the update rule is unchanged: potentiation depends on whether a presynaptic spike recently preceded a postsynaptic spike, and depression depends on the reverse ordering. The triplet extension incorporates the slow traces as multiplicative modulation terms: potentiation on a postsynaptic spike is additionally scaled by the slow postsynaptic trace $o_2$, which is nonzero when a prior postsynaptic spike occurred recently (forming a post-pre-post triplet). Depression on a presynaptic spike is similarly scaled by the slow presynaptic trace $r_2$, which reflects recent prior presynaptic activity (forming a pre-post-pre triplet). Because the slow traces accumulate in proportion to firing rate, this formulation introduces frequency-dependent plasticity that is absent from pair-based rules. The update ordering specified in the paper computes the weight change using the current trace values before incrementing them on the spike event, so that triplet modulation reflects earlier spikes rather than the spike being processed in the same cycle.

In prior coursework, we implemented a pair-based STDP spiking neural network in Verilog that classifies 5$\times$5 binary images of handwritten digits using two output neurons with lateral inhibition. In this project, we extend that design to implement the Pfister and Gerstner triplet STDP rule and systematically evaluate whether the triplet model can succeed in scenarios where the pair-based model fails. We construct input spike patterns that vary in rate and burst structure, creating conditions where pair-based STDP's fixed-magnitude updates are insufficient for learning but the triplet rule's slow-trace-modulated updates -- with their asymmetric amplification of depression at high-activity synapses -- provide enough additional discriminative capacity for successful classification. We compare classification performance between the pair-based and triplet implementations under identical network conditions.


## Methodology
Our starting point was the pair-based STDP spiking neural network from homework 4. In initial experiments, we observed that the 2-bit weight and 2-cycle shift-register design was highly sensitive to the choice of input spike train -- small changes to spike timing or rate could cause classification to fail entirely. This fragility motivated our investigation: we wanted to understand the conditions under which pair-based STDP breaks down and whether the triplet learning rule could provide more robust learning under those same conditions. To give ourselves more flexibility in designing spike patterns that would expose these failure modes, we extended the spike trains from 20 bits to 40 bits per pixel, doubling the presentation window. This wider window allowed us to construct patterns with varying burst structures and rate contrasts while maintaining enough timesteps for meaningful trace accumulation.

For the triplet STDP implementation, we made several structural modifications to the pair-based SNN from homework 4 (`snn_network.v`), targeting the spike history representation, the learning rule, the weight precision, and the neuron model.

The most fundamental change was replacing the binary shift-register spike history with continuously decaying trace variables, as prescribed by the Pfister and Gerstner (2006) formulation. In the pair-based design, spike history is stored in 25-bit shift registers that record whether each input neuron fired one or two clock cycles ago. This representation is strictly binary -- each bit is either 0 or 1 -- and only retains two cycles of history. The STDP update applies a fixed potentiation of +2 or +1 (for spikes 1 or 2 cycles ago, respectively) and a symmetric depression of -2 or -1, considering only isolated pre-post or post-pre pairs. For triplet STDP, we replaced these shift registers with four sets of 4-bit trace variables: two pre-synaptic traces per input synapse ($r_1[i]$ and $r_2[i]$, for $i = 0, \ldots, 24$) and two post-synaptic traces per output neuron ($o_1$ and $o_2$). The fast traces ($r_1$, $o_1$) decay exponentially by a right-shift of one bit per cycle (effectively halving), while the slow traces ($r_2$, $o_2$) decay linearly by 2 per cycle. On each spike event, the corresponding traces are incremented by a configurable amount, saturating at the 4-bit maximum of 15. This trace-based representation encodes both the recency and frequency of spiking activity in a graded amplitude rather than a binary flag, which is the information the triplet rule requires to modulate weight updates beyond what pair-based timing alone captures.

The weight update rule follows the triplet STDP formulation directly. On a post-synaptic spike, potentiation is computed as $\Delta w^+ = r_1[i] \cdot A_2^+ + \left\lfloor r_1[i] \cdot o_2 / 16 \right\rfloor \cdot A_3^+$, where the first term is the standard pair-based LTP gated by the fast pre-synaptic trace, and the second term is the triplet modulation in which the slow post-synaptic trace $o_2$ scales potentiation when a recent prior post-synaptic spike has occurred (forming a post-pre-post triplet). On a pre-synaptic spike, depression is computed as $\Delta w^- = o_1 \cdot A_2^- + \left\lfloor o_1 \cdot r_2[i] / 16 \right\rfloor \cdot A_3^-$, where the fast post-synaptic trace gates standard LTD and the slow pre-synaptic trace provides triplet modulation for pre-post-pre patterns. The division by 16 (implemented as a 4-bit right-shift) normalizes the product of two 4-bit traces into the same scale as the pair terms. The raw potentiation and depression values are computed in 12-bit arithmetic, right-shifted by a configurable scale factor (`DW_SCALE`), and then applied as a signed delta to the weight with clamping to the valid range.

A deliberate choice was made in how the amplitude parameters ($A_2^\pm$, $A_3^\pm$) were configured. The pair-based amplitude parameters were kept symmetric ($A_2^+ = A_2^- = 1$), matching the equal-magnitude potentiation and depression of the original homework 4 design. This ensures that the pair-based component of the triplet rule behaves identically to standalone pair STDP, providing a clean baseline for comparison: any difference in learning outcomes between the two models can be attributed entirely to the triplet terms rather than to a retuning of the pair-based parameters.

The triplet amplitude parameters, by contrast, were set asymmetrically, with depression stronger than potentiation ($A_3^- > A_3^+$). The Pfister and Gerstner (2006) formulation treats $A_2^\pm$ and $A_3^\pm$ as independent free parameters fit to experimental data, so this asymmetry is permitted by the model. Our specific choice of $A_3^- = 4$, $A_3^+ = 1$ is motivated by a practical observation from our experiments. When the triplet terms are configured symmetrically ($A_3^+ = A_3^-$), the slow traces create a positive feedback loop: the neuron that fires more frequently builds a larger slow post-synaptic trace $o_2$, which amplifies potentiation for its synapses, causing it to fire even more. This winner-takes-all dynamic is stronger than the pair-based version, but it does not improve classification — it simply causes the dominant neuron to win for both digit classes. Making triplet depression stronger than triplet potentiation counteracts this runaway effect. The slow pre-synaptic trace $r_2$, which accumulates proportionally to input firing rate, selectively amplifies depression for high-activity synapses. This rate-dependent depression suppresses weights for uncorrelated inputs more aggressively than the pair terms alone, while the modest triplet potentiation term reinforces only those synapses participating in correlated post-pre-post triplet motifs. The result is a learning rule where the triplet terms provide the frequency-sensitive modulation that Pfister and Gerstner identify as missing from pair-based models, without disrupting the symmetric pair-based baseline.

In addition to the learning rule, we expanded the synaptic weight resolution from 2-bit (range 0--3) to 4-bit (range 0--15). With only four weight levels, the graded updates produced by the trace-based triplet rule were quantized to the same coarse steps as the pair-based rule, effectively erasing the triplet contribution. The 4-bit range provides 16 levels, giving the learning rule sufficient dynamic range to express the fine-grained differences between pair-only and triplet-modulated updates. Initial weight values were scaled by 4$\times$ from the original pair-based values to preserve the relative weight distribution at initialization. To accommodate the larger weights (a maximum weighted sum of $15 \times 25 = 375$, which exceeds 8 bits), the weighted sum accumulator was widened to 9 bits, and all neuron voltage parameters -- resting potential ($V_{REST}$), firing threshold ($V_{THRESHOLD}$), and leak ($V_{LEAK}$) -- were scaled by 4$\times$ to maintain equivalent dynamics in the wider datapath.

Finally, the neuron model was upgraded from integrate-and-fire (IF) to leaky integrate-and-fire (LIF) by subtracting a constant leak term ($V_{LEAK} = 4$) from the membrane potential each cycle, with clamping to prevent the potential from dropping below rest. This prevents runaway membrane potential accumulation over the longer 40-timestep presentation window and more closely matches biological neuron behavior. The lateral inhibition mechanism -- where a spike from one output neuron forces the other to reset in the following cycle -- was preserved unchanged from the pair-based design, ensuring that any performance differences are attributable to the learning rule rather than the competitive dynamics.

The implementation for triplet STDP learning was first tested on the same 40-bit spike train that gave successful results in the pair STDP-based neural network to calibrate the design and ensure correct functionality. From this baseline, we designed experiments to expose conditions where the triplet rule's additional learning capacity provides an advantage over pair-based STDP.

As described above, spike trains were expanded to 40 bits per pixel. The weight resolution was also expanded from 2-bit to 4-bit to provide the granularity needed for trace-based updates; the voltage parameters ($V_{REST}$, $V_{THRESHOLD}$, $V_{LEAK}$) were then scaled by 4$\times$ to maintain equivalent neuron dynamics with the wider weight range.

To show a successful implementation of a triplet STDP algorithm, multiple experiments were conducted. The first experiment established that triplet STDP does not degrade performance in a scenario where pair STDP already succeeds. The subsequent experiments were designed to demonstrate conditions where the triplet rule's slow-trace modulation and asymmetric coefficients enable successful classification but pair-based STDP fails.

### Experiment 1: Baseline Calibration

Experiment 1.1				       Experiment 1.2
20 bit Pair-STDP Baseline Spike Train:              40 bit Pair-STDP Baseline Spike Train:
 “white”: “01000000100000000010”,                             “white”: “0100000010000000001001000000100000000010”,
 “black”: “01010100010101000101”,                             “black”: “0101010001010100010101010100010101000101”,

These baseline spike trains, which were shown in prior coursework to successfully train a pair-based STDP network, served as a calibration point. Experiment 1.1 uses the original 20-bit / 2-bit weight configuration, and Experiment 1.2 extends to 40-bit spike trains with 4-bit weights. Comparing the two confirmed that the expanded weight resolution and voltage scaling preserved correct learning behavior. The triplet STDP network was also verified on Experiment 1.2 to confirm it does not break a scenario where pair STDP already works.

### Experiment 2: Rate-Dependent Weight Modulation

The triplet model introduces rate sensitivity through its slow traces ($r_2$, $o_2$), which accumulate in proportion to firing frequency. When input rates differ between WHITE and BLACK pixels, the slow pre-synaptic trace $r_2$ builds up more at higher-rate (BLACK) synapses. This elevated $r_2$ is amplified by the triplet depression coefficient $A_3^- = 4$, creating stronger depression at high-rate synapses. Pair-based STDP lacks this mechanism: with symmetric $A_2^+ = A_2^- = 1$, the magnitude of each weight update is the same regardless of the broader firing context, so moderate rate differences produce weight maps that are too similar for the two output neurons to specialize.

To test this, we designed evenly-spaced spike patterns with no burst structure, where BLACK pixels fire at a higher rate than WHITE pixels (2.5:1 ratio):

Experiment 2.1 (C1-2):
“white”: “0100000000010000000001000000000100000000” (4 spikes, evenly spaced)
“black”: “0100100001001000010010000100100001001000” (10 spikes, evenly spaced)

Experiment 2.2 (C2-31):
“white”: “0010000000001000000000100000000010000000” (4 spikes, evenly spaced)
“black”: “0010010000100100001001000010010000100100” (10 spikes, evenly spaced)

Both patterns are evenly spaced with no burst structure, isolating the rate difference as the sole variable. The BLACK pattern has 2.5$\times$ the firing rate of WHITE. For pair-based STDP, the higher BLACK rate produces more spike pairs and thus more weight updates, but each update has the same fixed magnitude — the result is that one neuron accumulates enough of an advantage during the first training image to dominate both digit classes. For triplet STDP, the slow pre-synaptic traces at BLACK-pixel synapses accumulate to higher values than at WHITE-pixel synapses, and the asymmetric triplet depression ($A_3^- = 4$) selectively amplifies depression at these high-rate inputs. This rate-dependent modulation enables the two neurons to develop distinct weight templates.

### Experiment 3: Activity-Dependent Competitive Learning with Bursty Inputs

In Experiment 2, both WHITE and BLACK patterns used evenly-spaced isolated spikes. Experiment 3 introduces burst structure: BLACK pixels fire in clusters of 2--3 consecutive spikes separated by gaps, while WHITE pixels fire isolated spikes. Bursts cause the slow pre-synaptic trace $r_2$ to accumulate rapidly — consecutive pre-synaptic spikes compound the trace before it can decay (e.g., two spikes one cycle apart yield $r_2 \approx 14$ out of a maximum of 15). This elevated $r_2$ is multiplied by the triplet depression coefficient $A_3^- = 4$, creating amplified depression at burst-active synapses. The triplet potentiation term, weighted at only $A_3^+ = 1$, does not produce comparable amplification. Pair-based STDP, with its symmetric $A_2^+ = A_2^- = 1$, decomposes bursts into independent pairs whose potentiation and depression contributions largely cancel, making bursts effectively neutral to the learning rule.

We tested both burst-of-3 (`111`) and doublet (`11`) BLACK patterns across multiple timing configurations:

Experiment 3.1 (Burst-of-3, best example):
“white”: “0000100000001000000010000000100000000000” (4 spikes, isolated)
“black”: “0001110000000111000000011100000001110000” (12 spikes, four “111” bursts)

Experiment 3.2 (Doublet, strongest separation):
“white”: “0000010000000001000000000100000000010000” (4 spikes, isolated)
“black”: “0110001100000110001100001100011000001100” (14 spikes, seven “11” doublets)

A total of 9 pattern configurations were found where both original and pair-based STDP fail but triplet STDP succeeds (3 burst-of-3 patterns and 6 doublet patterns). The doublet finding is notable: even two consecutive spikes produce enough $r_2$ accumulation for the triplet depression term to create meaningful weight differentiation, provided the timing relative to WHITE spikes allows sufficient rate-code contrast between the two digit images.


## Results

### Experiment 1: Baseline Calibration

Figure 2 and Figure 3 show the weight maps from the baseline experiments 1.1 and 1.2, run on the pair-based STDP network for 20-bit / 2-bit weight and 40-bit / 4-bit weight configurations, respectively. The triplet STDP network was also verified on the 40-bit / 4-bit configuration, confirming that it produces correct classification when pair STDP already succeeds. Since all subsequent triplet experiments use 4-bit weights, Experiment 1.2 serves as the baseline for comparison. Experiment 1.1 was used to calibrate the voltage and weight scaling needed to support the wider datapath.

Figure 2: Experiment 1.1 Weight Maps            Figure 3: Experiment 1.2 Weight Maps

### Experiment 2: Rate-Dependent Weight Modulation

Both pattern configurations (C1-2 and C2-31) use evenly-spaced spikes with no burst structure, differing only in the firing rate between WHITE (4 spikes) and BLACK (10 spikes) pixels. Classification results are summarized below:

| Config | Experiment | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|------------|-------------------|-------------------|--------|
| Original | C1-2 | 0, 4 | 0, 4 | FAIL (N2 both) |
| Pair | C1-2 | 4, 0 | 4, 2 | FAIL (N1 both) |
| **Triplet** | **C1-2** | **4, 0** | **1, 3** | **PASS** |
| Original | C2-31 | 0, 4 | 0, 4 | FAIL (N2 both) |
| Pair | C2-31 | 4, 0 | 4, 2 | FAIL (N1 both) |
| **Triplet** | **C2-31** | **4, 0** | **1, 3** | **PASS** |

The original 2-bit configuration saturates its weights (range 0--3) too quickly, with both neurons converging to nearly identical weight maps. The 4-bit pair-based model develops differentiated weight maps after training, but the differentiation is insufficient: Neuron 1 dominates both test digits because the symmetric pair updates ($A_2^+ = A_2^- = 1$) accumulate similar total potentiation across both training images, giving the first-trained neuron an advantage it never relinquishes. Triplet STDP produces a qualitatively different outcome: the slow pre-synaptic traces at BLACK-pixel synapses accumulate to higher values during training (reflecting their 2.5$\times$ higher firing rate), and the $A_3^- = 4$ depression term amplifies weight decreases at these synapses. This rate-dependent depression creates sufficient asymmetry between the two weight maps for the second neuron to specialize on the complementary digit.

Figure 4: Experiment 2 Weight Maps (Original, Pair, and Triplet for C1-2)

### Experiment 3: Activity-Dependent Competitive Learning with Bursty Inputs

Across all 9 successful burst configurations, the original and pair-based models failed while triplet STDP succeeded. The best examples from each burst type are shown below:

| Config | Pattern | Test '0' (N1, N2) | Test '1' (N1, N2) | Result |
|--------|---------|-------------------|-------------------|--------|
| Original | Burst-of-3 | 2, 4 | 0, 4 | FAIL (N2 both) |
| Pair | Burst-of-3 | 5, 0 | 4, 0 | FAIL (N1 both) |
| **Triplet** | **Burst-of-3** | **4, 0** | **0, 4** | **PASS** |
| Original | Doublet | 4, 4 | 4, 4 | FAIL (tied) |
| Pair | Doublet | 4, 1 | 4, 2 | FAIL (N1 both) |
| **Triplet** | **Doublet** | **3, 0** | **0, 4** | **PASS** |

The burst-of-3 example produced perfect separation (4,0)/(0,4) for the triplet model. The doublet example produced the strongest separation of any doublet pattern tested: (3,0)/(0,4), with zero overlap between the winning neuron's output across the two test digits.

Pair-based STDP fails because its symmetric updates ($A_2^+ = A_2^- = 1$) cause the potentiation and depression contributions from burst spikes to largely cancel. The result is that one neuron (typically N1, which benefits from favorable initial weights for the first training image) accumulates enough advantage to dominate both digit classes. Triplet STDP succeeds because the slow pre-synaptic trace $r_2$ accumulates rapidly during bursts — for a doublet, $r_2$ reaches approximately 14 out of 15 on the second spike — and this elevated trace is amplified by $A_3^- = 4$ in the depression term. BLACK-pixel synapses (receiving bursts) experience 4$\times$ amplified depression relative to WHITE-pixel synapses (receiving isolated spikes, where $r_2$ remains low). This differential depression breaks the symmetry between the two output neurons, enabling competitive specialization.

Several instructive failures provided additional insight. Patterns with alternating isolated spikes (no burst structure) failed for all three models, confirming that the triplet advantage requires consecutive spikes to accumulate the slow traces. Conversely, dense burst-of-4 patterns overloaded the network, causing identical responses to both digit images. The triplet advantage was most robust with burst-of-2 and burst-of-3 patterns where the trace accumulation was sufficient for the triplet terms to produce meaningful modulation without saturating the network.

Figure 5: Experiment 3 Weight Maps (Burst-of-3: Original, Pair, Triplet)
Figure 6: Experiment 3 Weight Maps (Doublet: Original, Pair, Triplet)
