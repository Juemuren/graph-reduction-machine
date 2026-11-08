#!/usr/bin/env python3
"""
Align the label, category, and ::= columns in the CoreLambda grammar.
"""

import argparse
import difflib
import os
import re
import stat
import tempfile
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


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-p", "--preview", action="store_true")
    args = parser.parse_args()

    project_dir = Path(__file__).resolve().parent.parent
    grammar_file = project_dir / "grammar" / "CoreLambda.cf"
    original = grammar_file.read_text(encoding="utf-8")
    aligned = align_grammar(original)

    if original == aligned:
        print("BNFC grammar is already aligned.")
        return

    if args.preview:
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
        try:
            confirmed = input("Write aligned grammar? [y/N] ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            confirmed = ""
            print()
        if confirmed not in {"y", "yes"}:
            print("No changes written.")
            return

    temp_dir = project_dir / ".tmp"
    temp_dir.mkdir(exist_ok=True)
    candidate: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="\n",
            prefix="align-bnfc.",
            dir=temp_dir,
            delete=False,
        ) as temp_file:
            candidate = Path(temp_file.name)
            temp_file.write(aligned)
        os.chmod(candidate, stat.S_IMODE(grammar_file.stat().st_mode))
        os.replace(candidate, grammar_file)
        candidate = None
    finally:
        if candidate is not None:
            candidate.unlink(missing_ok=True)

    print(f"Aligned {grammar_file}")


if __name__ == "__main__":
    main()
