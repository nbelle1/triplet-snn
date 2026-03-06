import subprocess
import re
import numpy as np
import matplotlib.pyplot as plt

# run simulation and capture output (using your updated verbose target)
result = subprocess.run(
    ["make", "verbose"],
    capture_output=True, text=True, cwd="."
)
output = result.stdout

# parse weight lines: "BEFORE N0: 10 43 0 63 ..."
pattern = r"(BEFORE|AFTER) N(\d+): ([\d ]+)"
matches = re.findall(pattern, output)

phase_data = {}
for tag, neuron_str, vals in matches:
    neuron_idx = int(neuron_str)
    # Reshape the 784 weights into a 28x28 image grid
    weights = np.array([int(v) for v in vals.split()]).reshape(28, 28)
    
    key = (tag, neuron_idx)
    if key not in phase_data:
        phase_data[key] = weights

# Build plot: 10 rows (Neurons) x 2 cols (Before/After)
fig, axes = plt.subplots(10, 2, figsize=(8, 20))

for n in range(10):
    for col, tag in enumerate(["BEFORE", "AFTER"]):
        key = (tag, n)
        ax = axes[n, col]
        
        if key in phase_data:
            # Use 'viridis' or 'gray' colormap for 0-63 range
            im = ax.imshow(phase_data[key], cmap="gray", vmin=0, vmax=63)
            ax.set_title(f"Neuron {n} - {tag}", fontsize=10)
        else:
            ax.text(0.5, 0.5, "No Data", ha='center', va='center')
            
        ax.set_xticks([])
        ax.set_yticks([])

fig.suptitle("28x28 Weight Maps Before/After Training", fontsize=14, fontweight="bold")
fig.tight_layout(rect=[0, 0, 1, 0.98])
plt.savefig("weight_heatmaps.png", dpi=150, bbox_inches="tight")
print("Saved to weight_heatmaps.png")