#!/usr/bin/env bash

# Source this file to use invoke_compiler, invoke_interpreter and invoke_lambda_stage.

_lambda_tool() (
    local target=$1 file='' source='' input=stdin executable
    local -a options=()
    shift

    while (($#)); do
        case $1 in
            -f | --file)
                file=$2
                input='file'
                shift 2
                ;;
            -s | --source)
                source=$2
                input='source'
                shift 2
                ;;
            --)
                shift
                options=("$@")
                break
                ;;
            *)
                options+=("$1")
                shift
                ;;
        esac
    done

    executable=$(cabal list-bin "exe:$target")
    case $input in
        file)
            "$executable" "$file" "${options[@]}"
            ;;
        source)
            printf '%s\n' "$source" | "$executable" "${options[@]}"
            ;;
        stdin)
            "$executable" "${options[@]}"
            ;;
    esac
)

invoke_compiler() {
    _lambda_tool lambda-compiler "$@"
}

invoke_interpreter() {
    _lambda_tool ski-interpreter "$@"
}

invoke_lambda_stage() (
    local stage='' encode=church decode=natural
    local -a input=()

    while (($#)); do
        case $1 in
            -t | --stage)
                stage=$2
                shift 2
                ;;
            -f | --file | -s | --source)
                input=("$1" "$2")
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
                shift
                ;;
        esac
    done

    if [[ -t 1 ]]; then
        printf '\033[1;96m%s\033[0m\n' "${stage^}"
    else
        printf '%s\n' "${stage^}"
    fi

    case $stage in
        expand)
            invoke_compiler "${input[@]}" -- \
                "--encode=$encode" \
                --stop-after=expand
            ;;
        reduce)
            invoke_compiler "${input[@]}" -- \
                "--encode=$encode" \
                --stop-after=reduce \
                --enable-reduce=both
            ;;
        compile)
            invoke_compiler "${input[@]}" -- \
                "--encode=$encode" |
                tr -d '\r' |
                paste -sd '\t' -
            ;;
        interpret)
            invoke_compiler "${input[@]}" -- \
                "--encode=$encode" |
                invoke_interpreter -- \
                    --show-steps |
                tr -d '\r' |
                paste -sd '\t' -
            ;;
        decode)
            invoke_compiler "${input[@]}" -- \
                "--encode=$encode" |
                invoke_interpreter -- \
                    --show-steps \
                    "--decode=$decode"
            ;;
    esac
)
