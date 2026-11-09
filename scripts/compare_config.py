# /// script
# requires-python = ">=3.11"
# dependencies = ["jsonschema>=4.23,<5"]
# [tool.ty.environment]
# root = ["."]
# ///
"""Shared JSON configuration and method setup for comparison scripts."""

import json
from collections.abc import Callable
from pathlib import Path
from typing import Literal, TypedDict, TypeVar

from compare_common import (
    MethodSpec,
    compile_example,
    decode,
    entry_source,
)
from jsonschema import validate


class Method(TypedDict):
    name: str
    file: str
    function: str
    encode: Literal["church", "scott"]
    decode: Literal["natural", "scott-natural", "integer", "rational", "boolean"]


Point = TypeVar("Point")


def load_config(path: Path, schema_path: Path) -> object:
    data: object = json.loads(path.read_text(encoding="utf-8"))
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    validate(data, schema)
    return data


def method_names(methods: list[Method], case_name: str) -> list[str]:
    names = [method["name"] for method in methods]
    if len(names) != len(set(names)):
        raise ValueError(f"{case_name}: duplicate method name")
    return names


def method_spec(
    method: Method,
    base: Path,
    compiler: str,
    interpreter: str,
    arguments: Callable[[Point], list[int]],
    label: Callable[[Point], str],
) -> MethodSpec[Point]:
    source = base / method["file"]

    def probe(point: Point, limit: int) -> tuple[int, str] | None:
        context = label(point)
        graph = compile_example(
            compiler,
            entry_source(source, method["function"], arguments(point)),
            context,
            method["encode"],
        )
        return decode(interpreter, graph, method["decode"], limit, context)

    return MethodSpec(method["name"], probe, label)
