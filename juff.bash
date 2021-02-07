readonly_globals() {
set -o pipefail

declare -rg RED=`tput setaf 1`
declare -rg GREEN=`tput setaf 2`
declare -rg YELLOW=`tput setaf 3`
declare -rg BLUE=`tput setaf 4`
declare -rg MAGENTA=`tput setaf 5`
declare -rg CYAN=`tput setaf 6`
declare -rg NORMAL=`tput sgr0`
declare -rg BOLD=`tput bold`
declare -rg UNDERLINE=`tput smul`
declare -rg BELL=`tput bel`

declare -rg REMOTE='https://github.com/SomajitDey/juff.git' #Use ssh instead of https for faster git push
declare -rg BRANCH='test'
declare -rg INBOX=${HOME}'/Inbox_Juff'
declare -rg REPO=${INBOX}'/.git'
declare -rg LATEST=${INBOX}'/.all.txt'
declare -rg DOWNLOADS=${INBOX}'/Downloads'
declare -rg LOGS=${INBOX}'/.logs'
declare -rg PUSH_LOG=${LOGS}'/push.log'
declare -rg LASTACT_LOG=${LOGS}'/lastaction.log'
declare -rg NOTIFICATION=${LOGS}'/notification.log'
declare -rg DELIVERY=${LOGS}'/delivery.log'
}

whiteline() {
echo `tput setab 7`$'\n'"${1}"$'\n'`tput sgr0``tput ed`
}

timestamp() {
  date +${GREEN}%c" ${1}${NORMAL}"
}

config() {

declare -g PAGE='1'

echo >> ${PUSH_LOG}
echo >> ${NOTIFICATION}
echo >> ${DELIVERY}
echo >> ${LASTACT_LOG}

if [ ! -d "${REPO}/.git" ]; then
    mkdir -p ${INBOX}
    mkdir -p ${DOWNLOADS}
    mkdir -p ${LOGS}
    git clone "${REMOTE}" "${REPO}" || exit
    cd ${REPO}
    read -p 'Enter your name without any spaces [you may use _ and .]: ' RESPONSE
    set -- ${RESPONSE}
    git config --local user.name ${1}
    read -p 'Enter your existing emailid: ' RESPONSE
    set -- ${RESPONSE}
    git config --local user.email ${1}
    SELF_EMAIL=${1}
    git config credential.helper store
    echo what about the PAT? && exit
fi

[ ${PWD} != ${REPO} ] && cd ${REPO}

declare -g SELF_NAME=`git config --local user.name`
declare -g SELF_EMAIL=`git config --local user.email`

declare -rg SELF=${SELF_NAME}'#'${SELF_EMAIL}
declare -rg GITBOX=${REPO}'/.'${SELF}
mkdir -p "${GITBOX}" && echo "Created $GITBOX"
declare -rg ANCHOR=${GITBOX}'/anchor'
[ ! -e "${ANCHOR}" ] && echo "Created $ANCHOR" && echo 'This is just so that this directory is never empty' > ${ANCHOR} && read
}

push() {
    git add --all > /dev/null 2>&1
    git diff --quiet HEAD || { git commit -qm 'by juff-daemon' && git push -q origin main ; } > /dev/null 2>&1
    if [ ${?} == '0' ]; then
        timestamp "${GREEN}Push successful"
        echo 'Delivered!' > ${DELIVERY}
    else
        timestamp "${RED}Push failed"
    fi
} >> ${PUSH_LOG}

pull() {
git pull -q origin main > /dev/null 2>&1
[ ${?} != 0 ] && timestamp "${RED}Pull failed" && return 1
local EXT=${1}
if ! ls ${GITBOX}/*${EXT} >/dev/null 2>&1 ; then echo && return 2 ; fi
for FILE in ${GITBOX}/*${EXT}; do
    case ${EXT} in
    .txt)
        local FROM=`echo ${FILE} | grep -o ^[A-Za-z0-9._]*#*[a-z0-9._]*@[a-z0-9._]*`
        local CHAT=${INBOX}'/'${FROM}'.txt'
        xargs curl -sfw '\n' < ${FILE} | tee -a ${LATEST} >> ${CHAT}
        if [ ${?} == '0' ]; then
            whiteline "${BLUE}------${MAGENTA}from ${BOLD}${RED}${FROM}${NORMAL}${\n}" >> ${LATEST}
            timestamp ${BLUE}'Text received from '${RED}${FROM}
        else
            timestamp "${RED}Download failed"
        fi
        ;;
    .dl)
        local DOWNLOADED=`xargs curl -sfw %{filename_effective}'\n' < ${FILE}`
        local DIR="${DOWNLOADS}/${FROM}/"
        [ ! -d "${DIR}"] mkdir ${DIR}
        [ -e "${DOWNLOADED}"] && mv --backup=numbered ${DOWNLOADED} ${DIR}
        if [ ${?} == 0 ]; then 
            timestamp ${BLUE}'File received from '${RED}${FROM}
        else
            timestamp "${RED}Download failed"
        fi
        ;;
    esac
    git rm -q ${FILE}
done
} >> ${NOTIFICATION}

daemon() {
handler() {
ITERATION=$((${COUNT} + 1))
}
trap handler QUIT
local ITERATION
local COUNT='0'
if [ -n "${1}" ]; then
    ITERATION="${1}"
else
    ITERATION=$((${COUNT} - 1))
fi
until [ ${COUNT} == ${ITERATION} ] ; do
    pull
    push
    ((COUNT++))
done
return
}

quit() {
    cd ${OLDPWD} ; tput cnorm ; tput sgr0 ; tput rmcup
    kill -SIGQUIT ${COPROC_PID} >/dev/null 2>&1
    pkill -SIGQUIT daemon >/dev/null 2>&1
    wait
    exit ${1}
}

post() {

card() {

local BLOB=${POSTBOX}'/'${FROM}'#'${EPOCHSECONDS}${2}
echo -e ${1} > ${BLOB}
}

local FROM=${SELF}
local TO=${1}
local POSTBOX=${REPO}'/.'${TO}
local TEXT

[ ! -d "${POSTBOX}" ] && echo ${RED}'ERROR: Recipient could not be found. Sending failed.' && return 1
echo 'Posting...'

if [ -f "${2}" ]; then
    local URL=`curl -sfF "file=@${2}" https://file.io/?expires=2 | grep -o "https://file.io/[A-Za-z0-9]*"`
    if [ -z "${URL}" ]; then 
        echo ${RED}"ERROR: File upload failed. Check internet connectivity."
        return 2
    fi
    card "${URL} -o /tmp/${2##*/}" .dl
    TEXT=${RED}${FROM}${CYAN}$'\n'' sent you '$'\t'${2##*/}${NORMAL}
else
    TEXT=${CYAN}${2}${NORMAL}$'\n'
fi

local URL=`curl -s --data "text=${TEXT}" https://file.io | grep -o "https://file.io/[A-Za-z0-9]*"`
[ -z "${URL}" ] && echo ${RED}"ERROR: Text upload failed. Check internet connectivity." && return 3
card ${URL} .txt
local CHAT=${INBOX}'/'${TO}'.txt'
echo -e ${2}$'\n' >> ${CHAT}
echo 'Message posted for delivery. To be delivered on next push.'
}

frontend() {

local ESC=$'\e'
local DELAY='0.5'
local EXITLOOP
local FILE=${1}
local MARGIN='8'

[ ! -e "${FILE}" ] && echo > ${FILE}
unset INPUT
while [ -z "${INPUT}" ]; do
    while [ -z "${EXITLOOP}" ]; do
        local LINES=`tput lines`
        local DROP=$((${LINES} - ${MARGIN}))
        tput clear
        tail -n ${DROP} ${FILE}
        tput home ; echo 'Press Esc to go back, or scroll for chat history'; tput el
        tput home ; tput cud ${DROP} ; tput ed
        tail -n 1 ${PUSH_LOG}
        tail -n 1 ${NOTIFICATION}
        tail -n 1 ${DELIVERY}
        tail -n 1 ${LASTACT_LOG}
        echo "${2}"
        echo -n "Input: Press any alphanumeric key to input text"
        read -srt ${DELAY} -n 1 EXITLOOP
    done
    [ ${EXITLOOP} == ${ESC} ] && return 1
    unset EXITLOOP
    tput clear
    sed -n p ${FILE}
    tput home ; tput cud ${DROP} ; tput ed
        tail -n 1 ${PUSH_LOG}
        tail -n 1 ${NOTIFICATION}
        tail -n 1 ${DELIVERY}
        tail -n 1 ${LASTACT_LOG}
    echo "${2}"
    read -erp 'Input: ' INPUT
done
return 0

}   

backend() {
if [ ${PAGE} == '1' ]; then
    if [ -n "${INPUT}" ]; then
        CORRESPONDENT="${INPUT}"
        [ ! -d "${REPO}/.${CORRESPONDENT}" ] && echo ${RED}'Recipient could not be found.' && return 1
    else
        [ -z "${CORRESPONDENT}" ] && unset PAGE && echo 'Quitting' && return 1
    fi
    PAGE='2'
    echo "Chatting with ${CORRESPONDENT}" >> ${LASTACT_LOG}
else
    if [ -n "${INPUT}" ]; then
        MESSAGE="${INPUT}"
        post ${CORRESPONDENT} ${MESSAGE} >> ${DELIVERY} &
        unset MESSAGE
    else
        PAGE='1'
        unset CORRESPONDENT
        echo "Back from chatting with ${CORRESPONDENT}" >> ${LASTACT_LOG}
    fi
fi
} >> ${LASTACT_LOG}

ui() {
tput smcup
local INPUT
while [ -n "${PAGE}" ]; do
    case ${PAGE} in
    1)
        [ -z "${CORRESPONDENT}" ] && frontend ${LATEST} 'Who do you wanna chat with?'
        backend
        ;;
    2)
        [ -z "${MESSAGE}" ] && frontend "${INBOX}/${TO}.txt" 'Enter message or drag and drop files to send'
        backend
        ;;
    esac
done

}

#Main

readonly_globals
config
CORRESPONDENT=${1}
MESSAGE=${2}
if [ -n "${MESSAGE}" ]; then
    post "{$CORRESPONDENT}" "${MESSAGE}"
elif [ "${1}" == 'daemon' ]; then
    daemon ; exit
elif [ "${1}" != 'sync' ]; then
    daemon &
    ui
    quit
fi
daemon 1
exit
