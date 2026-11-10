# /// script
# requires-python = ">=3.11"
# dependencies = ["jsonschema>=4.23,<5"]
# [tool.ty.environment]
# root = ["."]
# ///
"""Shared JSON configuration and method setup for comparison scripts."""

import argparse
import json
from collections.abc import Callable, Sequence
from pathlib import Path
from typing import Literal, TypedDict, TypeVar

from compare_common import MethodSpec, compile_example, decode, entry_source
from jsonschema import validate


class MethodName(TypedDict):
    name: str


class Method(TypedDict):
    name: str
    file: str
    function: str
    encode: Literal["church", "scott"]
    decode: Literal["natural", "scott-natural", "integer", "rational", "boolean"]


Point = TypeVar("Point")
CaseType = TypeVar("CaseType", bound="CasePaths")
Sample = TypeVar("Sample")


class CasePaths(TypedDict):
    name: str
    csv: str
    png: str


class Arguments(argparse.Namespace):
    config: Path


def load_config(path: Path, schema_path: Path) -> object:
    """Load a JSON comparison config and validate it against its schema."""

    data: object = json.loads(path.read_text(encoding="utf-8"))
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    validate(data, schema)
    return data


def method_names(methods: Sequence[MethodName], case_name: str) -> list[str]:
    """Return method names in config order, rejecting duplicates within a case."""

    names = [method["name"] for method in methods]
    if len(names) != len(set(names)):
        raise ValueError(f"{case_name}: duplicate method name")
    return names


def parse_config_path(description: str) -> Path:
    """Parse the common configuration path argument."""

    parser = argparse.ArgumentParser(
        description=description,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "config",
        type=Path,
        metavar="PATH",
        help="comparison JSON file",
    )
    return parser.parse_args(namespace=Arguments()).config


def run_cases(
    cases: Sequence[CaseType],
    base: Path,
    *,
    names: Callable[[CaseType], list[str]],
    measure: Callable[[CaseType, Path], list[Sample]],
    write_csv: Callable[[Path, list[Sample]], None],
    plot: Callable[[CaseType, list[Sample], list[str], Path], None],
) -> None:
    """Run each case in order, leaving measurement and rendering to callers."""

    for case in cases:
        methods = names(case)
        samples = measure(case, base)
        csv_path = base / case["csv"]
        png_path = base / case["png"]
        write_csv(csv_path, samples)
        plot(case, samples, methods, png_path)
        print(f"Saved {csv_path} and {png_path}")


def method_spec(
    name: str,
    compiler: str,
    interpreter: str,
    source: str | Callable[[Point], str],
    decode_mode: str,
    label: Callable[[Point], str],
    *,
    encode: str | None = None,
    precision: Callable[[Point], int] | None = None,
    compile_context: str | None = None,
) -> MethodSpec[Point]:
    """Compile fixed source once, or generate and compile source for each input."""

    if isinstance(source, str):
        graph = compile_example(compiler, source, compile_context or name, encode)

        def graph_for(point: Point) -> str:
            return graph

    else:

        def graph_for(point: Point) -> str:
            return compile_example(compiler, source(point), label(point), encode)

    def probe(point: Point, limit: int) -> tuple[int, str] | None:
        context = label(point)
        return decode(
            interpreter,
            graph_for(point),
            decode_mode,
            limit,
            context,
            precision(point) if precision is not None else None,
        )

    return MethodSpec(name, probe, label)


def entry_method_spec(
    method: Method,
    base: Path,
    compiler: str,
    interpreter: str,
    arguments: Callable[[Point], list[int]],
    label: Callable[[str, Point], str],
) -> MethodSpec[Point]:
    """Build a method that compiles an imported function for each input."""

    name = method["name"]
    return method_spec(
        name,
        compiler,
        interpreter,
        lambda point: entry_source(
            base / method["file"], method["function"], arguments(point)
        ),
        method["decode"],
        lambda point: label(name, point),
        encode=method["encode"],
    )
