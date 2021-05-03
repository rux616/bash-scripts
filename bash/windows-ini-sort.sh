#!/usr/bin/env bash

# This is a dumb sorter:
# - Sorts everything by section, including comments
# - Case insensitive
# - Duplicates not checked for

set -eo pipefail
#set -x

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

# get all the sections in the file
sections_txt="$(grep -E '^\[.*]'$'\r''{0,1}$' "${1}" | tr -d '[]\r' | LC_ALL=C sort -dfV )"
readarray -t sections < <(echo "${sections_txt}")

# create arrays for each section and store the reference to them
declare -a section_none
for (( i=0; i<${#sections[@]}; i++)); do
    declare -a section_${i}
    section_refs["${sections[$i]}"]="${i}"
done

# read the file, each line into the array for its section
declare -n current_section="section_none"
while IFS= read -r line; do
    if grep -Eq '^\[.*]'$'\r''${0,1}$' <<<"${line}"; then
        section="$(grep -E '^\[.*]'$'\r''{0,1}$' <<<"${line}" | tr -d '[]\r')"
        declare -n current_section="section_${section_refs["${section}"]}"
    else
        if [[ -n $(tr -d '\r\n' <<<"${line}") ]]; then
            current_section+=( "${line}" )
        fi
    fi
done <"${1}"

# print lines that have no section
if [[ ${#section_none[@]} -gt 0 ]]; then
    printf "%s\n" "${section_none[@]}" | LC_ALL=C sort -t '=' -k '1,1' -dfV
    printf "%s" "${line_ending}"
fi

# print each section alphabetically
for section in "${sections[@]}"; do
    declare -n current_section="section_${section_refs["${section}"]}"
    printf "[%s]%s" "${section}" "${line_ending}"
    printf "%s\n" "${current_section[@]}" | LC_ALL=C sort -t '=' -k '1,1' -dfV
    printf "%s" "${line_ending}"
done
