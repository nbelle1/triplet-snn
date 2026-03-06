# ECE274 Toolchain

This project is a small Python toolchain for creating pixel-based input data, converting that data into spike-train memory files, generating random weight memories, and visualizing stored weights as a heat map.

## Files

### `pixel_grid.py`

Interactive `tkinter` editor for drawing a `28x28` black-and-white pixel grid.

- Left click or left drag paints black pixels (`1`)
- Right click or right drag erases to white (`0`)
- Brush size is adjustable in the UI
- CSV files are saved into the `grids/` folder
- The save folder is created automatically if it does not exist
- The user can choose the CSV filename from the UI

This is the starting point for creating dataset examples such as handwritten digits or other binary patterns.

### `csv2spiketrain.py`

Batch converter that reads all `.csv` grid files from a folder and converts each pixel into a spike train.

- Input folder is configurable at the top of the file
- Output `.mem` files are written into the `dataset/` folder
- The `dataset/` folder is created automatically if it does not exist
- Each output filename matches the source CSV filename
- Pixel values are mapped to black-pixel and white-pixel spike trains loaded from `param.mem`

The script ignores blank lines and comment lines in `param.mem`. It accepts comment styles beginning with `#` or `//`.

### `param.mem`

Parameter file that defines the spike train used for:

- black pixels (`1`)
- white pixels (`0`)

The converter reads the first two binary entries in the file and checks that they are the same length.

### `weight_gen.py`

Random weight-memory generator.

- Generates an `N x N` grid of weights
- Each weight is initialized to a random `B`-bit value
- One weight is written per line in the output `.mem` file
- Grid size, bit width, and output filename are configurable at the top of the script

This is useful for creating initialization files for simulations or hardware experiments.

### `weight_heatmap.py`

Weight visualization tool.

- Reads a `.mem` file containing one binary weight per line
- Reconstructs the `N x N` grid
- Displays the values as a `tkinter` heat map
- Includes a color legend showing how color maps to weight value
- Can be run directly or imported and called from another Python file

Example:

```python
from weight_heatmap import show_weight_heatmap

show_weight_heatmap("weights.mem")
```

## Typical Workflow

1. Use `pixel_grid.py` to draw binary images and save them as CSV files in `grids/`.
2. Set the black and white spike-train values in `param.mem`.
3. Run `csv2spiketrain.py` to convert all grid CSV files into `.mem` spike-train files in `dataset/`.
4. Use `weight_gen.py` to generate random weight memories.
5. Use `weight_heatmap.py` to inspect the generated weights visually.

## Running The Scripts

```powershell
python pixel_grid.py
python csv2spiketrain.py
python weight_gen.py
python weight_heatmap.py
```

## Requirements

- Python 3
- `tkinter` available in the Python installation

No third-party Python packages are required by the current scripts.
