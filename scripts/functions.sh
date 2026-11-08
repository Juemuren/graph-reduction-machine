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
            -f | --file | -s | --source)
                input=("$1" "$2")
                shift 2
                ;;
            -t | --stage)
                stage=$2
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
                    --no-step-limit \
                    "--decode=$decode"
            ;;
    esac
)

_lambda_tool_completion() {
    local current=${COMP_WORDS[COMP_CWORD]}
    local previous=${COMP_WORDS[COMP_CWORD - 1]}
    local command=${COMP_WORDS[0]}
    local option_words='-f --file -s --source'
    local word

    if [[ $command != invoke_lambda_stage ]]; then
        for word in "${COMP_WORDS[@]:1:COMP_CWORD-1}"; do
            [[ $word == -- ]] && return
        done
        option_words+=' --'
    else
        option_words+=' -t --stage -e --encode -d --decode'
    fi

    case $previous in
        -f | --file)
            compopt -o filenames
            mapfile -t COMPREPLY < <(compgen -f -- "$current")
            return
            ;;
        -s | --source)
            return
            ;;
    esac

    if [[ $command == invoke_lambda_stage ]]; then
        case $previous in
            -t | --stage)
                mapfile -t COMPREPLY < <(compgen -W 'expand reduce compile interpret decode' -- "$current")
                return
                ;;
            -e | --encode)
                mapfile -t COMPREPLY < <(compgen -W 'church scott' -- "$current")
                return
                ;;
            -d | --decode)
                mapfile -t COMPREPLY < <(compgen -W 'natural scott-natural boolean integer rational real' -- "$current")
                return
                ;;
        esac
    fi

    mapfile -t COMPREPLY < <(compgen -W "$option_words" -- "$current")
}

complete -F _lambda_tool_completion invoke_compiler invoke_interpreter invoke_lambda_stage
