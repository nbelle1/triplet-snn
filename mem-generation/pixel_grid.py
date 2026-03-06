import csv
import tkinter as tk
from pathlib import Path


GRID_SIZE = 28
CELL_SIZE = 20
BLACK = 1
WHITE = 0
OUTPUT_FOLDER = Path("grids")


class PixelGridApp:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("28x28 Pixel Grid")

        self.grid = [[WHITE for _ in range(GRID_SIZE)] for _ in range(GRID_SIZE)]
        self.brush_size = tk.IntVar(value=1)
        self.file_name = tk.StringVar(value="pixel_grid")

        self.canvas = tk.Canvas(
            root,
            width=GRID_SIZE * CELL_SIZE,
            height=GRID_SIZE * CELL_SIZE,
            bg="white",
            highlightthickness=0,
        )
        self.canvas.pack(padx=10, pady=10)
        self.canvas.bind("<Button-1>", self.on_left_click)
        self.canvas.bind("<B1-Motion>", self.on_left_drag)
        self.canvas.bind("<Button-3>", self.on_right_click)
        self.canvas.bind("<B3-Motion>", self.on_right_drag)

        controls = tk.Frame(root)
        controls.pack(fill="x", padx=10, pady=(0, 10))

        tk.Button(controls, text="Clear", command=self.clear_grid).pack(side="left")
        tk.Button(controls, text="Save CSV", command=self.save_csv).pack(side="left", padx=(8, 0))
        tk.Label(controls, text="File name").pack(side="left", padx=(16, 4))
        tk.Entry(controls, width=16, textvariable=self.file_name).pack(side="left")
        tk.Label(controls, text="Brush size").pack(side="left", padx=(16, 4))
        tk.Spinbox(
            controls,
            from_=1,
            to=9,
            width=3,
            textvariable=self.brush_size,
        ).pack(side="left")

        self.status = tk.Label(
            root,
            text="Left click/drag: black (1)    Right click/drag: white (0)    Save CSV writes to the grids folder.",
            anchor="w",
        )
        self.status.pack(fill="x", padx=10, pady=(0, 10))

        self.draw_grid()

    def draw_grid(self) -> None:
        self.canvas.delete("all")
        for row in range(GRID_SIZE):
            for col in range(GRID_SIZE):
                x1 = col * CELL_SIZE
                y1 = row * CELL_SIZE
                x2 = x1 + CELL_SIZE
                y2 = y1 + CELL_SIZE
                fill = "black" if self.grid[row][col] == BLACK else "white"
                self.canvas.create_rectangle(x1, y1, x2, y2, fill=fill, outline="gray")

    def set_cell(self, event: tk.Event, value: int) -> None:
        col = event.x // CELL_SIZE
        row = event.y // CELL_SIZE

        if 0 <= row < GRID_SIZE and 0 <= col < GRID_SIZE:
            brush_size = max(1, min(GRID_SIZE, self.brush_size.get()))
            half_width = brush_size // 2

            start_row = max(0, row - half_width)
            start_col = max(0, col - half_width)
            end_row = min(GRID_SIZE, start_row + brush_size)
            end_col = min(GRID_SIZE, start_col + brush_size)

            if end_row - start_row < brush_size:
                start_row = max(0, end_row - brush_size)
            if end_col - start_col < brush_size:
                start_col = max(0, end_col - brush_size)

            for brush_row in range(start_row, end_row):
                for brush_col in range(start_col, end_col):
                    self.grid[brush_row][brush_col] = value
            self.draw_grid()

    def on_left_click(self, event: tk.Event) -> None:
        self.set_cell(event, BLACK)

    def on_left_drag(self, event: tk.Event) -> None:
        self.set_cell(event, BLACK)

    def on_right_click(self, event: tk.Event) -> None:
        self.set_cell(event, WHITE)

    def on_right_drag(self, event: tk.Event) -> None:
        self.set_cell(event, WHITE)

    def clear_grid(self) -> None:
        for row in range(GRID_SIZE):
            for col in range(GRID_SIZE):
                self.grid[row][col] = WHITE
        self.draw_grid()

    def save_csv(self) -> None:
        file_stem = self.file_name.get().strip()
        if not file_stem:
            self.status.config(text="Enter a file name before saving.")
            return

        OUTPUT_FOLDER.mkdir(exist_ok=True)
        file_path = OUTPUT_FOLDER / f"{file_stem}.csv"

        with file_path.open("w", newline="", encoding="utf-8") as csv_file:
            writer = csv.writer(csv_file)
            writer.writerows(self.grid)

        self.status.config(text=f"Saved CSV to {file_path}")


def main() -> None:
    root = tk.Tk()
    PixelGridApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
