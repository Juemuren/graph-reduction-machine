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

from collections import defaultdict
from pathlib import Path
from typing import TypeAlias, TypedDict, cast

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
from compare_config import (
    Method,
    entry_method_spec,
    load_config,
    method_names,
    parse_config_path,
    run_cases,
)

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
    compiler = executable(COMPILER)
    interpreter = executable(INTERPRETER)
    methods = (
        entry_method_spec(
            method,
            base,
            compiler,
            interpreter,
            lambda index: [index],
            lambda name, index: f"{case['name']}/{name} n={index}",
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
    run_cases(
        config["cases"],
        path.parent,
        names=lambda case: method_names(case["methods"], case["name"]),
        measure=measure_case,
        write_csv=write_csv,
        plot=lambda case, samples, methods, output: plot(
            samples, methods, output, case["name"]
        ),
    )


def main() -> None:
    run_config(parse_config_path(__doc__))


if __name__ == "__main__":
    main()
