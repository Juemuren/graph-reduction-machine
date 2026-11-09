#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["matplotlib>=3.10,<4"]
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

import matplotlib.pyplot as plt
from compare_common import (
    COMPILER,
    INTERPRETER,
    ROOT,
    compile_example,
    decode,
    executable,
    write_csv_rows,
)
from matplotlib.colors import SymLogNorm

FIGURE_SIZE = (11, 7)
ENCODINGS = {"church", "scott"}
DECODINGS = {"natural", "scott-natural", "integer", "rational", "boolean"}
INPUT_KINDS = {"diagonal", "fixed-m", "fixed-n", "grid"}

@dataclass(frozen=True)
class Sample:
    method: str
    m: int
    n: int
    steps: int | None
    value: str | None

def nonnegative(value: object, field: str) -> int:
    if type(value) is not int or value < 0:
        raise ValueError(f"{field} must be a nonnegative integer")
    return value


def positive(value: object, field: str) -> int:
    number = nonnegative(value, field)
    if number == 0:
        raise ValueError(f"{field} must be positive")
    return number


def input_pairs(spec: dict[str, object]) -> list[tuple[int, int]]:
    kind = spec.get("kind")
    if kind not in INPUT_KINDS:
        raise ValueError(f"input.kind must be one of {sorted(INPUT_KINDS)}")
    if kind == "grid":
        max_m = nonnegative(spec.get("maxM"), "input.maxM")
        max_n = nonnegative(spec.get("maxN"), "input.maxN")
        return [(m, n) for m in range(max_m + 1) for n in range(max_n + 1)]
    maximum = nonnegative(spec.get("maxIndex"), "input.maxIndex")
    if kind == "diagonal":
        return [(index, index) for index in range(maximum + 1)]
    fixed = nonnegative(spec.get("fixed"), "input.fixed")
    if kind == "fixed-m":
        return [(fixed, index) for index in range(maximum + 1)]
    return [(index, fixed) for index in range(maximum + 1)]


def entry_source_binary(source: Path, function: str, m: int, n: int) -> str:
    resolved = source.resolve()
    try:
        import_path = "./" + resolved.relative_to(ROOT).as_posix()
    except ValueError:
        import_path = resolved.as_posix()
    return f'@< "{import_path}" ({function}); @! {function} {m} {n};'


def measure_case(
    case: dict[str, object], base: Path, compiler: str, interpreter: str
) -> tuple[list[Sample], list[str]]:
    name = case.get("name")
    methods = case.get("methods")
    spec = case.get("input")
    if not isinstance(name, str) or not name:
        raise ValueError("case.name must be a nonempty string")
    if not isinstance(methods, list) or not methods:
        raise ValueError(f"{name}: methods must be a nonempty list")
    if not isinstance(spec, dict):
        raise TypeError(f"{name}: input must be an object")
    pairs = input_pairs(spec)
    max_steps = positive(case.get("maxSteps"), f"{name}.maxSteps")
    samples: list[Sample] = []
    method_names: list[str] = []
    for method in methods:
        if not isinstance(method, dict):
            raise TypeError(f"{name}: each method must be an object")
        method_name = method.get("name")
        file = method.get("file")
        function = method.get("function")
        encode = method.get("encode")
        mode = method.get("decode")
        if not all(
            isinstance(item, str) and item for item in (method_name, file, function)
        ):
            raise ValueError(f"{name}: method name, file and function must be strings")
        if method_name in method_names:
            raise ValueError(f"{name}: duplicate method {method_name}")
        if encode not in ENCODINGS or mode not in DECODINGS:
            raise ValueError(f"{name}/{method_name}: invalid encode or decode mode")
        method_names.append(method_name)
        source = base / file
        for m, n in pairs:
            context = f"{name}/{method_name} m={m} n={n}"
            graph = compile_example(
                compiler, entry_source_binary(source, function, m, n), context, encode
            )
            result = decode(interpreter, graph, mode, max_steps, context)
            if result is None:
                print(f"{context}: exceeded {max_steps} steps")
                samples.append(Sample(method_name, m, n, None, None))
            else:
                steps, value = result
                print(f"{context}: {steps} steps, {value}")
                samples.append(Sample(method_name, m, n, steps, value))
    values: dict[tuple[int, int], str] = {}
    for sample in samples:
        if sample.value is None:
            continue
        pair = (sample.m, sample.n)
        if pair in values and values[pair] != sample.value:
            raise ValueError(f"{name}: methods disagree at m={sample.m}, n={sample.n}")
        values[pair] = sample.value
    return samples, method_names


def write_config_csv(path: Path, samples: list[Sample]) -> None:
    write_csv_rows(
        path,
        ("method", "m", "n", "steps", "value", "status"),
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
    spec: dict[str, object],
    output: Path,
    title: str,
) -> None:
    grouped: dict[str, list[Sample]] = defaultdict(list)
    for sample in samples:
        grouped[sample.method].append(sample)
    kind = spec["kind"]
    if kind == "grid":
        max_m = nonnegative(spec["maxM"], "input.maxM")
        max_n = nonnegative(spec["maxN"], "input.maxN")
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
    if kind != "grid":
        figure.tight_layout()
    figure.savefig(output, dpi=180, bbox_inches="tight")
    plt.close(figure)


def run_config(path: Path) -> None:
    config = json.loads(path.read_text(encoding="utf-8"))
    cases = config.get("cases")
    if not isinstance(cases, list) or not cases:
        raise ValueError("cases must be a nonempty list")
    compiler = executable(COMPILER)
    interpreter = executable(INTERPRETER)
    names: set[str] = set()
    for case in cases:
        if not isinstance(case, dict):
            raise TypeError("each case must be an object")
        name = case.get("name")
        if name in names:
            raise ValueError(f"duplicate case {name}")
        samples, methods = measure_case(case, path.parent, compiler, interpreter)
        names.add(name)
        csv_name = case.get("csv")
        png_name = case.get("png")
        if (
            not isinstance(csv_name, str)
            or not csv_name
            or not isinstance(png_name, str)
            or not png_name
        ):
            raise ValueError(f"{name}: csv and png must be paths")
        csv_path = path.parent / csv_name
        png_path = path.parent / png_name
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
