#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["jsonschema>=4.23,<5", "matplotlib>=3.10,<4"]
# [tool.ty.environment]
# root = ["."]
# ///
"""
Compare binary algorithms from a JSON configuration and plot reduction steps.
"""

from collections import defaultdict
from pathlib import Path
from typing import Literal, TypeAlias, TypedDict, cast

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
from matplotlib.colors import SymLogNorm
from matplotlib.figure import Figure

FIELDS = ("method", "m", "n", "steps", "value", "status")
LINE_FIGURE_SIZE = (11, 7)
GRID_MIN_WIDTH = 6
GRID_WIDTH_PER_METHOD = 5
GRID_HEIGHT = 5


class DiagonalInput(TypedDict):
    kind: Literal["diagonal"]
    maxIndex: int


class FixedInput(TypedDict):
    kind: Literal["fixed-m", "fixed-n"]
    fixed: int
    maxIndex: int


class GridInput(TypedDict):
    kind: Literal["grid"]
    maxM: int
    maxN: int


Input: TypeAlias = DiagonalInput | FixedInput | GridInput


class Case(TypedDict):
    name: str
    methods: list[Method]
    input: Input
    maxSteps: int
    csv: str
    png: str


class Config(TypedDict):
    cases: list[Case]


Sample: TypeAlias = Measurement[tuple[int, int]]


def input_pairs(spec: Input) -> list[tuple[int, int]]:
    match spec["kind"]:
        case "grid":
            return [
                (m, n) for m in range(spec["maxM"] + 1) for n in range(spec["maxN"] + 1)
            ]
        case "diagonal":
            return [(index, index) for index in range(spec["maxIndex"] + 1)]
        case "fixed-m":
            return [(spec["fixed"], index) for index in range(spec["maxIndex"] + 1)]
        case "fixed-n":
            return [(index, spec["fixed"]) for index in range(spec["maxIndex"] + 1)]


def measure_case(case: Case, base: Path) -> list[Sample]:
    name = case["name"]
    compiler = executable(COMPILER)
    interpreter = executable(INTERPRETER)
    methods = (
        entry_method_spec(
            method,
            base,
            compiler,
            interpreter,
            lambda pair: [pair[0], pair[1]],
            lambda method_name, pair: f"{name}/{method_name} m={pair[0]} n={pair[1]}",
        )
        for method in case["methods"]
    )
    results = measure_methods(
        methods,
        input_pairs(case["input"]),
        case["maxSteps"],
        on_limit="record",
    )
    check_agreement(results, name, lambda pair: f"m={pair[0]}, n={pair[1]}")
    return results


def write_csv(path: Path, samples: list[Sample]) -> None:
    write_csv_rows(
        path,
        FIELDS,
        (
            (
                sample.method,
                sample.input[0],
                sample.input[1],
                sample.steps if sample.steps is not None else "",
                sample.value if sample.value is not None else "",
                "ok" if sample.steps is not None else "limit",
            )
            for sample in samples
        ),
    )


def plot_grid(
    grouped: dict[str, list[Sample]],
    method_names: list[str],
    spec: GridInput,
    max_steps: int,
    title: str,
) -> Figure:
    figure, axes = plt.subplots(
        1,
        len(method_names),
        figsize=(
            max(GRID_MIN_WIDTH, GRID_WIDTH_PER_METHOD * len(method_names)),
            GRID_HEIGHT,
        ),
        sharex=True,
        sharey=True,
        squeeze=False,
    )
    color_map = plt.get_cmap("viridis").copy()
    color_map.set_bad("lightgray")
    norm = SymLogNorm(linthresh=1, vmin=0, vmax=max(1, max_steps))
    for axis, method in zip(axes[0], method_names):
        grid = [
            [float("nan") for _ in range(spec["maxN"] + 1)]
            for _ in range(spec["maxM"] + 1)
        ]
        for sample in grouped[method]:
            if sample.steps is not None:
                grid[sample.input[0]][sample.input[1]] = sample.steps
        image = axis.imshow(
            grid,
            origin="lower",
            cmap=color_map,
            norm=norm,
            aspect="auto",
        )
        axis.set(title=method, xlabel="n", ylabel="m")
    figure.colorbar(
        image,
        ax=axes[0].tolist(),
        label="Reduction steps",
    )
    figure.suptitle(title)
    return figure


def plot_lines(
    grouped: dict[str, list[Sample]],
    method_names: list[str],
    spec: DiagonalInput | FixedInput,
    title: str,
) -> Figure:
    figure, axis = plt.subplots(figsize=LINE_FIGURE_SIZE)

    for method in method_names:
        points = [
            point
            for point in grouped[method]
            if point.steps is not None and point.steps > 0
        ]
        if points:
            match spec["kind"]:
                case "diagonal":
                    x_values = [point.input[0] for point in points]
                case "fixed-m":
                    x_values = [point.input[1] for point in points]
                case "fixed-n":
                    x_values = [point.input[0] for point in points]
            axis.plot(
                x_values,
                [point.steps for point in points],
                marker="o",
                label=method,
            )
    match spec["kind"]:
        case "diagonal":
            x_label = "m = n"
        case "fixed-m":
            x_label = "n"
        case "fixed-n":
            x_label = "m"
    axis.set(
        yscale="log",
        xlabel=x_label,
        ylabel="Reduction steps",
        title=title,
    )
    axis.grid(True, which="both", alpha=0.25)
    axis.legend()
    figure.tight_layout()
    return figure


def plot(
    samples: list[Sample],
    method_names: list[str],
    spec: Input,
    output: Path,
    title: str,
) -> None:
    successful = [sample.steps for sample in samples if sample.steps is not None]
    if not successful:
        raise ValueError(f"{title}: no successful measurements")
    grouped: dict[str, list[Sample]] = defaultdict(list)
    for sample in samples:
        grouped[sample.method].append(sample)

    if spec["kind"] == "grid":
        figure = plot_grid(grouped, method_names, spec, max(successful), title)
    else:
        figure = plot_lines(grouped, method_names, spec, title)
    output.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(output, dpi=180, bbox_inches="tight")
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
            samples, methods, case["input"], output, case["name"]
        ),
    )


def main() -> None:
    run_config(parse_config_path(__doc__))


if __name__ == "__main__":
    main()
