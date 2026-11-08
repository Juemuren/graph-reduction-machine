#!/usr/bin/env bash

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/functions.sh
source "$script_dir/functions.sh"

file='' source='' stages=decode encode=church decode=natural input_kind=''
while (($#)); do
    case $1 in
        -f | --file)
            file=$2
            input_kind='file'
            shift 2
            ;;
        -s | --source)
            source=$2
            input_kind='source'
            shift 2
            ;;
        -t | --stages)
            stages=$2
            shift 2
            ;;
        -e | --encode)
            encode=$2
            shift 2
            ;;
        -d | --decode)
            decode=$2
            shift 2
            ;;
        *)
            file=$1
            input_kind='file'
            shift
            ;;
    esac
done

case $input_kind in
    file)
        source_args=(--file "$file")
        ;;
    source)
        source_args=(--source "$source")
        ;;
    *)
        source=$(cat)
        source_args=(--source "$source")
        ;;
esac

IFS=, read -r -a selected_stages <<< "$stages"
for stage in expand reduce compile interpret decode; do
    for selected in "${selected_stages[@]}"; do
        if [[ $selected == "$stage" ]]; then
            invoke_lambda_stage "${source_args[@]}" \
                --stage "$stage" \
                --encode "$encode" \
                --decode "$decode"
            break
        fi
    done
done
