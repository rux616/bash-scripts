#!/usr/bin/env bash

# yet another color test script

TC='\e['
CLR_LINE_START="${TC}1K"
CLR_LINE_END="${TC}K"
CLR_LINE="${TC}2K"
RESET_LINE="${CLR_LINE}${TC}1000D"
RST="${TC}0m"

declare -A style fgcolor ifgcolor bgcolor ibgcolor
styles=( dim reg bol und bli inv )
style[bol]="${TC}1m"
style[und]="${TC}4m"
style[bli]="${TC}5m"
style[inv]="${TC}7m"
style[reg]="${TC}22;24;25m"
style[dim]="${TC}2m"

colors=( bk rd gr ye bl mg cy wh )
declare -i fgi=30 ifgi=90 bgi=40 ibgi=100
for ((clr_idx=0; clr_idx<${#colors[@]}; clr_idx++)); do
    fgcolor[${colors[$clr_idx]}]="${TC}${fgi}m";    ((fgi++))
    ifgcolor[${colors[$clr_idx]}]="${TC}${ifgi}m";  ((ifgi++))
    bgcolor[${colors[$clr_idx]}]="${TC}${bgi}m";    ((bgi++))
    ibgcolor[${colors[$clr_idx]}]="${TC}${ibgi}m";  ((ibgi++))
done

# regular fg/regular bg
printf "       "
printf "%${#styles[@]}s " $(printf "fg:%s " ${colors[@]})
printf "\n"
for clr_r in ${colors[@]}; do
    to_print=" bg:${clr_r}"
    for clr_c in ${colors[@]}; do
        to_print+=" "
        for stl in ${styles[@]}; do
            to_print+="${RST}${bgcolor[${clr_r}]}${fgcolor[${clr_c}]}${style[${stl}]}X${RST}"
        done
    done
    to_print+="\n"
    printf "${to_print}"
done
printf "\n"

# regular fg/intense bg
printf "       "
printf "%${#styles[@]}s " $(printf "fg:%s " ${colors[@]})
printf "\n"
for clr_r in ${colors[@]}; do
    to_print="ibg:${clr_r}"
    for clr_c in ${colors[@]}; do
        to_print+=" "
        for stl in ${styles[@]}; do
            to_print+="${RST}${ibgcolor[${clr_r}]}${fgcolor[${clr_c}]}${style[${stl}]}X${RST}"
        done
    done
    to_print+="\n"
    printf "${to_print}"
done
printf "\n"

# intense fg/regular bg
printf "       "
printf "%${#styles[@]}s " $(printf "ifg:%s " ${colors[@]})
printf "\n"
for clr_r in ${colors[@]}; do
    to_print=" bg:${clr_r}"
    for clr_c in ${colors[@]}; do
        to_print+=" "
        for stl in ${styles[@]}; do
            to_print+="${RST}${bgcolor[${clr_r}]}${ifgcolor[${clr_c}]}${style[${stl}]}X${RST}"
        done
    done
    to_print+="\n"
    printf "${to_print}"
done
printf "\n"

# intense fg/intense bg
printf "       "
printf "%${#styles[@]}s " $(printf "ifg:%s " ${colors[@]})
printf "\n"
for clr_r in ${colors[@]}; do
    to_print="ibg:${clr_r}"
    for clr_c in ${colors[@]}; do
        to_print+=" "
        for stl in ${styles[@]}; do
            to_print+="${RST}${ibgcolor[${clr_r}]}${ifgcolor[${clr_c}]}${style[${stl}]}X${RST}"
        done
    done
    to_print+="\n"
    printf "${to_print}"
done
printf "\n"

echo "${styles[@]}"

unset TC CLR_LINE_START CLR_LINE_END CLR_LINE RESET_LINE RST style fgcolor ifgcolor bgcolor ibgcolor styles colors fgi ifgi bgi ibgi clr_idx clr_r to_print clr_c stl
