# HW4: IF Neuron SNN with STDP Learning & Lateral Inhibition

## Files

| File | Description |
|------|-------------|
| `snn_stdp.v` | Main Verilog module — 2 IF output neurons with 25 inputs each, 50 mutable 2-bit weights, STDP learning logic, and lateral inhibition |
| `tb_snn_stdp.v` | Testbench — runs 4 phases: train on '0', train on '1', test on '0', test on '1'. Prints V_mem waveforms, spike counts, and weight maps |
| `ECE274_HW4.pdf` | Assignment specification |
| `notes.md` | Study notes and Q&A from the assignment |

## How to Run

```bash
cd /Users/dakotabarnes/Develop/274/hw4

# Compile
iverilog -o snn_sim snn_stdp.v tb_snn_stdp.v

# Run simulation
vvp snn_sim

# View waveforms (optional)
gtkwave snn_stdp.vcd
```

## Output

The simulation prints:
1. Initial weight maps (5x5 grids for each output neuron)
2. Per-cycle V_mem and spike status for each phase
3. Spike counts per output neuron after each phase
4. Updated weight maps after each training phase

A VCD file (`snn_stdp.vcd`) is generated for waveform viewing in GTKWave.

## Pixel Maps

The pixel maps for training/testing images are defined in `tb_snn_stdp.v` (lines ~108-120). These may need adjustment to match Fig. 4 in the assignment PDF. Each is a 25-bit vector where `1` = black pixel, `0` = white pixel, indexed as `pixel[row*5 + col]`.
