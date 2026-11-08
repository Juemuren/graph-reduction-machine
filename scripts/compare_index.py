# /// script
# requires-python = ">=3.11"
# dependencies = ["matplotlib>=3.10,<4"]
# ///
"""Measure indexed algorithms and plot reduction steps against the index."""

import argparse
import csv
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

import matplotlib.pyplot as plt
from compare_common import (
    COMPILER,
    INTERPRETER,
    ROOT,
    compile_example,
    decode,
    executable,
    sources_in,
)

FIELDS = ("method", "n", "steps", "value")
FUNCTION_PATTERN = re.compile(r"^[a-z][A-Za-z0-9_]*$")


@dataclass(frozen=True)
class Sample:
    method: str
    index: int
    steps: int
    value: str


class Arguments(argparse.Namespace):
    directory: Path
    function: str
    decode: str
    max_index: int
    max_steps: int
    csv: Path | None
    plot: Path | None


def entry_source(source: Path, function: str, index: int) -> str:
    resolved = source.resolve()
    try:
        import_path = "./" + resolved.relative_to(ROOT).as_posix()
    except ValueError:
        import_path = resolved.as_posix()
    return f'@< "{import_path}" ({function}); @! {function} {index};'


def measure(
    directory: Path, function: str, mode: str, max_index: int, max_steps: int
) -> list[Sample]:
    sources = sources_in(directory)
    compiler = executable(COMPILER)
    interpreter = executable(INTERPRETER)
    samples = []
    for source in sources:
        for index in range(max_index + 1):
            context = f"{source} n={index}"
            graph = compile_example(
                compiler, entry_source(source, function, index), context
            )
            result = decode(interpreter, graph, mode, max_steps, context)
            if result is None:
                print(f"{source.stem} n={index}: exceeded {max_steps} steps")
                break
            steps, value = result
            print(f"{source.stem} n={index}: {steps} steps, {value}")
            samples.append(Sample(source.stem, index, steps, value))
    if not samples:
        raise ValueError("no successful measurements")
    return samples


def write_csv(path: Path, samples: list[Sample]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(
            {
                "method": sample.method,
                "n": sample.index,
                "steps": sample.steps,
                "value": sample.value,
            }
            for sample in samples
        )


def plot(samples: list[Sample], output: Path) -> None:
    grouped: dict[str, list[Sample]] = defaultdict(list)
    for sample in samples:
        grouped[sample.method].append(sample)

    figure, axis = plt.subplots(figsize=(11, 7))
    for method, points in sorted(grouped.items()):
        positive = [point for point in points if point.steps > 0]
        if positive:
            axis.plot(
                [point.index for point in positive],
                [point.steps for point in positive],
                marker="o",
                label=method,
            )
    axis.set(
        yscale="log",
        xlabel="Index",
        ylabel="Reduction steps",
        title="Indexed algorithms: index vs reduction steps",
    )
    axis.grid(True, which="both", alpha=0.25)
    axis.legend()
    figure.tight_layout()
    output.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(output, dpi=180)
    plt.close(figure)


def parse_args() -> Arguments:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "directory",
        type=Path,
        help="directory containing .lambda algorithms",
    )
    parser.add_argument(
        "--function",
        required=True,
        help="function exported by each algorithm",
    )
    parser.add_argument(
        "--decode",
        choices=("natural", "scott-natural", "integer", "rational", "boolean"),
        default="natural",
        help="interpreter decoding mode",
    )
    parser.add_argument(
        "--max-index",
        type=int,
        default=10,
        metavar=">=0",
    )
    parser.add_argument(
        "--max-steps",
        type=int,
        default=1_000_000,
        metavar=">0",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        metavar="PATH",
        help="output CSV",
    )
    parser.add_argument(
        "--plot",
        type=Path,
        metavar="PATH",
        help="output PNG",
    )
    args = parser.parse_args(namespace=Arguments())
    if not FUNCTION_PATTERN.fullmatch(args.function):
        parser.error("--function must be a source-language name")
    if args.max_index < 0:
        parser.error("--max-index must be nonnegative")
    if args.max_steps <= 0:
        parser.error("--max-steps must be positive")
    if args.csv is None:
        args.csv = args.directory / "index-vs-steps.csv"
    if args.plot is None:
        args.plot = args.directory / "index-vs-steps.png"
    return args


def main() -> None:
    args = parse_args()
    assert args.csv is not None and args.plot is not None
    samples = measure(
        args.directory, args.function, args.decode, args.max_index, args.max_steps
    )
    write_csv(args.csv, samples)
    plot(samples, args.plot)
    print(f"Saved {args.csv} and {args.plot}")


if __name__ == "__main__":
    main()
