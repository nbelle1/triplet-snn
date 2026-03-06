import random
from pathlib import Path


# User configuration
GRID_SIZE = 28
BIT_WIDTH = 6
OUTPUT_FILE = Path("weights.mem")


def generate_weight_grid(grid_size: int, bit_width: int) -> list[list[int]]:
    max_value = (1 << bit_width) - 1
    return [
        [random.randint(0, max_value) for _ in range(grid_size)]
        for _ in range(grid_size)
    ]


def write_weight_grid(output_file: Path, weights: list[list[int]], bit_width: int) -> None:
    with output_file.open("w", encoding="utf-8") as mem_file:
        for row in weights:
            for value in row:
                mem_file.write(f"{value:0{bit_width}b}\n")


def main() -> None:
    if GRID_SIZE <= 0:
        raise ValueError("GRID_SIZE must be greater than 0.")
    if BIT_WIDTH <= 0:
        raise ValueError("BIT_WIDTH must be greater than 0.")

    weights = generate_weight_grid(GRID_SIZE, BIT_WIDTH)
    write_weight_grid(OUTPUT_FILE, weights, BIT_WIDTH)
    print(
        f"Wrote a {GRID_SIZE}x{GRID_SIZE} grid of random {BIT_WIDTH}-bit weights to {OUTPUT_FILE}"
    )


if __name__ == "__main__":
    main()
