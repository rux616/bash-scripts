#!/usr/bin/env bash

# This is a dumb sorter:
# - Sorts everything by section, including comments
# - Case insensitive sorting
# - Sections are deduped
# - Duplicates keys not checked for
# - Fully duplicate lines are deduped
# - Multi-line strings are not supported

set -eo pipefail
#set -x

function _decho() {
    ${debug} && >&2 printf -- "DEBUG: %s\n" "${@}"
    return 0
}

function _vecho() {
    ${verbose} && >&2 printf -- "INFO: %s\n" "${@}"
    return 0
}

# check for verbose or debugging flag
[[ $1 == --verbose ]] && { shift; verbose=true; } || verbose=false
[[ $1 == --debug ]] && { shift; debug=true; verbose=true; } || debug=false

# do some basic checks
[[ $# -ne 1 ]] && { printf "error: specify 1 file\n"; exit 1; }
[[ ! -e $1 ]] && { printf "error: file must exist\n"; exit 1; }

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
declare -a section_none
declare -n current_section="section_none"
declare -i section_counter=0
while IFS= read -r line || [[ -n ${line} ]]; do
    _vecho "line: ${line}"
    _decho "xxd line: $(printf -- "%s" "${line}" | xxd)"
    line="$(tr -d '\r\n' <<<"${line}")"
    if [[ ${line} =~ ^\[.+]$ ]]; then
        # create arrays for each section and store the reference to them
        section="$(tr -d '[]' <<<"${line}")"
        section="$(printf -- "%s\n" "${sections[@]}" "${section}" | LC_ALL=C sort -Vdfu | grep -ix "${section}")"
        _vecho "new section: ${section}"
        if [[ -z "${section_refs["${section}"]}" ]]; then
            sections+=( "${section}" )
            declare -a section_${section_counter}
            section_refs["${section}"]=${section_counter}
            section_counter+=1
        fi

        declare -n current_section="section_${section_refs["${section}"]}"
    else
        # if not a blank line, store it in the section's array
        if [[ -n ${line} ]]; then
            current_section+=( "${line}" )
        fi
    fi
done <"${1}"

# sort the sections alphabetically and without regard for case
readarray -t sections < <(printf "%s\n" "${sections[@]}" | LC_ALL=C sort -Vdfu)

{
    # print lines that have no section
    if [[ ${#section_none[@]} -gt 0 ]]; then
        printf "%s${line_ending}" "${section_none[@]}" | LC_ALL=C sort -t '=' -k '1,1' -Vdfu
        printf "%s" "${line_ending}"
    fi

    # print each section alphabetically
    for section in "${sections[@]}"; do
        declare -n current_section="section_${section_refs["${section}"]}"
        printf "[%s]${line_ending}" "${section}"
        printf "%s${line_ending}" "${current_section[@]}" | LC_ALL=C sort -t '=' -k '1,1' -Vdfu
        printf "${line_ending}"
    done
} | head -n -1 -
