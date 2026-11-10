#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["jsonschema>=4.23,<5", "matplotlib>=3.10,<4"]
# [tool.ty.environment]
# root = ["."]
# ///
"""
Compare real-number algorithms from a JSON configuration and plot their accuracy.
"""

import argparse
from collections import defaultdict
from dataclasses import dataclass
from decimal import Decimal, localcontext
from fractions import Fraction
from pathlib import Path
from typing import TypedDict, cast

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
    write_csv_rows,
)
from compare_config import load_config, method_names
from matplotlib.axes import Axes

MIN_DECIMAL_PRECISION = 50
DECIMAL_GUARD_DIGITS = 20
DEFAULT_ZERO_ERROR_FLOOR = 1e-12

FIELDS = ("method", "n", "steps", "value", "abs_error")
FIGURE_SIZE = (11, 7)
POINT_ZORDER = 3
FRONTIER_ZORDER = 4


class Method(TypedDict):
    name: str
    file: str


class Case(TypedDict):
    name: str
    methods: list[Method]
    exactValue: str
    maxIndex: int
    maxSteps: int
    csv: str
    png: str


class Config(TypedDict):
    cases: list[Case]


def method_spec(
    method: Method, base: Path, compiler: str, interpreter: str, case_name: str
) -> MethodSpec[int]:
    source = base / method["file"]
    graph = compile_example(
        compiler,
        source.read_text(encoding="utf-8"),
        f"{case_name}/{method['name']}",
    )

    def probe(index: int, limit: int) -> tuple[int, str] | None:
        return decode(
            interpreter,
            graph,
            "real",
            limit,
            f"{case_name}/{method['name']} n={index}",
            index,
        )

    return MethodSpec(
        method["name"],
        probe,
        lambda index: f"{case_name}/{method['name']} n={index}",
    )


def measure_case(case: Case, base: Path) -> list[Measurement[int]]:
    compiler = executable(COMPILER)
    interpreter = executable(INTERPRETER)
    methods = (
        method_spec(method, base, compiler, interpreter, case["name"])
        for method in case["methods"]
    )
    results = measure_methods(
        methods,
        range(case["maxIndex"] + 1),
        case["maxSteps"],
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


def plot(samples: list[Sample], output: Path, title: str) -> None:
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
    axis.set_title(title)
    axis.grid(True, which="both", alpha=0.25)
    axis.legend()
    figure.tight_layout()
    output.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(output, dpi=180)
    plt.close(figure)


def run_config(path: Path) -> None:
    config = cast(Config, load_config(path, Path(__file__).with_suffix(".schema.json")))
    for case in config["cases"]:
        method_names(case["methods"], case["name"])
        samples = make_samples(
            measure_case(case, path.parent), Decimal(case["exactValue"])
        )
        csv_path = path.parent / case["csv"]
        png_path = path.parent / case["png"]
        write_csv(csv_path, samples)
        plot(samples, png_path, case["name"])
        print(f"Saved {csv_path} and {png_path}")


class Arguments(argparse.Namespace):
    config: Path


def parse_args() -> Arguments:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "config",
        type=Path,
        metavar="PATH",
        help="comparison JSON file",
    )
    args = parser.parse_args(namespace=Arguments())
    return args


def main() -> None:
    args = parse_args()

    run_config(args.config)


if __name__ == "__main__":
    main()
