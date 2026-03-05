import sys
import os
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import numpy as np

# Hardcoded file lists for the progression
FILES_N1 = [
    "init_weights_n1.mem", 
    "trained_weights_pass1_n1.mem", 
    "trained_weights_pass2_n1.mem"
]

FILES_N2 = [
    "init_weights_n2.mem", 
    "trained_weights_pass1_n2.mem", 
    "trained_weights_pass2_n2.mem"
]

# Shared Colormap
COLORS = ["#FFFFFF", "#AAAAAA", "#555555", "#000000"] # White to Black
CMAP = mcolors.ListedColormap(COLORS)

def read_mem_file(input_file):
    """Helper function to safely read and parse a .mem file into a 5x5 numpy array."""
    try:
        with open(input_file, 'r') as f:
            lines = [line.strip() for line in f if line.strip() and not line.startswith('//')]
    except FileNotFoundError:
        print(f"Error: File {input_file} not found.")
        return None

    try:
        weights = [int(line, 2) for line in lines]
    except ValueError:
        print(f"Error: Could not parse binary values in {input_file}.")
        return None

    if len(weights) != 25:
        print(f"Warning: Expected 25 weights in {input_file}, found {len(weights)}. Padding/Truncating.")
        weights = (weights + [0]*25)[:25]

    return np.array(weights).reshape((5, 5))

def generate_individual_map(input_file):
    """Generates the single PNG for a given file (Your original logic)."""
    weight_grid = read_mem_file(input_file)
    if weight_grid is None:
        return

    fig, ax = plt.subplots(figsize=(6, 5))
    im = ax.imshow(weight_grid, cmap=CMAP, vmin=0, vmax=3)

    cbar = plt.colorbar(im, ax=ax, ticks=[0, 1, 2, 3], fraction=0.046, pad=0.04)
    cbar.ax.set_yticklabels(['0 (White)', '1', '2', '3 (Black)'])
    cbar.set_label('Weight Value', rotation=270, labelpad=15)

    ax.set_title(f"Weight Map: {input_file}")
    ax.set_xticks(np.arange(5))
    ax.set_yticks(np.arange(5))
    ax.set_xticklabels(np.arange(1, 6))
    ax.set_yticklabels(np.arange(1, 6))
    
    ax.set_xticks(np.arange(-.5, 5, 1), minor=True)
    ax.set_yticks(np.arange(-.5, 5, 1), minor=True)
    ax.grid(which='minor', color='gray', linestyle='-', linewidth=0.5)

    output_file = os.path.splitext(input_file)[0] + ".png"
    plt.tight_layout()
    plt.savefig(output_file, dpi=300)
    plt.close()
    print(f"Saved individual map to {output_file}")

def generate_progression_grid():
    """Generates a 2x3 grid showing N1 and N2 progression side-by-side."""
    fig, axes = plt.subplots(2, 3, figsize=(12, 8))
    fig.suptitle("SNN Weight Progression Over Training Cycles", fontsize=16, fontweight='bold')

    titles = ["Initial Weights", "After Pass 1", "After Pass 2"]
    
    for row, file_list in enumerate([FILES_N1, FILES_N2]):
        neuron_name = "Neuron 1" if row == 0 else "Neuron 2"
        
        for col, file_name in enumerate(file_list):
            ax = axes[row, col]
            weight_grid = read_mem_file(file_name)
            
            if weight_grid is not None:
                im = ax.imshow(weight_grid, cmap=CMAP, vmin=0, vmax=3)
                ax.set_title(f"{neuron_name}: {titles[col]}", fontsize=11)
            else:
                ax.text(0.5, 0.5, 'File Not Found', ha='center', va='center', color='red')
                ax.set_title(f"{neuron_name}: {titles[col]}")

            # Formatting
            ax.set_xticks(np.arange(5))
            ax.set_yticks(np.arange(5))
            ax.set_xticklabels([]) # Hide labels to keep the grid clean
            ax.set_yticklabels([])
            ax.set_xticks(np.arange(-.5, 5, 1), minor=True)
            ax.set_yticks(np.arange(-.5, 5, 1), minor=True)
            ax.grid(which='minor', color='gray', linestyle='-', linewidth=0.5)

    # Add a single colorbar for the entire figure at the bottom
    cbar_ax = fig.add_axes([0.15, 0.05, 0.7, 0.03]) # [left, bottom, width, height]
    cbar = fig.colorbar(im, cax=cbar_ax, orientation='horizontal', ticks=[0, 1, 2, 3])
    cbar.ax.set_xticklabels(['0 (White)', '1', '2', '3 (Black)'])
    cbar.set_label('Weight Intensity')

    # Adjust layout so subplots don't overlap the colorbar
    plt.subplots_adjust(left=0.05, right=0.95, top=0.9, bottom=0.15, wspace=0.1, hspace=0.2)
    
    output_file = "training_progression.png"
    plt.savefig(output_file, dpi=300)
    plt.close()
    print(f"\nSuccess: Saved unified progression chart to {output_file}")

if __name__ == "__main__":
    print("Starting automated weight mapping...\n")
    
    # 1. Generate individual files
    all_files = FILES_N1 + FILES_N2
    for file in all_files:
        generate_individual_map(file)
        
    # 2. Generate the unified progression grid
    generate_progression_grid()