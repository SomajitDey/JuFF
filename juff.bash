#Double quotes "${SENTENCE}" for sentence as a single text. Use when passing parameter to functions
#Use coproc for daemon, coproc_PID, coproc[0], coproc[1] see man bash


#TODO: Inbox will hold repo and local copies of chats as hidden files and dir.
#Withing repo every dir should be hidden and file with dir names must be present: 
#This is for autocomplete with :: read -ep

RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
NORMAL=`tput sgr0`
BOLD=`tput bold`
UNDERLINE=`tput smul`


REMOTE=Use ssh for faster git push
BRANCH='main'
INBOX=~'/Inbox_Juff'
REPO=${INBOX}'/.git'
LATEST=${INBOX}'/latest.txt'
DOWNLOADS=${INBOX}'/Downloads'
LOGS=${INBOX}'/.logs'
PUSH_LOG=
PULL_LOG=
GET_LOG=
LASTACT_LOG=    #shows status of last action

SELF_NAME=
SELF_EMAIL=
# MOVE SELF to init()
SELF=${NAME}'::'${EMAIL}
GITBOX=${REPO}'/.'${SELF}

unset MESSAGE   #to be renamed INPUT
unset MSG    #${2}, otherwise empty
unset CORRESPONDENT    #${1}, otherwise empty

CWD=${PWD}

push() {
    git add --all
    git diff --quiet HEAD -- ${1} || git commit ${1} -qm 'bot' && git push -q origin main
}

quit() {
    cd ${CWD} ; tput cnorm ; tput sgr0 ; tput rmcup
    pkill -SIGQUIT daemon
    wait
    exit ${1}
}

post() {

card() {

timestamp() {
  date +::%s
}

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



##########################################################################
########################  TEST  ##########################################
init

daemon &
tput smcup && tput clear


ui() {

local CORRESPONDENT

show() {

clean(){
tput cuu 5 ; tput ed
}

if [ -z "${CORRESPONDENT}" ]; then
    local CHAT=${LATEST}
else
    local CHAT=${INBOX}'/'${CORRESPONDENT}'.txt'
fi

tput clear
[ -e "${CHAT}"] && cat ${CHAT}
clean 5
tput cup 0,0
if [ -z "$CORRESPONDENT" ]; then
    read -p 'Chat with: ' CORRESPONDENT #TODO: Add timeout here
else
    echo 'Chat with : ${CORRESPONDENT}'
fi
}


show
}