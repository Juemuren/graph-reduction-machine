#!/usr/bin/env python3
"""
Align the label, category, and ::= columns in a BNFC grammar.
"""

import argparse
import difflib
import re
from pathlib import Path

RULE = re.compile(r"^([A-Za-z0-9_]+\.)\s+(\S+)\s+::=\s*(.*)$")


def align_grammar(source: str) -> str:
    lines = source.splitlines()
    rules = [RULE.match(line) for line in lines]
    label_width = max((len(rule[1]) for rule in rules if rule), default=0)
    category_width = max((len(rule[2]) for rule in rules if rule), default=0)

    aligned = [
        f"{rule[1]:<{label_width}} {rule[2]:<{category_width}} ::= {rule[3]}"
        if rule
        else line
        for line, rule in zip(lines, rules)
    ]
    return "\n".join(aligned) + ("\n" if lines else "")


def preview_grammar(grammar_file: Path, original: str, aligned: str) -> None:
    print(
        "".join(
            difflib.unified_diff(
                original.splitlines(keepends=True),
                aligned.splitlines(keepends=True),
                fromfile=str(grammar_file),
                tofile="aligned grammar",
            )
        ),
        end="",
    )


def confirm_write() -> bool:
    try:
        confirmed = input("Write aligned grammar? [y/N] ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        confirmed = ""
        print()
    if confirmed not in {"y", "yes"}:
        print("No changes written.")
        return False
    return True


def write_grammar(grammar_file: Path, aligned: str) -> None:
    with grammar_file.open("w", encoding="utf-8", newline="\n") as output:
        output.write(aligned)


class Args(argparse.Namespace):
    preview: bool
    grammar: Path


def parse_args() -> Args:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "-p",
        "--preview",
        action="store_true",
        help="preview diff before writing",
    )
    parser.add_argument(
        "-g",
        "--grammar",
        type=Path,
        help="grammar file to align",
    )
    args = parser.parse_args(namespace=Args())
    return args


def main() -> None:
    args = parse_args()
    original = args.grammar.read_text(encoding="utf-8")
    aligned = align_grammar(original)

    if original == aligned:
        print("BNFC grammar is already aligned")
        return
    if args.preview:
        preview_grammar(args.grammar, original, aligned)
        if not confirm_write():
            return

    write_grammar(args.grammar, aligned)
    print(f"Aligned {args.grammar}")


if __name__ == "__main__":
    main()
