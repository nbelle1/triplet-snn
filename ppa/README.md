# PPA Analysis — Triplet SNN ASIC Flow

Synthesize and place-and-route the SNN designs using LibreLane (OpenLane-based) targeting Sky130.

## File Overview

| File | Purpose |
|------|---------|
| `architectures.json` | Ground truth for all architecture definitions (params, RTL files, groups). Referenced by all notebooks. |
| `ppa_analysis.ipynb` | Generate LibreLane configs, run synthesis, load PPA metrics, and produce comparison plots. |
| `arch_regression.ipynb` | Validate functional correctness and compare performance across architectures using simulation. |
| `dynamic_power_analysis.ipynb` | Measure dynamic power (VCD toggle counts) and temporal metrics (active/idle cycles, convergence, inference latency). |
| `<arch_key>/config.json` | Per-design LibreLane config (auto-generated from `architectures.json` by the notebook). |

## Architectures

Defined in `architectures.json`. Two groups — **baseline** (from reports) and **optimized** (new):

| Key | Label | Group | RTL File | Key Parameters |
|-----|-------|-------|----------|----------------|
| `original_pair` | Original Pair | baseline | `snn_network.v` | 2-bit weights, IF, symmetric |
| `pair` | Pair | baseline | `snn_dynamic.v` | `TRIPLET_EN=0, LEAK_EN=1, W_BITS=4` |
| `triplet` | Triplet | baseline | `snn_dynamic.v` | `TRIPLET_EN=1, LEAK_EN=1, W_BITS=4` |
| `triplet_optimized` | Triplet Optimized | optimized | `snn_dynamic_optimized.v` | Same as triplet, optimized RTL |
| `triplet_optimized_spike_gated` | Triplet Opt. Spike-Gated | optimized | `snn_dynamic_optimized.v` | `SPIKE_GATE_EN=1` |
| `triplet_optimized_nn` | Triplet Opt. Nearest-Neighbor | optimized | `snn_dynamic_optimized.v` | `MODE=1` |

## Prerequisites

1. **LibreLane** — Install from [github.com/efabless/openlane2](https://github.com/efabless/openlane2) (LibreLane is the renamed OpenLane 2). Follow the [Nix-based installation guide](https://librelane.readthedocs.io/en/latest/installation/nix_installation/index.html#nix-based-installation) to set up the nix shell.

2. **Sky130 PDK** — Installed automatically by LibreLane/CIEL on first run, or manually via:
   ```bash
   ciel install sky130A
   ```

3. **Environment variable** — Set `LIBRELANE_SHELL` to point to your LibreLane nix shell file, e.g.:
   ```bash
   export LIBRELANE_SHELL=/path/to/librelane/shell.nix
   ```
   Alternatively, you can `cd` into the LibreLane repo and run `nix develop` directly.

4. **Python dependencies** — From the repo root:
   ```bash
   pip install -r requirements.txt
   ```

## Running the Flow

### 1. Generate configs and run LibreLane

Open `ppa_analysis.ipynb` and run the first cells to:
1. Load `architectures.json`
2. Auto-generate per-design `config.json` files
3. Run LibreLane (parallel or sequential — toggle `PARALLEL` flag)

Or run manually from a terminal:

```bash
nix-shell $LIBRELANE_SHELL

for config in ppa/*/config.json; do
    echo "=== Running: $config ==="
    python3 -m librelane "$config"
done
```

Results land in `<arch_key>/runs/*/final/metrics.json`.

### 2. Analyze PPA

Continue running `ppa_analysis.ipynb` to load metrics, generate comparison tables, and produce area/power/timing plots.

### 3. Run regression

Open `arch_regression.ipynb` to validate functional correctness across architectures using the test patterns from `reports/`.

## Adding or Modifying Architectures

Edit `architectures.json` to add/change designs. Both notebooks read from this file, so changes propagate automatically. Re-run the config generation cell in `ppa_analysis.ipynb` to regenerate `config.json` files.

## Troubleshooting

- **Verilator lint errors on `$readmemh` / `initial` blocks**: The RTL wraps these in `` `ifndef SYNTHESIS `` guards. All configs define `SYNTHESIS` via `VERILOG_DEFINES`.
- **"Yosys check errors"**: The `integer i` loop counter creates benign conflicting-driver warnings in the early CHECK pass (resolved by later optimization). All configs set `ERROR_ON_SYNTH_CHECKS: false` to downgrade these to warnings.
- **Missing PDK**: If you see PDK-related errors, ensure CIEL has installed Sky130A. Run `ciel install sky130A` or check `~/.ciel/`.
