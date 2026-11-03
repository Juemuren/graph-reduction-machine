#!/bin/sh

set -eu

usage() {
    printf 'Usage: sh scripts/align-bnfc.sh [-p|--preview]\n' >&2
    exit 2
}

if [ "$#" -gt 1 ]; then
    usage
fi

case "${1-}" in
    '') preview=false ;;
    -p | --preview) preview=true ;;
    *) usage ;;
esac

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH='' cd -- "$script_dir/.." && pwd)
grammar_file=$project_dir/grammar/ArithmeticLambda.cf

mkdir -p "$project_dir/.tmp"
candidate=$(mktemp "$project_dir/.tmp/align-bnfc.XXXXXX")
trap 'rm -f "$candidate"' 0 HUP INT TERM

cp -p "$grammar_file" "$candidate"
awk -f "$script_dir/align-bnfc.awk" "$grammar_file" > "$candidate"

if cmp -s "$grammar_file" "$candidate"; then
    printf 'BNFC grammar is already aligned.\n'
    exit 0
fi

if [ "$preview" = true ]; then
    delta --paging=always "$grammar_file" "$candidate" || [ "$?" -eq 1 ]
    if ! gum confirm 'Write aligned grammar?'; then
        printf 'No changes written.\n'
        exit 0
    fi
fi

mv -f "$candidate" "$grammar_file"
printf 'Aligned %s\n' "$grammar_file"
