# /// script
# requires-python = ">=3.11"
# dependencies = ["matplotlib>=3.10,<4"]
# [tool.ty.environment]
# root = ["."]
# ///
"""Measure indexed algorithms and plot reduction steps against the index."""

import argparse
from collections import defaultdict
from pathlib import Path, PurePosixPath

import matplotlib.pyplot as plt
from compare_common import (
    ROOT,
    Measurement,
    Probe,
    compile_example,
    decode,
    measure_algorithms,
    write_csv_rows,
)

DEFAULT_CSV = PurePosixPath("DIR/index-vs-steps.csv")
DEFAULT_PLOT = PurePosixPath("DIR/index-vs-steps.png")

FIELDS = ("method", "n", "steps", "value")
FIGURE_SIZE = (11, 7)


class Arguments(argparse.Namespace):
    directory: Path
    function: str
    decode: str
    max_index: int
    max_steps: int
    csv: Path
    plot: Path


def entry_source(source: Path, function: str, index: int) -> str:
    resolved = source.resolve()
    try:
        import_path = "./" + resolved.relative_to(ROOT).as_posix()
    except ValueError:
        import_path = resolved.as_posix()
    return f'@< "{import_path}" ({function}); @! {function} {index};'


def measure(
    directory: Path, function: str, mode: str, max_index: int, max_steps: int
) -> list[Measurement]:
    def prepare(source: Path, compiler: str, interpreter: str) -> Probe:
        def probe(index: int, limit: int) -> tuple[int, str] | None:
            context = f"{source} n={index}"
            graph = compile_example(
                compiler, entry_source(source, function, index), context
            )
            return decode(interpreter, graph, mode, limit, context)

        return probe

    return measure_algorithms(directory, max_index, max_steps, prepare)


def write_csv(path: Path, samples: list[Measurement]) -> None:
    write_csv_rows(
        path,
        FIELDS,
        (
            {
                "method": sample.method,
                "n": sample.index,
                "steps": sample.steps,
                "value": sample.value,
            }
            for sample in samples
        ),
    )


def plot(samples: list[Measurement], output: Path) -> None:
    grouped: dict[str, list[Measurement]] = defaultdict(list)
    for sample in samples:
        grouped[sample.method].append(sample)

    figure, axis = plt.subplots(figsize=FIGURE_SIZE)
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
        metavar="DIR",
        help="directory containing .lambda algorithms",
    )
    parser.add_argument(
        "--function",
        required=True,
        metavar="NAME",
        help="function exported by each algorithm",
    )
    parser.add_argument(
        "--decode",
        choices=("natural", "scott-natural", "integer", "rational", "boolean"),
        default="natural",
        metavar="MODE",
        help="interpreter decoding mode",
    )
    parser.add_argument(
        "--max-index",
        type=int,
        default=10,
        metavar=">=0",
        help="maximum reduction steps",
    )
    parser.add_argument(
        "--max-steps",
        type=int,
        default=1_000_000,
        metavar=">0",
        help="maximum index",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV,
        metavar="PATH",
        help="output CSV",
    )
    parser.add_argument(
        "--plot",
        type=Path,
        default=DEFAULT_PLOT,
        metavar="PATH",
        help="output PNG",
    )
    args = parser.parse_args(namespace=Arguments())
    if args.max_index < 0:
        parser.error("--max-index must be nonnegative")
    if args.max_steps <= 0:
        parser.error("--max-steps must be positive")
    if args.csv is DEFAULT_CSV:
        args.csv = args.directory / DEFAULT_CSV.name
    if args.plot is DEFAULT_PLOT:
        args.plot = args.directory / DEFAULT_PLOT.name
    return args


def main() -> None:
    args = parse_args()

    samples = measure(
        args.directory,
        args.function,
        args.decode,
        args.max_index,
        args.max_steps,
    )
    write_csv(args.csv, samples)
    plot(samples, args.plot)
    print(f"Saved {args.csv} and {args.plot}")


if __name__ == "__main__":
    main()
