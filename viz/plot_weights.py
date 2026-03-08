import argparse
import subprocess
import re
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors

# ---------------------------------------------------------------------------
# CLI: choose which network to train & plot
# ---------------------------------------------------------------------------
TARGETS = {
    "snn":     {"make": ["make", "train"],         "title": "SNN Network"},
    "triplet": {"make": ["make", "triplet-train"], "title": "Triplet SNN"},
    "dynamic": {"make": ["make", "ablation"],      "title": "Dynamic SNN"},
}

parser = argparse.ArgumentParser(description="Plot weight heatmaps for SNN variants")
parser.add_argument("target", nargs="?", default="snn", choices=TARGETS.keys(),
                    help="Which network to train and plot (default: snn)")
parser.add_argument("--make-args", nargs="*", default=[],
                    help="Extra make arguments, e.g. W_BITS=2 TRIPLET_EN=0")
args = parser.parse_args()

cfg = TARGETS[args.target]
make_cmd = cfg["make"] + args.make_args

# ---------------------------------------------------------------------------
# Run simulation and capture output
# ---------------------------------------------------------------------------
result = subprocess.run(make_cmd, capture_output=True, text=True, cwd=".")
output = result.stdout

# parse weight lines: "BEFORE W1: 1 0 0 1 2 ..." or "AFTER W1: ..."
pattern = r"(BEFORE|AFTER) (W[12]): ([\d ]+)"
matches = re.findall(pattern, output)

if not matches:
    print("No weight data found in simulation output.")
    print("--- stdout ---")
    print(output[-2000:] if len(output) > 2000 else output)
    print("--- stderr ---")
    print(result.stderr[-2000:] if len(result.stderr) > 2000 else result.stderr)
    raise SystemExit(1)

# ---------------------------------------------------------------------------
# Organise by phase
# ---------------------------------------------------------------------------
phase_names = ["Train '0'", "Train '1'"]
phase_data = {}
for tag, neuron, vals in matches:
    weights = np.array([int(v) for v in vals.split()]).reshape(5, 5)
    key = (tag, neuron)
    if key not in phase_data:
        phase_data[key] = []
    phase_data[key].append(weights)

# ---------------------------------------------------------------------------
# Auto-detect weight range and build colormap
# ---------------------------------------------------------------------------
all_weights = np.concatenate([w.ravel() for wlist in phase_data.values() for w in wlist])
w_max = int(all_weights.max())

if w_max <= 3:
    # 2-bit: discrete 4-level grayscale (original behaviour)
    cmap = mcolors.ListedColormap(["#FFFFFF", "#AAAAAA", "#555555", "#000000"])
    bounds = [-0.5, 0.5, 1.5, 2.5, 3.5]
    norm = mcolors.BoundaryNorm(bounds, cmap.N)
    text_thresh = 2
else:
    # wider weights: continuous grayscale
    cmap = "gray_r"
    norm = mcolors.Normalize(vmin=0, vmax=w_max)
    text_thresh = w_max / 2

# ---------------------------------------------------------------------------
# Plot
# ---------------------------------------------------------------------------
fig, axes = plt.subplots(4, 2, figsize=(8, 14))

row = 0
for phase_idx, phase_name in enumerate(phase_names):
    for tag in ["BEFORE", "AFTER"]:
        for col, neuron in enumerate(["W1", "W2"]):
            key = (tag, neuron)
            if key in phase_data and phase_idx < len(phase_data[key]):
                weights = phase_data[key][phase_idx]
            else:
                continue

            ax = axes[row, col]
            im = ax.imshow(weights, cmap=cmap, norm=norm)
            ax.set_title(f"{phase_name} - {tag} - Neuron {col+1}", fontsize=10)

            for r in range(5):
                for c in range(5):
                    val = weights[r, c]
                    color = "white" if val >= text_thresh else "black"
                    ax.text(c, r, str(val), ha="center", va="center",
                            fontsize=12, fontweight="bold", color=color)

            ax.set_xticks(range(5))
            ax.set_yticks(range(5))
            ax.set_xticklabels([])
            ax.set_yticklabels([])
            ax.tick_params(length=0)

        row += 1

out_file = f"weight_heatmaps_{args.target}.png"
fig.suptitle(f"{cfg['title']} — Weight Maps Before/After Each Training Phase",
             fontsize=13, fontweight="bold")
fig.tight_layout(rect=[0, 0, 1, 0.96])
plt.savefig(out_file, dpi=150, bbox_inches="tight")
plt.show()
print(f"Saved to {out_file}")
