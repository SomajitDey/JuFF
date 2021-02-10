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
declare -rg BRANCH='juff-test'
declare -rg INBOX=${HOME}'/Inbox_JuFF'
declare -rg REPO=${INBOX}'/.git'
declare -rg LATEST=${INBOX}'/.all.txt'
declare -rg DOWNLOADS=${INBOX}'/Downloads'
declare -rg LOGS=${INBOX}'/.logs'
declare -rg PUSH_LOG=${LOGS}'/push.log'
declare -rg LASTACT_LOG=${LOGS}'/lastaction.log'
declare -rg NOTIFICATION=${LOGS}'/notification.log'
declare -rg DELIVERY=${LOGS}'/delivery.log'
declare -rg DLQUEUE=${INBOX}'/.dlqueue'
declare -rg BUFFER=${INBOX}'/.buffer.txt'
declare -rg TRUSTREMOTE='https://github.com/SomajitDey/JuFF-KeyServer.git'
#This is a github repo where the maintainer stores files with pubkeys from verified accounts
declare -rg TRUSTLOCAL=${INBOX}'/.trustcentre'
declare -rg PORT=${INBOX}'/my_JuFF.key'
declare -rg GPGHOME=${INBOX}'/.gnupg'
declare -rg SELFKEYRING=${GPGHOME}'/self.kbx'
declare -rg EXPORT_SEC=${GPGHOME}'/privatekey.asc'
declare -rg EXPORT_PUB=${GPGHOME}'/pubkey.asc'
declare -rg PASSWDFILE=${GPGHOME}'/passphrase.txt'
declare -rg TMPKEYRING=${GPGHOME}'/corr.kbx'
declare -rg ORIGPWD=${PWD}
declare -rg GITHUBPAT=${TRUSTLOCAL}'/access_token.txt'
declare -rg MAILINGLIST='somajit@users.sourceforge.net'
declare -g GPGPASSWD
declare -g SELFKEYID
declare -rg REGISTRAR='registration#juff@github.com'
}

whiteline() {
echo `tput setab 7`$'\n'"${1}"$'\n'`tput sgr0``tput ed`
}

timestamp() {
  date +${GREEN}%c" ${1}${NORMAL}"
}

config() {
echo "Configuring ..."
mkdir -p ${INBOX}
mkdir -p ${DOWNLOADS}
mkdir -p ${LOGS}
mkdir -p ${DLQUEUE}
mkdir -p ${GPGHOME}
echo >> ${PUSH_LOG}
echo >> ${NOTIFICATION}
echo >> ${DELIVERY}
echo >> ${LASTACT_LOG}

if [ ! -d "${TRUSTLOCAL}/.git" ]; then
    local TOREGISTER='TRUE'
    git clone "${TRUSTREMOTE}" "${TRUSTLOCAL}" || { echo "Perhaps an issue with your network"; exit;}
    git clone "${REMOTE}" "${REPO}" || { echo "Perhaps an issue with your network"; exit;}
    cd ${REPO}
    git switch ${BRANCH}
    git branch -u 'origin/'${BRANCH}
    read -p 'Enter your name without any spaces [you may use _ and .]: ' RESPONSE
    set -- ${RESPONSE}
    git config --local user.name ${1}
    read -p 'Enter your emailid (this will be verified): ' RESPONSE
    set -- ${RESPONSE}
    git config --local user.email ${1}
    git config --local credential.helper store --file=${GITHUBPAT}
else
    cd ${REPO}
fi

declare -rg SELF_NAME=`git config --local user.name`
declare -rg SELF_EMAIL=`git config --local user.email`
declare -rg SELF=${SELF_NAME}'#'${SELF_EMAIL}
declare -rg GITBOX=${REPO}'/'${SELF}
declare -rg VERIFIED_SELF=${TRUSTLOCAL}'/${SELF}'   #Contains pubkey (verified through mail) signed by admin
declare -rg ABOUT=${GITBOX}'/about.txt'

key() {
#One can encrypt this PASSWDFILE with a memorable password/PIN which will then become the juff passwd
if [ ( -f "${SELFKEYRING}" ) && ( -f "${PASSWDFILE}" ) ]; then 
    { read GPGPASSWD ; read SELFKEYID; } < ${PASSWDFILE}
elif [ -f "${PORT}" ]; then
    tar -xzf ${PORT} --directory ${INBOX}
else
    echo "Creating your credentials..."
    local SEC_HASH="$(echo ${EPOCHSECONDS}${SELF} | sha256sum)"
    set -- ${SEC_HASH}
    GPGPASSWD=${1}

    echo ${GPGPASSWD} > ${PASSWDFILE} || echo 'Passphrase creation failed'

    gpg --no-default-keyring --keyring ${SELFKEYRING} \
    --batch -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --quick-gen-key ${SELF} || echo 'Key creation failed'
    
    gpg --no-default-keyring --keyring ${SELFKEYRING} \
    --batch -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --armor --output ${EXPORT_PUB} --export ${SELF} || echo 'Public key export failed'

    gpg --no-default-keyring --keyring ${SELFKEYRING} \
    --batch -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --armor --output ${EXPORT_SEC} --export-secret-keys ${SELF} || echo 'Secure key export failed'
    
    cd ${INBOX} ; tar -cvzf ${PORT} .gnupg ; cd ${OLDPWD}
    
    if [ -e ${EXPORT_PUB} ]; then 
        echo 'Uploading your public key for registration...'
        post "${REGISTRAR}" "${EXPORT_PUB}"
        daemon 1
        tail -n 1 "${DELIVERY}"
    fi
    
    gpg --no-default-keyring --keyring ${SELFKEYRING} \
    --keyid-format long -k ${SELF} | awk NR==2 | read SELFKEYID 
    
    if [ -n "${SELFKEYID}" ]; then
        echo ${SELFKEYID} > ${PASSWDFILE}
        echo "Your key id is: "
        echo ${YELLOW}${SELFKEYID}${NORMAL})
        echo "Now email this key id to ${MAILINGLIST} from ${SELF_EMAIL} to complete your registration"
        [ "${PUSHOK}" != 'true' ] && echo "Also attach ${EXPORT_PUB} with your mail. Thank you."
        echo "Once verification is done you will receive a message both here and at ${SELF_EMAIL}"
        echo ${UNDERLINE}"Verification may take a while so please check on me later.${NORMAL}"
        echo "See ya then!"
    else
        echo "Key creation failed...something went wrong."
    fi
    exit
fi
}

if [ -e "${VERIFIED_SELF}" ]; then
    if [ -n "${TOREGISTER}" ]; then
        echo "${GREEN}This email id is already present and verified.${NORMAL}"
        echo "I have reconfigured the ${INBOX}. ${MAGENTA}What now?${NORMAL}"
        echo "${BOLD}1)${NORMAL}${BLUE}Create ${PORT} and relaunch me.${NORMAL}"
        echo "${BOLD}2)${NORMAL}${YELLOW}In case you have lost your JuFF key, "\
             "email a 'new-key' request to ${MAILINGLIST}${NORMAL}"
        exit
    fi
    
    mkdir -p ${GITBOX}
    [ ! -e "${ABOUT}" ] && \
    echo "This is the JuFF postbox of $SELF_NAME.$'\n'For verified pubkey, refer to $TRUSTREMOTE" > ${ABOUT}
    key
else
    if [ -n "${TOREGISTER}" ]; then
        key
    else
        key
        echo "${RED}The account ${SELF} is not present. If this is unexpected, " \
        "${BLUE}Email ${UNDERLINE}${MAILINGLIST} to query.${NORMAL}"
        exit
    fi
fi
}

push() {
declare -g PUSHOK='true'
    git add --all > /dev/null 2>&1
    if ! git diff --quiet HEAD; then
        { git commit -qm 'by juff-daemon' && git push -q origin "${BRANCH}" ;} > /dev/null 2>&1
        if [ ${?} == '0' ]; then
            timestamp "${GREEN}Push successful"
            echo ${YELLOW}'Delivered!'${NORMAL} > "${DELIVERY}"
        else
            PUSHOK='false'
            timestamp "${RED}Push failed. Maybe becoz pull is required or maybe there's no net"
        fi
    else
        echo ${MAGENTA}'git is synced'${NORMAL}
    fi
} >> ${PUSH_LOG}

queue() {
local COMMIT
    for LINE in $(git log --name-only --pretty=format:%H last.. -- "${GITBOX}"); do
        if [ "${LINE}" == "${LINE##*/}" ]; then
            COMMIT="${LINE}"
        else
            ln -t ${DLQUEUE} ${LINE} > /dev/null 2>&1 && continue
            git restore -q --source="${COMMIT}" "${LINE}" && ln -t ${DLQUEUE} ${LINE} && \
            rm "${LINE}"
            git restore -q --source=HEAD "${LINE}"
        fi
    done
    git tag -d last > /dev/null 2>&1
} >> ${NOTIFICATION}

pull() {
git tag last > /dev/null 2>&1
git pull -q --ff-only origin "${BRANCH}" > /dev/null 2>&1
[ ${?} != 0 ] && timestamp "${RED}Pull failed. Check internet connectivity" && return 1
} >> ${NOTIFICATION}

get() {
for FILE in ${DLQUEUE}/* ; do
    local EXT=$(echo ${FILE} | grep -o [.][txt,dl]*$)
    local FROM=`echo ${FILE##*/} | grep -o ^[A-Za-z0-9._]*#*[a-z0-9._]*@[a-z0-9._]*`
    case ${EXT} in
    .txt)
        echo Trying text download...
        local CHAT=${INBOX}'/'${FROM}'.txt'
        xargs curl -sf -o "${BUFFER}" < ${FILE}
        if [ ${?} == '0' ]; then
            (cat "${BUFFER}" && echo) | tee -a ${LATEST} >> ${CHAT} && rm "${BUFFER}"
            whiteline "${BLUE}------${MAGENTA}from ${BOLD}${RED}${FROM}${NORMAL}"$'\n' >> ${LATEST}
            timestamp ${BLUE}'Text received from '${RED}${FROM}
            rm ${FILE}
        else
            timestamp "${RED}Download failed. Will retry again."
        fi
        ;;
    .dl)
        echo Trying file download...
        local DOWNLOADED=`xargs curl -sfw %{filename_effective}'\n' < ${FILE}`
        local DIR="${DOWNLOADS}/${FROM}/"
        mkdir -p "${DIR}"
        [ -e "${DOWNLOADED}" ] && mv --backup=numbered "${DOWNLOADED}" "${DIR}"
        if [ ${?} == 0 ]; then 
            timestamp "${BLUE}File received from ${RED}${FROM}"
            rm ${FILE}
        else
            timestamp "${RED}Download failed. Will retry again."
        fi
        ;;
    esac
done
} >> ${NOTIFICATION}

daemon() {
handler() {
ITERATION=$((${COUNT} + 1))
}
trap handler QUIT TERM INT HUP
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
    queue
    get
    [ "${PUSHOK}"=='true' ] && ((COUNT++))
done
echo "Everything synced gracefully"
echo "Press Enter if the prompt is not available below"
}

quit() {
    [ -n "${dPID}" ] && kill ${dPID} >/dev/null 2>&1
    cd ${ORIGPWD} ; tput cnorm ; tput sgr0 ; tput rmcup
    wait ${postPID[@]}
    exit ${1}
}

post() {

card() {

local BLOB=${POSTBOX}'/'${FROM}'#'${EPOCHSECONDS}${2}
echo -e ${1} > ${BLOB}
}

local FROM=${SELF}
local TO=${1}
local POSTBOX=${REPO}'/'${TO}
local TEXT

[ ! -d "${POSTBOX}" ] && echo ${RED}"ERROR: ${POSTBOX} could not be found. Sending failed."${NORMAL} && return 1
echo 'Posting...'

if [ -f "${2}" ]; then
    local URL=`curl -sfF "file=@${2}" https://file.io/?expires=2 | grep -o "https://file.io/[A-Za-z0-9]*"`
    if [ -z "${URL}" ]; then 
        echo ${RED}"ERROR: File upload failed. Check internet connectivity."${NORMAL}
        return 2
    fi
    card "${URL} -o /tmp/${2##*/}" ".dl"
    TEXT=${RED}${FROM}${CYAN}$'\n'' sent you '$'\t'${2##*/}${NORMAL}
else
    TEXT=${CYAN}${2}${NORMAL}$'\n'
fi

local URL=`curl -s --data "text=${TEXT}" https://file.io | grep -o "https://file.io/[A-Za-z0-9]*"`
[ -z "${URL}" ] && echo ${RED}"ERROR: Text upload failed. Check internet connectivity."${NORMAL} && return 3
card ${URL} .txt
local CHAT=${INBOX}'/'${TO}'.txt'
echo -e ${2}$'\n' >> ${CHAT}
echo ${GREEN}'Message posted for delivery. To be delivered on next push.'${NORMAL}
}

frontend() {
display() {
        tput home
        if [ -z "${EXITLOOP}" ]; then
            echo -n 'Nav mode ON: Esc = quit or go back ; UP, DOWN, LEFT, RIGHT for navigation'
        else
            echo -n 'Input mode ON: Press Enter to switch to Nav mode'
        fi
        tput el; tput cud1 && tput el
        tput home ; tput cud ${DROP} ; tput ed
        tail -n 1 ${PUSH_LOG}
        tail -n 1 ${NOTIFICATION}
        tail -n 1 ${DELIVERY}
        tail -n 1 ${LASTACT_LOG}
        echo "${PROMPT}"
}

local ESC=$'\e'
local CSI=${ESC}'['
local UP=${CSI}'A'
local DOWN=${CSI}'B'
local RIGHT=${CSI}'C'
local LEFT=${CSI}'D'

local DELAY='1' #This is the refresh time period (to display new message)
local EXITLOOP ; local TRAILING
local FILE=${1}
local PROMPT="${2}"
local MARGIN='8'
local SCROLL='2'
local SHOWINGTILL

[ ! -e "${FILE}" ] && echo > ${FILE}
unset INPUT ; unset EXITLOOP
while [ -z "${INPUT}" ]; do
    while [ -z "${EXITLOOP}" ]; do
        local WINDOW=$(set -- $(wc -l ${FILE}) && echo $1)
        [ -z "${SHOWINGTILL}" ] && SHOWINGTILL=${WINDOW}
        local DROP=$(($(tput lines) - ${MARGIN}))
        tput clear
        awk "NR==$((${SHOWINGTILL}-${DROP})),NR==${SHOWINGTILL}" "${FILE}"
        display
        echo -n "Input: Press any alphanumeric key..."
        read -srt ${DELAY} -n 1 EXITLOOP && read -srt0.001 TRAILING
    done
    if [ ${EXITLOOP} == ${ESC} ]; then 
        case ${EXITLOOP}${TRAILING} in
            ${UP} ) SHOWINGTILL=$((${SHOWINGTILL} - ${SCROLL})) ;;
            ${DOWN} ) (( ${SHOWINGTILL} + ${SCROLL} <= ${WINDOW} )) && SHOWINGTILL=${SHOWINGTILL}+${SCROLL} ;;
            ${RIGHT} ) return 2 ;;
            ${LEFT} ) return 3 ;;
            * ) return 1 ;;
        esac
    else
    display
    tput cnorm
    read -erp 'Input: ' INPUT
    tput civis
    fi
    unset EXITLOOP
done
return 0

}   

backend() {
if [ ${PAGE} == '1' ]; then
    if [ ! -d "${REPO}/.${CORRESPONDENT}" ]; then
        echo ${RED}'Recipient could not be found.'${NORMAL}
        unset CORRESPONDENT
    else
        PAGE='2'
        echo "Chatting with ${CORRESPONDENT}"
    fi
else
    post "${CORRESPONDENT}" "${MESSAGE}" >> "${DELIVERY}" &
    declare -g postPID+=(${!})
    unset MESSAGE
fi
} >> ${LASTACT_LOG}

ui() {
tput smcup ; tput civis
altscr() {
tput rmcup ; tput cnorm
read -sn1 -p 'Press any key to return to juff. Ctrl-c to exit.' && read -st0.001
echo ; tput cuu1 ; tput ed ; tput smcup ; tput civis
}
local INPUT ; local PREV_CORR
local PAGE='1'
while [ -n "${PAGE}" ]; do
    case ${PAGE} in
    1)
        if [ -z "${CORRESPONDENT}" ]; then 
            frontend ${LATEST} 'Who do you wanna chat with?'
            case ${?} in
            0)  CORRESPONDENT="${INPUT}" ;;
            1)  unset PAGE ;;
            2)  CORRESPONDENT="${PREV_CORR}" ;;
            3)  altscr ;;
            esac
        fi
        [ -n "${CORRESPONDENT}" ] && backend ;;
    2)
        frontend "${INBOX}/${CORRESPONDENT}.txt" 'Enter message or drag and drop files to send'
        case ${?} in 
        0)  MESSAGE="${INPUT}" ;;
        1 | 3 ) PAGE='1' ; PREV_CORR="${CORRESPONDENT}" ; unset CORRESPONDENT
                echo "Back from chatting with ${CORRESPONDENT}" >> ${LASTACT_LOG} ;;
        2 ) altscr ;;
        esac
        [ -n "${MESSAGE}" ] && backend ;;
    esac
done

}

#Main

readonly_globals
config
CORRESPONDENT=${1}
MESSAGE=${2}
if [ -n "${MESSAGE}" ]; then
    post "${CORRESPONDENT}" "${MESSAGE}"
elif [ "${1}" == 'daemon' ]; then
    daemon & 
    echo ${!}
    exit
elif [ "${1}" != 'sync' ]; then
    daemon &
    dPID=${!}
    ui
    quit
fi
daemon 1
tail -n 1 "${DELIVERY}"
exit
