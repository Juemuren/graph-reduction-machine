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
from typing import TypedDict, cast

import matplotlib.pyplot as plt
from compare_common import (
    COMPILER,
    INTERPRETER,
    Measurement,
    check_agreement,
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


def measure_case(case: Case, base: Path) -> list[Measurement]:
    method_names(case["methods"], case["name"])
    methods = (
        method_spec(
            method,
            base,
            executable(COMPILER),
            executable(INTERPRETER),
            lambda index: [index],
            lambda index, name=method["name"]: f"{case['name']}/{name} n={index}",
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
        Measurement(result.method, result.input, result.steps, result.value)
        for result in results
        if result.steps is not None and result.value is not None
    ]
    if not samples:
        raise ValueError("no successful measurements")
    return samples


def write_csv(path: Path, samples: list[Measurement]) -> None:
    write_csv_rows(
        path,
        FIELDS,
        (
            (
                sample.method,
                sample.index,
                sample.steps,
                sample.value,
            )
            for sample in samples
        ),
    )


def plot(samples: list[Measurement], output: Path, title: str) -> None:
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
        samples = measure_case(case, path.parent)
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
