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

_lambda_encode_completions() {
    mapfile -t COMPREPLY < <(compgen -W 'church scott binary' -- "$1")
}

_lambda_decode_completions() {
    local rest=$1 prefix='' expected='type' candidate top
    local -a stack=()
    local -a types=(natural scott-natural binary-natural boolean integer rational string 'list<' 'pair<')

    while [[ -n $rest ]]; do
        if [[ $expected == type ]]; then
            case $rest in
                list\<*)
                    stack+=(list)
                    prefix+='list<'
                    rest=${rest#list<}
                    ;;
                pair\<*)
                    stack+=(pair-first)
                    prefix+='pair<'
                    rest=${rest#pair<}
                    ;;
                *)
                    if [[ $rest =~ ^(natural|scott-natural|binary-natural|boolean|integer|rational|string|real)([,\>]|$) ]]; then
                        candidate=${BASH_REMATCH[1]}
                        [[ $candidate == real && ${#stack[@]} -gt 0 ]] && break
                        prefix+=$candidate
                        rest=${rest#"$candidate"}
                        expected=after
                    else
                        break
                    fi
                    ;;
            esac
        else
            top=${stack[${#stack[@]} - 1]-}
            case $top:$rest in
                pair-first:,*)
                    stack[${#stack[@]} - 1]=pair-second
                    prefix+=,
                    rest=${rest#,}
                    expected='type'
                    ;;
                list:\>* | pair-second:\>*)
                    unset 'stack[${#stack[@]}-1]'
                    prefix+='>'
                    rest=${rest#>}
                    ;;
                *) break ;;
            esac
        fi
    done

    COMPREPLY=()
    if [[ $expected == type ]]; then
        if ((${#stack[@]} == 0)); then
            types+=(real)
        fi
        for candidate in "${types[@]}"; do
            [[ $candidate == "$rest"* ]] && COMPREPLY+=("$prefix$candidate")
        done
    elif [[ -z $rest ]]; then
        top=${stack[${#stack[@]} - 1]-}
        case $top in
            list | pair-second) COMPREPLY+=("$prefix>") ;;
            pair-first) COMPREPLY+=("$prefix,") ;;
        esac
    fi
}

_lambda_option_completions() {
    local command=$1 current=$2 value index
    COMPREPLY=()

    case $command:$current in
        invoke_compiler:--encode=*)
            value=${current#--encode=}
            _lambda_encode_completions "$value"
            for index in "${!COMPREPLY[@]}"; do
                COMPREPLY[index]="--encode=${COMPREPLY[index]}"
            done
            ;;
        invoke_interpreter:--decode=*)
            _lambda_decode_completions "${current#--decode=}"
            for index in "${!COMPREPLY[@]}"; do
                COMPREPLY[index]="--decode=${COMPREPLY[index]}"
            done
            ;;
    esac

    compopt -o nospace
}

_lambda_tool_completion() {
    local current=${COMP_WORDS[COMP_CWORD]}
    local previous=${COMP_WORDS[COMP_CWORD - 1]}
    local command=${COMP_WORDS[0]}
    local option_words='-f --file -s --source'
    local word

    if [[ $command != invoke_lambda_stage ]]; then
        for word in "${COMP_WORDS[@]:1:COMP_CWORD-1}"; do
            if [[ $word == -- ]]; then
                _lambda_option_completions "$command" "$current"
                return
            fi
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
                _lambda_encode_completions "$current"
                return
                ;;
            -d | --decode)
                _lambda_decode_completions "$current"
                compopt -o nospace
                return
                ;;
        esac
    fi

    mapfile -t COMPREPLY < <(compgen -W "$option_words" -- "$current")
}

complete -F _lambda_tool_completion invoke_compiler invoke_interpreter invoke_lambda_stage
