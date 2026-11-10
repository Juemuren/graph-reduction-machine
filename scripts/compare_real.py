#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["matplotlib>=3.10,<4"]
# [tool.ty.environment]
# root = ["."]
# ///
"""
Measure real-number examples and plot their accuracy against reduction steps.
"""

import argparse
from collections import defaultdict
from dataclasses import dataclass
from decimal import Decimal, localcontext
from fractions import Fraction
from pathlib import Path, PurePosixPath

import matplotlib.pyplot as plt
from compare_common import (
    COMPILER,
    INTERPRETER,
    Measurement,
    MethodSpec,
    compile_example,
    decode,
    executable,
    measure_methods,
    sources_in,
    write_csv_rows,
)
from matplotlib.axes import Axes

DEFAULT_CSV = PurePosixPath("DIR/steps-vs-error.csv")
DEFAULT_PLOT = PurePosixPath("DIR/steps-vs-error.png")

MIN_DECIMAL_PRECISION = 50
DECIMAL_GUARD_DIGITS = 20
DEFAULT_ZERO_ERROR_FLOOR = 1e-12

FIELDS = ("method", "n", "steps", "value", "abs_error")
FIGURE_SIZE = (11, 7)
POINT_ZORDER = 3
FRONTIER_ZORDER = 4


def method_spec(source: Path, compiler: str, interpreter: str) -> MethodSpec[int]:
    graph = compile_example(
        compiler,
        source.read_text(encoding="utf-8"),
        str(source),
    )

    def probe(index: int, limit: int) -> tuple[int, str] | None:
        return decode(
            interpreter,
            graph,
            "real",
            limit,
            f"{source} n={index}",
            index,
        )

    return MethodSpec(
        source.stem,
        probe,
        lambda index: f"{source.stem} n={index}",
    )


def measure(directory: Path, max_index: int, max_steps: int) -> list[Measurement[int]]:
    compiler = executable(COMPILER)
    interpreter = executable(INTERPRETER)
    methods = (
        method_spec(source, compiler, interpreter) for source in sources_in(directory)
    )
    results = measure_methods(
        methods,
        range(max_index + 1),
        max_steps,
        on_limit="stop",
    )
    samples = [
        result
        for result in results
        if result.steps is not None and result.value is not None
    ]
    if not samples:
        raise ValueError("no successful measurements")
    return samples


@dataclass(frozen=True)
class Sample:
    method: str
    index: int
    steps: int
    value: str
    error: Decimal


def make_samples(measurements: list[Measurement[int]], exact: Decimal) -> list[Sample]:
    samples = []
    for measurement in measurements:
        if measurement.steps is None or measurement.value is None:
            continue
        value = Fraction(measurement.value)
        with localcontext() as context:
            context.prec = max(
                MIN_DECIMAL_PRECISION,
                len(exact.as_tuple().digits) + DECIMAL_GUARD_DIGITS,
            )
            approximation = Decimal(value.numerator) / Decimal(value.denominator)
            error = abs(approximation - exact)
        samples.append(
            Sample(
                measurement.method,
                measurement.input,
                measurement.steps,
                measurement.value,
                error,
            )
        )
    return samples


def write_csv(path: Path, samples: list[Sample]) -> None:
    write_csv_rows(
        path,
        FIELDS,
        (
            (
                sample.method,
                sample.index,
                sample.steps,
                sample.value,
                str(sample.error),
            )
            for sample in samples
        ),
    )


def pareto_frontier(samples: list[Sample]) -> list[Sample]:
    frontier = []
    best_error = Decimal("Infinity")
    for sample in sorted(samples, key=lambda item: (item.steps, item.error)):
        if sample.error < best_error:
            frontier.append(sample)
            best_error = sample.error
    return frontier


def plot_coordinates(
    points: list[Sample], zero_floor: float
) -> tuple[list[int], list[float]]:
    steps = [point.steps for point in points]
    errors = [float(point.error) if point.error > 0 else zero_floor for point in points]
    return steps, errors


def plot_scatter(axis: Axes, samples: list[Sample], zero_floor: float) -> None:
    grouped: dict[str, list[Sample]] = defaultdict(list)
    for sample in samples:
        grouped[sample.method].append(sample)

    colors = plt.get_cmap("tab10")
    for number, (method, points) in enumerate(sorted(grouped.items())):
        points = sorted(points, key=lambda item: item.index)
        steps, errors = plot_coordinates(points, zero_floor)
        color = colors(number % 10)
        axis.plot(
            steps,
            errors,
            color=color,
            alpha=0.65,
            linewidth=1.5,
        )
        axis.scatter(
            steps,
            errors,
            color=color,
            s=55,
            label=method,
            zorder=POINT_ZORDER,
        )
        for point, error in zip(points, errors):
            axis.annotate(
                f"n={point.index}",
                (point.steps, error),
                xytext=(5, 5),
                textcoords="offset points",
            )


def plot_pareto_frontier(axis: Axes, samples: list[Sample], zero_floor: float) -> None:
    frontier_steps, frontier_errors = plot_coordinates(
        pareto_frontier(samples), zero_floor
    )
    axis.plot(
        frontier_steps,
        frontier_errors,
        color="black",
        linestyle="--",
        linewidth=2,
        marker="x",
        markersize=8,
        label="Pareto frontier",
        zorder=FRONTIER_ZORDER,
    )


def plot(samples: list[Sample], output: Path) -> None:
    positive_errors = [float(sample.error) for sample in samples if sample.error > 0]
    zero_floor = (
        min(positive_errors) / 10 if positive_errors else DEFAULT_ZERO_ERROR_FLOOR
    )

    figure, axis = plt.subplots(figsize=FIGURE_SIZE)
    plot_scatter(axis, samples, zero_floor)
    plot_pareto_frontier(axis, samples, zero_floor)
    axis.set(
        xscale="log",
        yscale="log",
        xlabel="Reduction steps",
        ylabel="Absolute error",
    )
    axis.set_title("Real-number approximation: steps vs error")
    axis.grid(True, which="both", alpha=0.25)
    axis.legend()
    figure.tight_layout()
    output.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(output, dpi=180)
    plt.close(figure)


class Arguments(argparse.Namespace):
    directory: Path
    exact_value: Decimal
    max_steps: int
    max_index: int
    csv: Path
    plot: Path


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
        "--exact-value",
        required=True,
        type=Decimal,
        metavar="NUM",
        help="exact value of a real number",
    )
    parser.add_argument(
        "--max-steps",
        type=int,
        default=1_000_000,
        metavar=">0",
        help="maximum reduction steps",
    )
    parser.add_argument(
        "--max-index",
        type=int,
        default=10,
        metavar=">=0",
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
    if args.max_steps <= 0:
        parser.error("--max-steps must be positive")
    if args.max_index < 0:
        parser.error("--max-index must be nonnegative")
    if args.csv is DEFAULT_CSV:
        args.csv = args.directory / DEFAULT_CSV.name
    if args.plot is DEFAULT_PLOT:
        args.plot = args.directory / DEFAULT_PLOT.name
    return args


def main() -> None:
    args = parse_args()

    samples = make_samples(
        measure(
            args.directory,
            args.max_index,
            args.max_steps,
        ),
        args.exact_value,
    )
    write_csv(args.csv, samples)
    plot(samples, args.plot)
    print(f"Saved {args.csv} and {args.plot}")


if __name__ == "__main__":
    main()
