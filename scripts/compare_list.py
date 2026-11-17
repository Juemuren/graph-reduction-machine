#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["jsonschema>=4.23,<5", "matplotlib>=3.10,<4"]
# [tool.ty.environment]
# root = ["."]
# ///
"""Compare Church and Scott list operations over increasing list lengths."""

import re
from collections import defaultdict
from pathlib import Path
from random import Random
from typing import Literal, TypeAlias, TypedDict, cast

import matplotlib.pyplot as plt
from compare_common import (
    COMPILER,
    INTERPRETER,
    ROOT,
    Measurement,
    check_agreement,
    executable,
    measure_methods,
    write_csv_rows,
)
from compare_config import (
    load_config,
    method_names,
    method_spec,
    parse_config_path,
    run_cases,
)

Encoding = Literal["church", "scott"]
FIELDS = ("method", "length", "steps", "value", "status")
PLACEHOLDER = re.compile(r"\{([A-Za-z][A-Za-z0-9]*)\}")


class Method(TypedDict):
    name: str
    file: str
    function: str
    encoding: Encoding
    decode: str


class CyclicGenerator(TypedDict):
    kind: Literal["ascending-cycle", "descending-cycle"]
    min: int
    max: int


class ConstantGenerator(TypedDict):
    kind: Literal["constant"]
    value: int


class RandomGenerator(TypedDict):
    kind: Literal["random"]
    min: int
    max: int
    seed: int


Generator: TypeAlias = CyclicGenerator | ConstantGenerator | RandomGenerator


class Case(TypedDict):
    name: str
    expression: str
    generator: Generator
    methods: list[Method]
    maxLength: int
    maxSteps: int
    csv: str
    png: str


class Config(TypedDict):
    cases: list[Case]


Sample: TypeAlias = Measurement[int]


def values_for(generator: Generator, length: int) -> list[int]:
    match generator["kind"]:
        case "ascending-cycle":
            width = generator["max"] - generator["min"] + 1
            return [generator["min"] + index % width for index in range(length)]
        case "descending-cycle":
            width = generator["max"] - generator["min"] + 1
            return [generator["max"] - index % width for index in range(length)]
        case "constant":
            return [generator["value"]] * length
        case "random":
            rng = Random(generator["seed"])
            return [
                rng.randint(generator["min"], generator["max"]) for _ in range(length)
            ]


def source_for(method: Method, case: Case, length: int, base: Path) -> str:
    path = (base / method["file"]).resolve().relative_to(ROOT).as_posix()
    values = values_for(case["generator"], length)
    encoded_list = "nil"
    for value in reversed(values):
        encoded_list = f"(cons {value} {encoded_list})"
    middle_index = length // 2 if length else 0
    substitutions = {
        "function": method["function"],
        "list": encoded_list,
        "length": str(length),
        "first": str(values[0] if values else 0),
        "middle": str(values[middle_index] if values else 0),
        "last": str(values[-1] if values else 0),
        "firstIndex": "0",
        "middleIndex": str(middle_index),
        "lastIndex": str(length - 1 if length else 0),
    }

    def replace(match: re.Match[str]) -> str:
        name = match.group(1)
        try:
            return substitutions[name]
        except KeyError as error:
            raise ValueError(
                f"{case['name']}: unknown placeholder {{{name}}}"
            ) from error

    expression = PLACEHOLDER.sub(replace, case["expression"])
    function = method["function"]
    return f'@< "./{path}" (nil, cons, {function}); @! {expression};'


def measure_case(case: Case, base: Path) -> list[Sample]:
    generator = case["generator"]
    if generator["kind"] != "constant" and generator["min"] > generator["max"]:
        raise ValueError(f"{case['name']}: generator min exceeds max")
    if {method["encoding"] for method in case["methods"]} != {"church", "scott"}:
        raise ValueError(f"{case['name']}: expected Church and Scott methods")
    compiler = executable(COMPILER)
    interpreter = executable(INTERPRETER)
    methods = [
        method_spec(
            method["name"],
            compiler,
            interpreter,
            lambda length, method=method: source_for(method, case, length, base),
            method["decode"],
            lambda length, name=method["name"]: (
                f"{case['name']}/{name} length={length}"
            ),
            encode="binary",
        )
        for method in case["methods"]
    ]
    results = measure_methods(
        methods, range(case["maxLength"] + 1), case["maxSteps"], on_limit="record"
    )
    check_agreement(results, case["name"], lambda length: f"length={length}")
    if not any(result.steps is not None for result in results):
        raise ValueError(f"{case['name']}: no successful measurements")
    return results


def write_csv(path: Path, samples: list[Sample]) -> None:
    write_csv_rows(
        path,
        FIELDS,
        (
            (
                sample.method,
                sample.input,
                sample.steps if sample.steps is not None else "",
                sample.value if sample.value is not None else "",
                "ok" if sample.steps is not None else "limit",
            )
            for sample in samples
        ),
    )


def plot(case: Case, samples: list[Sample], names: list[str], output: Path) -> None:
    grouped: dict[str, list[Sample]] = defaultdict(list)
    for sample in samples:
        grouped[sample.method].append(sample)

    figure, axis = plt.subplots(figsize=(10, 6))
    for name in names:
        points = grouped[name]
        axis.plot(
            [point.input for point in points],
            [
                point.steps if point.steps is not None else float("nan")
                for point in points
            ],
            marker="o",
            label=name,
        )
    axis.set(
        yscale="log",
        xlabel="Length",
        ylabel="Reduction steps",
        title=case["name"],
    )
    axis.grid(True, which="both", alpha=0.25)
    axis.legend()
    figure.tight_layout()
    output.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(output, dpi=180)
    plt.close(figure)


def main() -> None:
    path = parse_config_path(__doc__)
    config = cast(Config, load_config(path, Path(__file__).with_suffix(".schema.json")))
    run_cases(
        config["cases"],
        path.parent,
        names=lambda case: method_names(case["methods"], case["name"]),
        measure=measure_case,
        write_csv=write_csv,
        plot=lambda case, samples, names, output: plot(case, samples, names, output),
    )


if __name__ == "__main__":
    main()
