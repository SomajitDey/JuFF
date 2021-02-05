#frontend takes a file as input for display and sets global var MESSAGE
#If MESSAGE is null, function exits only if user chose Esc. 

frontend() {

local ESC=$'\e'
local DELAY=0.5
local EXITLOOP=''
local FILE=${1}
local PROMPT1=${2}
local PROMPT2=${3}
local MARGIN=5

while [ -z "${MESSAGE}" ]; do
    while [ -z "${EXITLOOP}" ]; do
        local LINES=`tput lines`
        local DROP=$((${LINES} - ${MARGIN}))
        tput clear
        timeout ${DELAY} tail -n ${DROP} ${FILE}
        tput home ; tput cud ${DROP} ; tput ed
        echo ${PROMPT1}
        read -st ${DELAY} -n 1 EXITLOOP
    done
    [ ${EXITLOOP} == ${ESC} ] && return 1
    unset EXITLOOP
    tput clear
    sed -n p ${FILE}
    tput home ; tput cud ${DROP} ; tput ed
    echo ${PROMPT2}$'\n'
    read -e -p 'Input: ' MESSAGE
done
return 0

}   

#Below is a sample program to utilize frontend. Give a text file as argument.
TEXT1='Esc to go back, any key else to input text, share file or scroll back chat history'
TEXT2='Input message or drag and drop file to send'
frontend ${1} ${TEXT1} ${TEXT2}
[ -z "${MESSAGE}" ] && exit 1
echo ${MESSAGE}
exit 0