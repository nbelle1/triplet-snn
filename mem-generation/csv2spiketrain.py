import csv
from pathlib import Path


# User configuration
INPUT_FOLDER = Path("grids")
OUTPUT_FOLDER = Path("dataset")
PARAM_MEM = Path("param.mem")


def normalize_spike_train(train: str | list[int]) -> str:
    if isinstance(train, str):
        normalized = train.strip()
    else:
        normalized = "".join(str(bit) for bit in train)

    if any(bit not in {"0", "1"} for bit in normalized):
        raise ValueError("Spike trains must contain only binary values: 0 or 1.")

    return normalized


def load_pixel_trains(param_path: Path) -> tuple[str, str]:
    with param_path.open("r", encoding="utf-8") as param_file:
        lines = [
            line.strip()
            for line in param_file
            if line.strip()
            and not line.lstrip().startswith("#")
            and not line.lstrip().startswith("//")
        ]

    binary_lines = [line for line in lines if set(line) <= {"0", "1"}]

    if len(binary_lines) < 2:
        raise ValueError(
            f"{param_path} must contain at least two non-comment entries: black train then white train."
        )

    black_train = normalize_spike_train(binary_lines[0])
    white_train = normalize_spike_train(binary_lines[1])

    if len(black_train) != len(white_train):
        raise ValueError(
            f"Spike train length mismatch: black train has length {len(black_train)}, "
            f"white train has length {len(white_train)}."
        )

    return black_train, white_train


def load_pixels(csv_path: Path) -> list[int]:
    pixels: list[int] = []

    with csv_path.open("r", newline="", encoding="utf-8") as csv_file:
        reader = csv.reader(csv_file)
        for row_index, row in enumerate(reader, start=1):
            for col_index, value in enumerate(row, start=1):
                value = value.strip()
                if value not in {"0", "1"}:
                    raise ValueError(
                        f"Invalid pixel value at row {row_index}, column {col_index}: {value!r}"
                    )
                pixels.append(int(value))

    return pixels


def write_mem(mem_path: Path, spike_trains: list[str]) -> None:
    with mem_path.open("w", encoding="utf-8") as mem_file:
        for spike_train in spike_trains:
            mem_file.write(f"{spike_train}\n")


def main() -> None:
    black_train, white_train = load_pixel_trains(PARAM_MEM)
    OUTPUT_FOLDER.mkdir(exist_ok=True)

    input_csv_files = sorted(INPUT_FOLDER.glob("*.csv"))
    if not input_csv_files:
        raise FileNotFoundError(f"No CSV files found in {INPUT_FOLDER.resolve()}")

    for input_csv in input_csv_files:
        pixels = load_pixels(input_csv)
        spike_trains = [black_train if pixel == 1 else white_train for pixel in pixels]
        output_mem = OUTPUT_FOLDER / f"{input_csv.stem}.mem"

        write_mem(output_mem, spike_trains)
        print(
            f"Wrote {len(spike_trains)} spike trains of length {len(black_train)} "
            f"to {output_mem} using {PARAM_MEM}"
        )


if __name__ == "__main__":
    main()
