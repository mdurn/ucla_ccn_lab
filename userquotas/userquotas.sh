#!/bin/bash
# userquotas.sh
# Author: Michael Durnhofer
# email: mdurn@ucla.edu
#
# Takes 1 argument for the group name. For use on hoffman2 cluster. Prints out
# a list of users and individual quota usage for the given group.

txtred='\e[0;31m'
txtgrn='\e[0;32m'
txtblk='\e[0;30m'
bldblk='\e[1;30m'

if [[ $1 == '' ]]; then
    echo -e "${txtred}Error: userquotas.sh must take 1 argument <groupname>"
    echo -e "${txtgrn}Usage: sh userquotas.sh <groupname>"
    echo -e "${txtblk}Exiting..."
    exit
fi

if [[ $2 != '' ]]; then
    echo -e "${txtred}Error: userquotas.sh takes only 1 argument <groupname>"
    echo -e "${txtgrn}Usage: sh userquotas.sh <groupname>"
    echo -e "${txtblk}Exiting..."
    exit
fi

groupname=$1
if [[ $(quota -g ${1} 2>/dev/null) == ''  ]]; then
    echo -e "${txtred}Error: cannot find group '${groupname}'"
    echo -e "${txtblk}Exiting..."
    exit
fi

userlist=$(cat /etc/passwd | grep ${groupname} | awk -F':' '{ print $1 }')

echo -e "${bldblk}GROUP: ${txtblk}${groupname}\n"
echo -e "${txtblk}$(myquota -g ${groupname} | grep ${groupname} | tail -1)\n"

echo -e "${bldblk}User\t\tUsage\tLimit\t\tFile Usage\tFile Quota${txtblk}"
for i in ${userlist[@]}; do
    name=$(myquota -u $i | grep $i | head -1 | awk -F' ' '{ print $4 }')
    fusage=($(myquota -u $i | grep ${groupname} | tail -2 | head -1 | awk -F' ' '{ print $2,$3,$4,$5 }'))

    nametab="\t\t"
    if [[ $(expr length $i) > 7 ]]; then
        nametab="\t"
    fi

    echo -e "${name}${nametab}${fusage[0]}\t${fusage[1]}\t\t${fusage[2]}\t\t${fusage[3]}"
done
