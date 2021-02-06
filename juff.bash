readonly_globals() {
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

declare -rg REMOTE=Use ssh for faster git push
declare -rg BRANCH='main'
declare -rg INBOX=${HOME}'/Inbox_Juff'
declare -rg REPO=${INBOX}'/.git'
declare -rg LATEST=${INBOX}'/latest.txt'
declare -rg DOWNLOADS=${INBOX}'/Downloads'
declare -rg LOGS=${INBOX}'/.logs'
declare -rg PUSH_LOG=
declare -rg PULL_LOG=
declare -rg GET_LOG=
declare -rg LASTACT_LOG=    #shows status of last action
}

timestamp() {
  date +::%s
}

config() {
SELF_NAME=
SELF_EMAIL=
# MOVE SELF to init()
SELF=${NAME}'::'${EMAIL}
GITBOX=${REPO}'/.'${SELF}

unset MESSAGE   #to be renamed INPUT
unset MSG    #${2}, otherwise empty
unset CORRESPONDENT    #${1}, otherwise empty
}

push() {
    git add --all
    git diff --quiet HEAD || { git commit -qm 'by juff-daemon' && git push -q origin main }
}

quit() {
    cd ${OLDPWD} ; tput cnorm ; tput sgr0 ; tput rmcup
    pkill -SIGQUIT daemon
    wait
    exit ${1}
}

post() {

card() {

local BLOB=${POSTBOX}'/'${FROM}`timestamp`${2}
echo -e ${1} > ${BLOB}
}

local FROM=${SELF}
local TO=${1}
local POSTBOX=${REPO}'/.'${TO}

[ ! -d "${POSTBOX}" ] && return 1

if [ -f "${2}" ]; then
    local URL=`curl -sfF "file=@${2}" https://file.io/?expires=2 | grep -o "https://file.io/[A-Za-z0-9]*"`
    [ -z "${URL}" ] && return 2
    card "${URL} -o /tmp/${2##*/}" .dl
    local TEXT=${FROM}' sent you '$'\t'${2##*/}
else
    local TEXT=${FROM}'>>'$'\t'${2}
fi

local URL=`curl -s --data "text=${TEXT}" https://file.io | grep -o "https://file.io/[A-Za-z0-9]*"`
[ -z "${URL}" ] && return 3
card ${URL} .txt
local CHAT=${INBOX}'/'${TO}'.txt'
echo -e ${TEXT} | tee -a ${LATEST} >> ${CHAT}

}

pull() {
git pull -q origin main
local EXT=${1}
if ! ls ${GITBOX}/*${EXT} >/dev/null 2>&1 ; return 1
for FILE in ${GITBOX}/*${EXT}; do
    case ${EXT} in
    .txt)
        local FROM=`echo ${FILE} | grep -o ^[A-Za-z0-9._]*[:]*[a-z0-9._]*[@][a-z0-9._]*`
        local CHAT=${INBOX}'/'${FROM}'.txt'
        xargs curl -sfw '\n' < ${FILE} | tee -a ${LATEST} >> ${CHAT}
        ;;
    .dl)
        local DOWNLOADED=`xargs curl -sfw %{filename_effective}'\n' < ${FILE}`
        local DIR="${DOWNLOADS}/${FROM}/"
        [ ! -d "${DIR}"] mkdir ${DIR}
        [ -e "${DOWNLOADED}"] mv --backup=numbered ${DOWNLOADED} ${DIR}
    esac
    git rm -q ${FILE}
done
fi
}

daemon() {
local WRAPUP=''
handler() {
WRAPUP='Signal'
}
trap handler QUIT
while [ -z "${WRAPUP}" ] ; do
    pull
    push
done
}

frontend() {

local ESC=$'\e'
local DELAY=0.5
local EXITLOOP=''
local FILE=${1}
local MARGIN=5

# unset MESSAGE : If MESSAGE is already set, say by command line argument of Juff
# why bother to enter following loop
while [ -z "${MESSAGE}" ]; do
    while [ -z "${EXITLOOP}" ]; do
        local LINES=`tput lines`
        local DROP=$((${LINES} - ${MARGIN}))
        tput clear
        timeout ${DELAY} tail -n ${DROP} ${FILE}
        tput home ; echo 'Esc to go back, any key else to input text, share file or scroll back chat history'; tput el
        tput home ; tput cud ${DROP} ; tput ed
        echo ${PROMPT1}
        read -srt ${DELAY} -n 1 EXITLOOP
    done
    [ ${EXITLOOP} == ${ESC} ] && return 1
    unset EXITLOOP
    tput clear
    sed -n p ${FILE}
    tput home ; tput cud ${DROP} ; tput ed
    echo ${PROMPT2}$'\n'
    read -erp 'Input: ' MESSAGE
done
return 0

}   

backend() {
if [ ${PAGE} == '1' ]; then
    if [ -n ${MESSAGE} ]; then
        CORRESPONDENT=${MESSAGE}
        [ ! -d "${REPO}/.${CORRESPONDENT}" ] && return 1    #Set PROMPT1 for next display as 'can't find username'
        PAGE='2'
    else
        quit 1
    fi
else
    if [ -n ${MESSAGE} ]; then
        MESSAGE=${MESSAGE}  #${MESSAGE} should be INPUT
        PAGE='2'
        post ${CORRESPONDENT} ${MESSAGE}
    else
        PAGE='1'
    fi
fi
}
