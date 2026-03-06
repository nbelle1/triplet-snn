import tkinter as tk
from pathlib import Path

# Call this script like so:
# from weight_heatmap import show_weight_heatmap
# show_weight_heatmap("<input_file>", grid_size=28, cell_size=16))

# User configuration
INPUT_FILE = Path("weights.mem")
GRID_SIZE = 28
CELL_SIZE = 20
LEGEND_WIDTH = 80


def load_weights(input_file: Path, grid_size: int) -> list[list[int]]:
    with input_file.open("r", encoding="utf-8") as mem_file:
        lines = [line.strip() for line in mem_file if line.strip()]

    expected_count = grid_size * grid_size
    if len(lines) != expected_count:
        raise ValueError(
            f"Expected {expected_count} weights for a {grid_size}x{grid_size} grid, got {len(lines)}."
        )

    if any(set(line) - {"0", "1"} for line in lines):
        raise ValueError("All weights must be binary values.")

    values = [int(line, 2) for line in lines]
    return [
        values[row * grid_size : (row + 1) * grid_size]
        for row in range(grid_size)
    ]


def color_for_value(value: int, max_value: int) -> str:
    if max_value == 0:
        intensity = 0
    else:
        intensity = int((value / max_value) * 255)

    red = intensity
    green = 40
    blue = 255 - intensity
    return f"#{red:02x}{green:02x}{blue:02x}"


def draw_heatmap(canvas: tk.Canvas, weights: list[list[int]], cell_size: int) -> None:
    max_value = max(max(row) for row in weights)

    for row_index, row in enumerate(weights):
        for col_index, value in enumerate(row):
            x1 = col_index * cell_size
            y1 = row_index * cell_size
            x2 = x1 + cell_size
            y2 = y1 + cell_size
            canvas.create_rectangle(
                x1,
                y1,
                x2,
                y2,
                fill=color_for_value(value, max_value),
                outline="black",
            )


def draw_legend(canvas: tk.Canvas, max_value: int, legend_height: int) -> None:
    gradient_top = 20
    gradient_bottom = legend_height - 20
    gradient_left = 20
    gradient_right = 45
    gradient_height = max(1, gradient_bottom - gradient_top)

    for offset in range(gradient_height):
        value = max_value * (1 - (offset / gradient_height))
        y = gradient_top + offset
        canvas.create_line(
            gradient_left,
            y,
            gradient_right,
            y,
            fill=color_for_value(int(value), max_value),
        )

    canvas.create_rectangle(
        gradient_left,
        gradient_top,
        gradient_right,
        gradient_bottom,
        outline="black",
    )
    canvas.create_text(gradient_right + 8, gradient_top, text=str(max_value), anchor="w")
    canvas.create_text(gradient_right + 8, gradient_bottom, text="0", anchor="w")
    canvas.create_text(
        gradient_left,
        5,
        text="Value",
        anchor="nw",
    )


def show_weight_heatmap(
    input_file: str | Path = INPUT_FILE,
    grid_size: int = GRID_SIZE,
    cell_size: int = CELL_SIZE,
) -> None:
    input_path = Path(input_file)
    weights = load_weights(input_path, grid_size)
    max_value = max(max(row) for row in weights)

    root = tk.Tk()
    root.title(f"Weight Heatmap: {input_path}")

    container = tk.Frame(root)
    container.pack(padx=10, pady=10)

    heatmap_canvas = tk.Canvas(
        container,
        width=grid_size * cell_size,
        height=grid_size * cell_size,
        highlightthickness=0,
    )
    heatmap_canvas.pack(side="left")

    legend_canvas = tk.Canvas(
        container,
        width=LEGEND_WIDTH,
        height=grid_size * cell_size,
        highlightthickness=0,
    )
    legend_canvas.pack(side="left", padx=(12, 0))

    draw_heatmap(heatmap_canvas, weights, cell_size)
    draw_legend(legend_canvas, max_value, grid_size * cell_size)
    root.mainloop()


def main() -> None:
    show_weight_heatmap(INPUT_FILE, GRID_SIZE, CELL_SIZE)


if __name__ == "__main__":
    main()
