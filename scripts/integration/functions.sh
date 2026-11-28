#!/usr/bin/env bash

# Source this file to use the compiler, interpreter and integration functions.

_grm_tool() (
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
    _grm_tool lambda-compiler "$@"
}

invoke_interpreter() {
    _grm_tool ski-interpreter "$@"
}

invoke_integration_stage() (
    local stage='' encode_natural=church encode_string='church<binary>' decode=natural
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
            -en | --encode-natural)
                encode_natural=$2
                shift 2
                ;;
            -es | --encode-string)
                encode_string=$2
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
                "--encode-natural=$encode_natural" \
                "--encode-string=$encode_string" \
                --stop-after=expand
            ;;
        reduce)
            invoke_compiler "${input[@]}" -- \
                "--encode-natural=$encode_natural" \
                "--encode-string=$encode_string" \
                --stop-after=reduce \
                --reduce=both
            ;;
        compile)
            invoke_compiler "${input[@]}" -- \
                "--encode-natural=$encode_natural" "--encode-string=$encode_string" |
                tr -d '\r' |
                paste -sd '\t' -
            ;;
        interpret)
            invoke_compiler "${input[@]}" -- \
                "--encode-natural=$encode_natural" "--encode-string=$encode_string" |
                invoke_interpreter -- \
                    --show-steps |
                tr -d '\r' |
                paste -sd '\t' -
            ;;
        decode)
            invoke_compiler "${input[@]}" -- \
                "--encode-natural=$encode_natural" "--encode-string=$encode_string" |
                invoke_interpreter -- \
                    --show-steps \
                    --max-steps=infty \
                    "--decode=$decode"
            ;;
    esac
)

invoke_integration_sequence() (
    local file='' source='' input_kind='' stages=decode encode_natural=church encode_string='church<binary>' decode=natural stage selected
    local -a input=() selected_stages=()

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
            -en | --encode-natural)
                encode_natural=$2
                shift 2
                ;;
            -es | --encode-string)
                encode_string=$2
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
        file) input=(--file "$file") ;;
        source) input=(--source "$source") ;;
        *)
            source=$(cat)
            input=(--source "$source")
            ;;
    esac

    IFS=, read -r -a selected_stages <<< "$stages"
    for stage in expand reduce compile interpret decode; do
        for selected in "${selected_stages[@]}"; do
            if [[ $selected == "$stage" ]]; then
                invoke_integration_stage "${input[@]}" \
                    --stage "$stage" \
                    --encode-natural "$encode_natural" \
                    --encode-string "$encode_string" \
                    --decode "$decode"
                break
            fi
        done
    done
)

_grm_stage_completions() {
    local current=$1 multiple=$2 prefix='' fragment=$1 index
    if [[ $multiple == yes && $current == *,* ]]; then
        prefix=${current%,*},
        fragment=${current##*,}
    fi

    mapfile -t COMPREPLY < <(compgen -W 'expand reduce compile interpret decode' -- "$fragment")
    for index in "${!COMPREPLY[@]}"; do
        COMPREPLY[index]="$prefix${COMPREPLY[index]}"
    done
}

_grm_encode_natural_completions() {
    mapfile -t COMPREPLY < <(compgen -W 'church scott binary' -- "$1")
}

_grm_encode_string_completions() {
    mapfile -t COMPREPLY < <(compgen -W 'church<church> church<scott> church<binary> scott<church> scott<scott> scott<binary>' -- "$1")
}

_grm_decode_completions() {
    local rest=$1 prefix='' expected='type' candidate top
    local -a stack=()
    local -a types=(natural scott-natural binary-natural boolean integer rational real real:0 string 'list<' 'scott-list<' 'pair<')

    while IFS= read -r candidate; do
        types+=("string:$candidate")
    done < <(_grm_encode_string_completions ""; printf '%s\n' "${COMPREPLY[@]}")

    while [[ -n $rest ]]; do
        if [[ $expected == type ]]; then
            case $rest in
                list\<* | scott-list\<*)
                    stack+=(list)
                    candidate="${rest%%<*}<"
                    prefix+=$candidate
                    rest=${rest#"$candidate"}
                    ;;
                pair\<*)
                    stack+=(pair-first)
                    prefix+='pair<'
                    rest=${rest#pair<}
                    ;;
                *)
                    if [[ $rest =~ ^(natural|scott-natural|binary-natural|boolean|integer|rational|string|real(:[0-9]+)?|string:(church|scott)\<(church|scott|binary)\>)([,\>]|$) ]]; then
                        candidate=${BASH_REMATCH[1]}
                        prefix+=$candidate
                        rest=${rest#"$candidate"}
                        expected=after
                    else
                        break
                    fi
                    ;;
            esac
        else
            ((${#stack[@]} > 0)) || break
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
        for candidate in "${types[@]}"; do
            [[ $candidate == "$rest"* ]] && COMPREPLY+=("$prefix$candidate")
        done
    elif [[ -z $rest ]]; then
        if [[ $prefix == *real ]]; then
            COMPREPLY+=("$prefix:0")
        fi
        if [[ $prefix == *string ]]; then
            for candidate in "${types[@]}"; do
                [[ $candidate == string:* ]] && COMPREPLY+=("${prefix%string}$candidate")
            done
        fi
        ((${#stack[@]} > 0)) || return 0
        top=${stack[${#stack[@]} - 1]-}
        case $top in
            list | pair-second) COMPREPLY+=("$prefix>") ;;
            pair-first) COMPREPLY+=("$prefix,") ;;
        esac
    fi
}

_grm_option_completions() {
    local command=$1 current=$2 value index
    COMPREPLY=()

    case $command:$current in
        invoke_compiler:--encode-natural=*)
            value=${current#--encode-natural=}
            _grm_encode_natural_completions "$value"
            for index in "${!COMPREPLY[@]}"; do
                COMPREPLY[index]="--encode-natural=${COMPREPLY[index]}"
            done
            ;;
        invoke_compiler:--encode-string=*)
            value=${current#--encode-string=}
            _grm_encode_string_completions "$value"
            for index in "${!COMPREPLY[@]}"; do
                COMPREPLY[index]="--encode-string=${COMPREPLY[index]}"
            done
            ;;
        invoke_interpreter:--decode=*)
            _grm_decode_completions "${current#--decode=}"
            for index in "${!COMPREPLY[@]}"; do
                COMPREPLY[index]="--decode=${COMPREPLY[index]}"
            done
            ;;
    esac

    compopt -o nospace
}

_grm_decode_word_completions() {
    local value=$1 quote=${1:0:1} index
    if [[ $quote == "'" || $quote == '"' ]]; then
        value=${value#"$quote"}
        value=${value%"$quote"}
        _grm_decode_completions "$value"
        for index in "${!COMPREPLY[@]}"; do
            COMPREPLY[index]="$quote${COMPREPLY[index]}$quote"
        done
        compopt -o nospace
    else
        _grm_decode_completions "${value//\\/}"
        compopt -o nospace -o filenames
    fi
}

_grm_tool_completion() {
    local current=${COMP_WORDS[COMP_CWORD]}
    local previous=${COMP_WORDS[COMP_CWORD - 1]}
    local command=${COMP_WORDS[0]}
    local option_words='-f --file -s --source'
    local word

    case $command in
        invoke_integration_stage)
            option_words+=' -t --stage -en --encode-natural -es --encode-string -d --decode'
            ;;
        invoke_integration_sequence)
            option_words+=' -t --stages -en --encode-natural -es --encode-string -d --decode'
            ;;
        *)
            for word in "${COMP_WORDS[@]:1:COMP_CWORD-1}"; do
                if [[ $word == -- ]]; then
                    if [[ $command == invoke_interpreter && $previous == = &&
                          ${COMP_WORDS[COMP_CWORD - 2]} == --decode ]]; then
                        _grm_decode_word_completions "$current"
                        return
                    fi
                    _grm_option_completions "$command" "$current"
                    return
                fi
            done
            option_words+=' --'
            ;;
    esac

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

    if [[ $command == invoke_integration_stage || $command == invoke_integration_sequence ]]; then
        case $previous in
            -t | --stage | --stages)
                if [[ $command == invoke_integration_sequence ]]; then
                    _grm_stage_completions "$current" yes
                else
                    _grm_stage_completions "$current" no
                fi
                return
                ;;
            -en | --encode-natural)
                _grm_encode_natural_completions "$current"
                return
                ;;
            -es | --encode-string)
                _grm_encode_string_completions "$current"
                compopt -o nospace
                return
                ;;
            -d | --decode)
                _grm_decode_word_completions "$current"
                return
                ;;
        esac
    fi

    mapfile -t COMPREPLY < <(compgen -W "$option_words" -- "$current")
}

complete -F _grm_tool_completion invoke_compiler invoke_interpreter invoke_integration_stage invoke_integration_sequence
