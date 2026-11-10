#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["jsonschema>=4.23,<5", "matplotlib>=3.10,<4"]
# [tool.ty.environment]
# root = ["."]
# ///
"""
Measure indexed algorithms and plot reduction steps against the index.
"""

import argparse
from collections import defaultdict
from pathlib import Path
from typing import TypeAlias, TypedDict, cast

import matplotlib.pyplot as plt
from compare_common import (
    COMPILER,
    INTERPRETER,
    Measurement,
    check_agreement,
    entry_source,
    executable,
    measure_methods,
    write_csv_rows,
)
from compare_config import Method, load_config, method_names, method_spec

FIELDS = ("method", "n", "steps", "value")
FIGURE_SIZE = (11, 7)


class Case(TypedDict):
    name: str
    methods: list[Method]
    maxIndex: int
    maxSteps: int
    csv: str
    png: str


class Config(TypedDict):
    cases: list[Case]


Sample: TypeAlias = Measurement[int]


def measure_case(case: Case, base: Path) -> list[Sample]:
    methods = (
        method_spec(
            method["name"],
            executable(COMPILER),
            executable(INTERPRETER),
            lambda index, method=method: entry_source(
                base / method["file"], method["function"], [index]
            ),
            method["decode"],
            lambda index, name=method["name"]: f"{case['name']}/{name} n={index}",
            encode=method["encode"],
        )
        for method in case["methods"]
    )
    results = measure_methods(
        methods,
        range(case["maxIndex"] + 1),
        case["maxSteps"],
        on_limit="stop",
    )
    check_agreement(results, case["name"], lambda index: f"n={index}")
    samples = [
        result
        for result in results
        if result.steps is not None and result.value is not None
    ]
    if not samples:
        raise ValueError("no successful measurements")
    return samples


def write_csv(path: Path, samples: list[Sample]) -> None:
    write_csv_rows(
        path,
        FIELDS,
        (
            (
                sample.method,
                sample.input,
                sample.steps,
                sample.value,
            )
            for sample in samples
            if sample.steps is not None and sample.value is not None
        ),
    )


def plot(
    samples: list[Sample], method_names: list[str], output: Path, title: str
) -> None:
    grouped: dict[str, list[Sample]] = defaultdict(list)
    for sample in samples:
        grouped[sample.method].append(sample)

    figure, axis = plt.subplots(figsize=FIGURE_SIZE)
    for method in method_names:
        points = [
            point
            for point in grouped[method]
            if point.steps is not None and point.steps > 0
        ]
        if points:
            axis.plot(
                [point.input for point in points],
                [point.steps for point in points],
                marker="o",
                label=method,
            )
    axis.set(
        yscale="log",
        xlabel="Index",
        ylabel="Reduction steps",
        title=title,
    )
    axis.grid(True, which="both", alpha=0.25)
    axis.legend()
    figure.tight_layout()
    output.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(output, dpi=180)
    plt.close(figure)


def run_config(path: Path) -> None:
    config = cast(Config, load_config(path, Path(__file__).with_suffix(".schema.json")))
    for case in config["cases"]:
        methods = method_names(case["methods"], case["name"])
        samples = measure_case(case, path.parent)
        csv_path = path.parent / case["csv"]
        png_path = path.parent / case["png"]
        write_csv(csv_path, samples)
        plot(samples, methods, png_path, case["name"])
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
