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

import argparse
import json
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Literal, TypeAlias, TypedDict, cast

import matplotlib.pyplot as plt
from compare_common import (
    COMPILER,
    INTERPRETER,
    ROOT,
    MethodSpec,
    check_agreement,
    compile_example,
    decode,
    executable,
    measure_methods,
    write_csv_rows,
)
from jsonschema import validate
from matplotlib.colors import SymLogNorm

FIELDS = ("method", "m", "n", "steps", "value", "status")
FIGURE_SIZE = (11, 7)


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


class Method(TypedDict):
    name: str
    file: str
    function: str
    encode: Literal["church", "scott"]
    decode: Literal["natural", "scott-natural", "integer", "rational", "boolean"]


class Case(TypedDict):
    name: str
    methods: list[Method]
    input: Input
    maxSteps: int
    csv: str
    png: str


class Config(TypedDict):
    cases: list[Case]


@dataclass(frozen=True)
class Sample:
    method: str
    m: int
    n: int
    steps: int | None
    value: str | None


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


def entry_source_binary(source: Path, function: str, m: int, n: int) -> str:
    resolved = source.resolve()
    try:
        import_path = "./" + resolved.relative_to(ROOT).as_posix()
    except ValueError:
        import_path = resolved.as_posix()
    return f'@< "{import_path}" ({function}); @! {function} {m} {n};'


def method_spec(
    method: Method, base: Path, case_name: str, compiler: str, interpreter: str
) -> MethodSpec[tuple[int, int]]:
    source = base / method["file"]
    method_name = method["name"]

    def probe(pair: tuple[int, int], limit: int) -> tuple[int, str] | None:
        m, n = pair
        context = f"{case_name}/{method_name} m={m} n={n}"
        graph = compile_example(
            compiler,
            entry_source_binary(source, method["function"], m, n),
            context,
            method["encode"],
        )
        return decode(interpreter, graph, method["decode"], limit, context)

    def label(pair: tuple[int, int]) -> str:
        m, n = pair
        return f"{case_name}/{method_name} m={m} n={n}"

    return MethodSpec(method_name, probe, label)


def measure_case(
    case: Case, base: Path, compiler: str, interpreter: str
) -> tuple[list[Sample], list[str]]:
    name = case["name"]
    pairs = input_pairs(case["input"])
    max_steps = case["maxSteps"]
    method_names: list[str] = []
    for method in case["methods"]:
        method_name = method["name"]
        if method_name in method_names:
            raise ValueError(f"{name}: duplicate method {method_name}")
        method_names.append(method_name)
    methods = (
        method_spec(method, base, name, compiler, interpreter)
        for method in case["methods"]
    )
    results = measure_methods(methods, pairs, max_steps, on_limit="record")
    check_agreement(results, name, lambda pair: f"m={pair[0]}, n={pair[1]}")
    samples = [
        Sample(result.method, *result.input, result.steps, result.value)
        for result in results
    ]
    return samples, method_names


def write_config_csv(path: Path, samples: list[Sample]) -> None:
    write_csv_rows(
        path,
        FIELDS,
        (
            (
                sample.method,
                sample.m,
                sample.n,
                sample.steps if sample.steps is not None else "",
                sample.value if sample.value is not None else "",
                "ok" if sample.steps is not None else "limit",
            )
            for sample in samples
        ),
    )


def plot_case(
    samples: list[Sample],
    method_names: list[str],
    spec: Input,
    output: Path,
    title: str,
) -> None:
    grouped: dict[str, list[Sample]] = defaultdict(list)
    for sample in samples:
        grouped[sample.method].append(sample)
    if spec["kind"] == "grid":
        max_m = spec["maxM"]
        max_n = spec["maxN"]
        successful = [sample.steps for sample in samples if sample.steps is not None]
        if not successful:
            raise ValueError(f"{title}: no successful measurements")
        figure, axes = plt.subplots(
            1,
            len(method_names),
            figsize=(max(6, 5 * len(method_names)), 5),
            sharex=True,
            sharey=True,
            squeeze=False,
        )
        color_map = plt.get_cmap("viridis").copy()
        color_map.set_bad("lightgray")
        norm = SymLogNorm(linthresh=1, vmin=0, vmax=max(1, max(successful)))
        for axis, method in zip(axes[0], method_names):
            grid = [[float("nan") for _ in range(max_n + 1)] for _ in range(max_m + 1)]
            for sample in grouped[method]:
                if sample.steps is not None:
                    grid[sample.m][sample.n] = sample.steps
            image = axis.imshow(
                grid, origin="lower", cmap=color_map, norm=norm, aspect="auto"
            )
            axis.set(title=method, xlabel="n", ylabel="m")
        figure.colorbar(image, ax=axes[0].tolist(), label="Reduction steps")
        figure.suptitle(title)
    else:
        kind = spec["kind"]
        if not any(sample.steps is not None for sample in samples):
            raise ValueError(f"{title}: no successful measurements")
        figure, axis = plt.subplots(figsize=FIGURE_SIZE)
        for method in method_names:
            points = [
                point
                for point in grouped[method]
                if point.steps is not None and point.steps > 0
            ]
            if points:
                axis.plot(
                    [point.m if kind == "fixed-n" else point.n for point in points],
                    [point.steps for point in points],
                    marker="o",
                    label=method,
                )
        axis.set(
            yscale="log",
            xlabel="m" if kind == "fixed-n" else "n",
            ylabel="Reduction steps",
            title=title,
        )
        axis.grid(True, which="both", alpha=0.25)
        axis.legend()
    output.parent.mkdir(parents=True, exist_ok=True)
    if spec["kind"] != "grid":
        figure.tight_layout()
    figure.savefig(output, dpi=180, bbox_inches="tight")
    plt.close(figure)


def run_config(path: Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    schema_path = Path(__file__).with_suffix(".schema.json")
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    validate(data, schema)
    config = cast(Config, data)
    compiler = executable(COMPILER)
    interpreter = executable(INTERPRETER)
    names: set[str] = set()
    for case in config["cases"]:
        name = case["name"]
        if name in names:
            raise ValueError(f"duplicate case {name}")
        samples, methods = measure_case(case, path.parent, compiler, interpreter)
        names.add(name)
        csv_path = path.parent / case["csv"]
        png_path = path.parent / case["png"]
        write_config_csv(csv_path, samples)
        plot_case(samples, methods, case["input"], png_path, name)
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
        metavar="NAME",
        help="comparison JSON file",
    )
    args = parser.parse_args(namespace=Arguments())
    return args


def main() -> None:
    args = parse_args()
    run_config(args.config)


if __name__ == "__main__":
    main()
