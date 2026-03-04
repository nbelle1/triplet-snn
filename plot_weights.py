import subprocess
import re
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors

# run simulation and capture output
result = subprocess.run(
    ["make", "train"],
    capture_output=True, text=True, cwd="."
)
output = result.stdout

# parse weight lines: "BEFORE W1: 1 0 0 1 2 ..." or "AFTER W1: ..."
pattern = r"(BEFORE|AFTER) (W[12]): ([\d ]+)"
matches = re.findall(pattern, output)

# organize by phase
# phases appear in order: Train '0', Train '1'
phase_names = ["Train '0'", "Train '1'"]
phases = []
phase_data = {}
for tag, neuron, vals in matches:
    weights = np.array([int(v) for v in vals.split()]).reshape(5, 5)
    key = (tag, neuron)
    if key not in phase_data:
        phase_data[key] = []
    phase_data[key].append(weights)

# build plot: 2 rows (before/after) x 2 cols (W1/W2) per training phase
# total: 2 phases x 2 rows x 2 cols = 8 subplots
fig, axes = plt.subplots(4, 2, figsize=(8, 14))

# grayscale colormap: 0=white, 3=black (matching spec Fig. 6)
cmap = mcolors.ListedColormap(["#FFFFFF", "#AAAAAA", "#555555", "#000000"])
bounds = [-0.5, 0.5, 1.5, 2.5, 3.5]
norm = mcolors.BoundaryNorm(bounds, cmap.N)

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

            # annotate cells with weight values
            for r in range(5):
                for c in range(5):
                    val = weights[r, c]
                    color = "white" if val >= 2 else "black"
                    ax.text(c, r, str(val), ha="center", va="center",
                            fontsize=12, fontweight="bold", color=color)

            ax.set_xticks(range(5))
            ax.set_yticks(range(5))
            ax.set_xticklabels([])
            ax.set_yticklabels([])
            ax.tick_params(length=0)

        row += 1

fig.suptitle("Weight Maps Before/After Each Training Phase", fontsize=13, fontweight="bold")
fig.tight_layout(rect=[0, 0, 1, 0.96])
plt.savefig("weight_heatmaps.png", dpi=150, bbox_inches="tight")
plt.show()
print("Saved to weight_heatmaps.png")
