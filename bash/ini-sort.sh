#!/usr/bin/env bash

# This is a dumb sorter:
# - Case insensitive sorting
# - Comments are also sorted
# - Sections themselves get sorted and deduped
# - Section contents get sorted and deduped (last value overrides)
# - Extra blank lines are stripped
# - Multi-line values are not supported

set -eo pipefail
#set -x

declare -ir ll_quiet=0 ll_error=1 ll_warning=2 ll_normal=3 ll_verbose=4 ll_debug=5
function _eecho() {
    if [[ $1 -le $verbosity ]]; then
        case $1 in
            ${ll_error})   >&2 printf -- "%bERROR%b: " "${c_error}" "${c_end}"       ;;
            ${ll_warning}) >&2 printf -- "%bWARNING%b: " "${c_warning}" "${c_end}"   ;;
            ${ll_normal})  [[ $verbosity -gt $ll_verbose ]] && >&2 printf -- "INFO: ";;
            ${ll_verbose}) [[ $verbosity -gt $ll_verbose ]] && >&2 printf -- "INFO: ";;
            ${ll_debug})   >&2 printf -- "DEBUG: "   ;;
        esac
        shift
        >&2 printf -- "%s\n" "${@}"
    fi
    return 0
}

function _usage() {
    _eecho $ll_normal "Usage: $(basename "${0}") [OPTION] FILE [FILE]..."
    _eecho $ll_normal "Write sorted combination of all FILE(s) to standard output."
    _eecho $ll_normal ""
    _eecho $ll_normal "Options:"
    _eecho $ll_normal "  -q, --quiet    don't output any errors or messages"
    _eecho $ll_normal "  -e, --error    only output errors"
    _eecho $ll_normal "  -w, --warning  only output errors and warnings"
    _eecho $ll_normal "  -v, --verbose  output detailed info as the file is being processed"
    _eecho $ll_normal "  -d, --debug    output debug info as the file is being processed"
    _eecho $ll_normal "  -h, --help     display this help and exit"
    _eecho $ll_normal ""
    _eecho $ll_normal "If duplicate key are found within a section, the last value overrides."
    return 0
}

# set up colors
[[ -t 2 ]] && c_error="\e[1;31m"   || c_error=""
[[ -t 2 ]] && c_warning="\e[1;33m" || c_warning=""
[[ -t 2 ]] && c_end="\e[0m"        || c_end=""

# check for verbose or debugging flag
declare -i verbosity=$ll_normal
[[ $1 == "--quiet" || $1 == "-q" ]] && { shift; verbosity=$ll_quiet; }
[[ $1 == "--error" || $1 == "-e" ]] && { shift; verbosity=$ll_error; }
[[ $1 == "--warning" || $1 == "-w" ]] && { shift; verbosity=$ll_warning; }
[[ $1 == "--verbose" || $1 == "-v" ]] && { shift; verbosity=$ll_verbose; }
[[ $1 == "--debug" || $1 == "-d" ]] && { shift; verbosity=$ll_debug; }
[[ $1 == "--help" || $1 == "-h" ]] && { shift; _usage; exit 0; }

# do some basic checks
[[ $# -lt 1 ]] && { _eecho $ll_error "at least one file must be specified"; _usage; exit 1; }
for file in "${@}"; do
    [[ ! -r ${file} ]] && { _eecho $ll_error "cannot read: ${1}"; exit 1; }
done

# declare variables
declare -A section_refs
declare -a sections

# determine if the file is using windows line endings (\r\n) or unix line endings (\n)
if grep -q $'\r''$' "$1"; then
    line_ending=$'\r'$'\n'
else
    line_ending=$'\n'
fi

# read the file
declare -A section_none
declare -a section_none_comments \
           section_none_keys
declare -i section_counter=0
while [[ $# -gt 0 ]]; do
    [[ ! -r $1 ]] && { _eecho $ll_warning "can't read \"${1}\", skipping..."; shift; continue; }
    _eecho $ll_normal "reading ${1}..."
    declare -n current_section="section_none" \
               current_section_comments="section_none_comments" \
               current_section_keys="section_none_keys"
    declare -i line_counter=1
    while IFS= read -r line || [[ -n ${line} ]]; do
        _eecho $ll_debug "line ${line_counter} raw: ${line}"
        _eecho $ll_debug "line ${line_counter} xxd: $(printf -- "%s" "${line}" | xxd)"
        line="$(tr -d '\r\n' <<<"${line}")"
        if [[ ${line} =~ ^\[.+]$ ]]; then
            # line designates a section
            _eecho $ll_debug "line ${line_counter} type: section (${section})"
            section="${line#[}"
            section="${section%]}"
            section="$(printf -- "%s\n" "${sections[@]}" "${section}" | LC_ALL=C sort -Vdfu | grep -ix "${section}")"
            _eecho $ll_verbose "section: ${section}"
            if [[ -z "${section_refs["${section}"]}" ]]; then
                # create arrays for each section and store the reference to them
                sections+=( "${section}" )
                declare -A section_${section_counter}
                declare -a section_${section_counter}_comments \
                           section_${section_counter}_keys
                section_refs["${section}"]=${section_counter}
                section_counter+=1
            fi

            declare -n current_section="section_${section_refs["${section}"]}" \
                       current_section_comments="section_${section_refs["${section}"]}_comments" \
                       current_section_keys="section_${section_refs["${section}"]}_keys"
        elif [[ ${line} =~ ^\; ]]; then
            # line is a comment
            _eecho $ll_debug "line ${line_counter} type: comment (${line})"
            current_section_comments+=( "${line}" )
        elif [[ ${line} =~ = ]]; then
            # line is a key/value pair
            key="${line%%=*}"
            key="$(printf -- "%s\n" "${current_section_keys[@]}" "${key}" | LC_ALL=C sort -Vdfu | grep -ix "${key}")"
            value="${line#*=}"
            _eecho $ll_debug "line ${line_counter} type: key/value pair (${key} = ${value})"
            # if the key doesn't exist in this section, add it to the list
            if [[ -z ${current_section["${key}"]+empty} ]]; then
                current_section_keys+=( "${key}" )
            fi
            current_section["${key}"]="${value}"
        elif [[ -z ${line} ]]; then
            # line is an empty line
            _eecho $ll_debug "line ${line_counter} type: blank"
        else
            # line is of an unknown type; treat as a comment for sorting purposes
            _eecho $ll_warning "line ${line_counter} type: unknown (section: ${section:-"<none>"} / line: ${line})"
            current_section_comments+=( "${line}" )
        fi
        line_counter+=1
    done <"${1}"
    shift
done

# sort the sections
_eecho $ll_normal "sorting..."
{
    # print lines that have no section
    {
        if [[ ${#section_none_keys[@]} -gt 0 ]]; then
            _eecho $ll_verbose "section: <none>"
            for key in "${section_none_keys[@]}"; do
                _eecho $ll_debug "key: ${key}"
                _eecho $ll_debug "value: ${current_section["${key}"]}"
                printf "%s=%s${line_ending}" "${key}" "${section_none["${key}"]}"
            done
        fi
        if [[ ${#section_none_comments[@]} -gt 0 ]]; then
            printf "%s${line_ending}" "${section_none_comments[@]}"
        fi
    } | LC_ALL=C sort -t '=' -k '1,1' -Vdf
    if [[ ${#section_none_keys[@]} -gt 0 || ${#section_none_comments[@]} -gt 0 ]]; then
        printf "${line_ending}"
    fi

    # print each section alphabetically
    if [[ ${#sections[@]} -gt 0 ]]; then
        readarray -t sections < <(printf "%s\n" "${sections[@]}" | LC_ALL=C sort -Vdf)
        _eecho $ll_debug "${#sections[@]} sections"
        for section in "${sections[@]}"; do
            _eecho $ll_verbose "section: ${section}"
            declare -n current_section="section_${section_refs["${section}"]}" \
                       current_section_comments="section_${section_refs["${section}"]}_comments" \
                       current_section_keys="section_${section_refs["${section}"]}_keys"
            printf "[%s]${line_ending}" "${section}"
            {
                if [[ ${#current_section_keys[@]} -gt 0 ]]; then
                    for key in "${current_section_keys[@]}"; do
                        _eecho $ll_debug "key: ${key}"
                        _eecho $ll_debug "value: ${current_section["${key}"]}"
                        printf "%s=%s${line_ending}" "${key}" "${current_section["${key}"]}"
                    done
                fi
                if [[ ${#current_section_comments[@]} -gt 0 ]]; then
                    printf "%s${line_ending}" "${current_section_comments[@]}"
                fi
            } | LC_ALL=C sort -t '=' -k '1,1' -Vdf
            printf "${line_ending}"
        done
    fi
} | head -n -1 -
