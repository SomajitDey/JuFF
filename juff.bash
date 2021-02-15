# Free ephemeral file sharing services:
# https://oshi.at/cmd
# https://0x0.st/
# https://file.io

INBOX=${HOME}'/Inbox_JuFF'  #default: You may customize this

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

declare -g REMOTE='https://github.com/JuFF-GitHub/JuFF---Just-For-Fun.git'
#Use ssh instead of https for faster git push
declare -rg BRANCH='test'
declare -rg REPO=${INBOX}'/.git'
declare -rg LATEST=${INBOX}'/.all.txt'
declare -rg DOWNLOADS=${INBOX}'/Downloads'
declare -rg LOGS=${INBOX}'/.logs'
declare -rg PUSH_LOG=${LOGS}'/push.log'
declare -rg LASTACT_LOG=${LOGS}'/lastaction.log'
declare -rg NOTIFICATION=${LOGS}'/notification.log'
declare -rg DELIVERY=${LOGS}'/delivery.log'
declare -rg DLQUEUE=${INBOX}'/.dlqueue'
declare -rg BUFFERGARB='/tmp/.JuFF'
declare -rg BUFFERSENSE=${INBOX}'/.buffer'
declare -rg SENSETXT=${BUFFERSENSE}'/text.txt'
declare -rg GARBTXT=${BUFFERGARB}'/text.txt'
declare -rg TRUSTREMOTE='https://github.com/SomajitDey/JuFF-KeyServer.git'
#This is a github repo where the maintainer stores files with pubkeys from verified accounts
declare -rg TRUSTLOCAL=${INBOX}'/.trustcentre'
declare -rg PORT=${INBOX}'/my_JuFF.key'
declare -rg GPGHOME=${INBOX}'/.gnupg'
declare -rg EXPORT_SEC=${GPGHOME}'/privatekey.asc'
declare -rg EXPORT_PUB=${GPGHOME}'/pubkey.asc'
declare -rg PASSWDFILE=${GPGHOME}'/passphrase.txt'
declare -rg PATFILE=${GPGHOME}'/access_token.txt'
declare -rg KEYRING=${GPGHOME}'/pubring.kbx'
declare -rg MAILINGLIST='somajit@users.sourceforge.net'
declare -g GPGPASSWD
declare -g SELFKEYID
declare -rg REGISTRAR='registration#juff@github.com'
declare -rg gpg="gpg"   #Ideally this should be the path to gpg or gpg2 
}

whiteline() {
echo `tput smso`"${1}"$'\n'`tput rmso``tput ed`
}

timestamp() {
  date +${GREEN}%c" ${1}${NORMAL}"
}

trustpull() {
cd ${TRUSTLOCAL}
#We tried pull-only; but it would sometimes fail; so done as fetch+merge...
if git fetch --quiet origin main ; then
    if ! git diff --quiet HEAD origin/main ; then
        git pull -q origin main || echo 'Pulling from key-server failed'
    fi
else
    echo 'Fetch from key-server failed'
fi
cd ${OLDPWD}
}

config() {
echo "Configuring ..."
curl -I "${TRUSTREMOTE}" > /dev/null 2>&1 || { echo "Cannot proceed without internet connection...connect & relaunch." && exit;} 
mkdir -p ${INBOX}
mkdir -p ${DOWNLOADS}
mkdir -p ${LOGS}
mkdir -p ${DLQUEUE}
mkdir -p ${BUFFERGARB} ; mkdir -p ${BUFFERSENSE}
echo >> ${PUSH_LOG}
echo >> ${NOTIFICATION}
echo >> ${DELIVERY}
echo >> ${LASTACT_LOG}

if [ ! -d "${TRUSTLOCAL}/.git" ]; then
    local TOREGISTER='TRUE'
    git clone --quiet "${TRUSTREMOTE}" "${TRUSTLOCAL}" || { echo "Perhaps an issue with your network"; exit;}
    git clone --quiet "${REMOTE}" "${REPO}" || { echo "Perhaps an issue with your network"; exit;}
    cd ${REPO}
    git switch ${BRANCH}
    git branch -u 'origin/'${BRANCH}
    git tag lastsync > /dev/null 2>&1
    read -ep 'Enter your name without any spaces [you may use _ and .]: ' RESPONSE
    set -- ${RESPONSE}
    git config --local user.name ${1}
    read -ep 'Enter your emailid (this will be verified): ' RESPONSE
    set -- ${RESPONSE}
    git config --local user.email ${1}
else
    trustpull
    local TOREGISTER
    cd ${REPO}
fi

declare -rg SELF_NAME=`git config --local user.name`
declare -rg SELF_EMAIL=`git config --local user.email`
declare -rg SELF=${SELF_NAME}'#'${SELF_EMAIL}
declare -rg GITBOX=${REPO}'/'${SELF}
declare -rg VERIFIED_SELF=${TRUSTLOCAL}'/'${SELF}   #Contains pubkey (verified through mail) signed by admin
declare -rg ABOUT=${GITBOX}'/about.txt'

echo "Welcome ${SELF}"

key() {
#One can encrypt this PASSWDFILE with a memorable password/PIN which will then become the juff passwd
rm -rf "${GPGHOME}"
if [ -f "${PORT}" ]; then
    echo "Extracting keys from ${PORT##*/}..."
    tar -xzf ${PORT} --directory ${INBOX}
    local FLAG='false'
    [ ! -e "${KEYRING}" ] && echo 'Your JuFF key is broken : No keyring found. Exiting...' && FLAG='true'
    { read GPGPASSWD ; read SELFKEYID; } < ${PASSWDFILE} || \
    { echo 'Your JuFF key is broken : No passwd/keyid. Exiting...' && FLAG='true' ;}
    { read REMOTE < ${PATFILE} && git remote set-url --push origin "${REMOTE}" ;} \
    || { echo 'Your JuFF key is broken : No access token. Exiting...' && FLAG='true' ;}
    if [ "${FLAG}" == 'true' ]; then
        echo 'Fix the broken key or create a new one.'
        echo "To create a new key, delete ${PORT} and then relaunch me."
        exit
    fi
    unset FLAG
else
    echo 'Press Enter to proceed with the creation of new key.' 
    echo 'If you already have a key, close this with Ctrl + C and relaunch after installing the key as' ${PORT}
    read
    echo "Creating new credentials..."
    mkdir -p ${GPGHOME}
    touch "${KEYRING}"
    local SEC_HASH="$(echo ${EPOCHSECONDS}${SELF}${SECONDS} | sha256sum)"
    set -- ${SEC_HASH}
    GPGPASSWD=${1}

    echo ${GPGPASSWD} > ${PASSWDFILE} || echo 'Passphrase creation failed'

    $gpg --no-default-keyring --keyring "${KEYRING}" \
    --batch --no-tty --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --quick-gen-key ${SELF} || echo 'Key creation failed'
    
    $gpg --no-default-keyring --keyring "${KEYRING}" \
    --batch --no-tty --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --armor --output ${EXPORT_PUB} --export ${SELF} || echo 'Public key export failed'

    $gpg --no-default-keyring --keyring "${KEYRING}" \
    --batch --no-tty --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --armor --output ${EXPORT_SEC} --export-secret-keys ${SELF} || echo 'Secure key export failed'
    
    if [ -e ${EXPORT_PUB} ]; then 
        echo "Ok. Now give me your access token:"
        local GITHUBPAT
        read -e GITHUBPAT
        REMOTE="https://JuFF-GitHub:${GITHUBPAT}@github.com/JuFF-GitHub/JuFF---Just-For-Fun.git"
        git remote set-url --push origin "${REMOTE}"
        echo ${REMOTE} > ${PATFILE}
        echo 'Uploading your public key for registration...'
        post "${REGISTRAR}" "${EXPORT_PUB}" "DONTSIGN"
        daemon 1
        tail -n 1 "${DELIVERY}"
    fi
    
    SELFKEYID=$($gpg --no-default-keyring --keyring "${KEYRING}" \
                --no-auto-check-trustdb --keyid-format long -k ${SELF} | awk NR==2)
    
    if [ -n "${SELFKEYID}" ]; then
        echo ${SELFKEYID} >> ${PASSWDFILE}
        echo "Your key id is: "
        echo ${YELLOW}${SELFKEYID}${NORMAL}
        echo "Now email this key id to ${MAILINGLIST} from ${SELF_EMAIL} to complete your registration"
        [ "${PUSHOK}" != 'true' ] && echo "Also attach ${EXPORT_PUB} with your mail. Thank you."
        echo "Once verification is done you will receive a message both here and at ${SELF_EMAIL}"
        echo ${UNDERLINE}"Verification may take a while so please check on me later.${NORMAL}"
        echo "See ya then!"
        cd ${INBOX} ; tar -czf ${PORT} .gnupg ; cd ${OLDPWD}
    else
        echo "Key creation failed...something went wrong."
        echo "Remove ${INBOX} with sudo rm -r ${INBOX} and lanch me again."
    fi
    exit
fi
}

if [ -e "${VERIFIED_SELF}" ]; then
    if [ -n "${TOREGISTER}" ]; then
        echo "${GREEN}This email id is already present and verified.${NORMAL}"
        echo "I have reconfigured the ${INBOX}. ${MAGENTA}What now?${NORMAL}"
        key
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

keyretrieve() {
trustpull
local KEYOF=${1}
local BEFORE=${2}
cd ${TRUSTLOCAL}
local COMMIT=$(git log --name-only --pretty=format:%H --before=${BEFORE} -1 | awk NR==1)

#The idea is that any new public key will always be accompanied with revocation cert of the previous key
#Hence the star/glob below...but perhaps juff doesn't need a revocation cert bcoz of the way it operates
if [ -n "${COMMIT}" ]; then
#git restore -q --source="${COMMIT}" "${KEYOF}*"
git restore -q --source="${COMMIT}" "${KEYOF}"
#for FILES in ${KEYOF}* ; do
local FILES="${KEYOF}"
    $gpg --no-default-keyring --keyring "${KEYRING}" \
    --batch --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --import "${FILES}"
    if [ ${?} == '0' ]; then 
        echo 'Key import succeeded'
    else
        echo 'Key import failed'
    fi
    rm "${FILES}" ; git restore -q --source=HEAD "${FILES}" #For resetting everything back to current HEAD
#done
fi
cd ${OLDPWD}
} >> ${NOTIFICATION}

push() {
declare -g PUSHOK=''
    git add --all > /dev/null 2>&1
    if ! git diff --quiet HEAD; then
        { git commit -qm 'by juff-daemon' && git push -q origin "${BRANCH}" ;} > /dev/null 2>&1
        if [ ${?} == '0' ]; then
            timestamp "${GREEN}Push successful"
            echo ${YELLOW}'Delivered!'${NORMAL} > "${DELIVERY}"
            PUSHOK='true'
        else
            for i in {1..10}; do
                git add --all > /dev/null 2>&1 && { git diff --quiet HEAD || git commit -qm 'by juff-daemon';}
                git fetch --quiet origin "${BRANCH}"
                if { git rebase --quiet origin/"${BRANCH}" && git push -q origin "${BRANCH}";} > /dev/null 2>&1 ; then
                    timestamp "${GREEN}Push successful"
                    PUSHOK='true'
                    echo ${YELLOW}'Delivered!'${NORMAL} > "${DELIVERY}" 
                    break
                else
                    PUSHOK='false'
                    timestamp "${RED}Push failed. Maybe becoz pull is required or there's no net. Retrying"
                    continue
                fi
                echo "No success in pushing! Tried enough"
            done
        fi
    else
        echo ${MAGENTA}'git is synced'${NORMAL}
    fi
} >> ${PUSH_LOG}

queue() {
    for LINE in $(git log --name-only --pretty=format:%H:%an#%ae#%at lastsync.. -- "${GITBOX}"); do
        if [ "${LINE}" == "${LINE##*/}" ]; then
            local COMMIT="${LINE%:*}"
            local FROM="${LINE%#*}" && FROM="${FROM#*:}"
            local COMMITTIME="${LINE##*#}"
            keyretrieve "${FROM}" "${COMMITTIME}"
        elif [ "${LINE##*/}" != 'about.txt' ]; then
            ln -t ${DLQUEUE} ${LINE} > /dev/null 2>&1 && continue
            git restore -q --source="${COMMIT}" "${LINE}" && ln -f -t ${DLQUEUE} ${LINE} && \
            rm "${LINE}"
            git restore -q --source=HEAD "${LINE}"
        fi
    done
    git tag -d lastsync > /dev/null 2>&1
    git tag lastsync > /dev/null 2>&1
} >> ${NOTIFICATION}

pull() {
git pull -q --ff-only origin "${BRANCH}" > /dev/null 2>&1
[ ${?} != 0 ] && timestamp "${RED}Pull failed. Check internet connectivity" && return 1
} >> ${NOTIFICATION}

get() {
for FILE in $(ls "${DLQUEUE}") ; do
    rm -f "${GARBTXT}" "${SENSETXT}" "${BUFFERGARB}/*" "${BUFFERSENSE}/*"  #Precautionary cleanup
    local EXT=$(echo ${FILE} | grep -o [.][txt,dl]*$)
    local FROM=`echo ${FILE} | grep -o ^[A-Za-z0-9._]*#*[a-z0-9._]*@[a-z0-9._]*`
    local CHAT=${INBOX}'/'${FROM}'.txt'
    $gpg --no-default-keyring --keyring "${KEYRING}" \
    --batch --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --always-trust --no-tty -o "${SENSETXT}" -d "${DLQUEUE}/${FILE}" > /dev/null 2>&1 \
    || { echo 'URL decryption/verification failed' && rm "${DLQUEUE}/${FILE}" && continue ;}
    case ${EXT} in
    .txt)
        echo Trying text download...
        xargs curl -sf -o "${GARBTXT}" < ${SENSETXT}
        if [ ${?} == '0' ]; then
            rm "${DLQUEUE}/${FILE}"
            timestamp ${BLUE}'Text received from '${RED}${FROM}
            rm ${SENSETXT}  #i.e. resetting for next output
            $gpg --no-default-keyring --keyring "${KEYRING}" \
            --batch --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
            --always-trust \
            -o "${SENSETXT}" -d "${GARBTXT}" > /dev/null 2>&1 || { echo 'Text decryption failed' && continue ;}
            (cat "${SENSETXT}" && echo) | tee -a ${LATEST} >> ${CHAT} && rm "${SENSETXT}"
            whiteline "$(timestamp "from ${FROM}")" >> ${LATEST}
        else
            timestamp "${RED}Download failed. Will retry again."
        fi
        ;;
    .dl)
        local DIR="${DOWNLOADS}/${FROM}/"
        mkdir -p "${DIR}"
        echo Trying file download...
        local DOWNLOADED=`xargs curl -sfw %{filename_effective}'\n' < ${SENSETXT}`
        if [ ${?} == 0 ]; then 
            rm "${DLQUEUE}/${FILE}"
            timestamp "${BLUE}File received from ${RED}${FROM}"
            local BUFFEREDFILE=${BUFFERSENSE}'/'${DOWNLOADED##*/}
            $gpg --no-default-keyring --keyring "${KEYRING}" \
            --batch --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
            --always-trust \
            -o "${BUFFEREDFILE}" -d "${DOWNLOADED}" > /dev/null 2>&1 || { echo 'File decryption failed' && continue ;}
            mv --backup=numbered "${BUFFEREDFILE}" "${DIR}"
            echo "${CYAN}${FROM} sent ${BUFFEREDFILE##*/}${NORMAL}"$'\n' | tee -a ${LATEST} >> ${CHAT}
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
    tput cnorm ; tput sgr0 ; tput rmcup
    wait ${postPID[@]}
    exit ${1}
}

#Below we use gpg -a or --armor for encrypted output...This is very important..gpg expects ASCII input while decryting
#So, if we don't upload explicitly ascii output from encryption phase, gpg decryption gives neither output nor error!
post() {
local URL
upload(){
local COUNT=0
local ITERATION=5
local PAYLOAD="${1}"
until ((COUNT == ITERATION)); do
    URL=$(curl -sfF "file=@${PAYLOAD}" --no-epsv https://file.io | grep -o "https://file.io/[A-Za-z0-9]*")
    [ -n "${URL}" ] && break
    URL=$(curl -sfF "file=@${PAYLOAD}" --no-epsv https://oshi.at | awk NR==2 | grep -o "https://oshi.at/[.A-Z0-9_a-z/]*")
    [ -n "${URL}" ] && break
    ((COUNT++))
done
}
local CACHETXT='/tmp/readmeifucan.juff'
local CACHEFILE='/tmp/viewmeifucan.juff'
local CACHEUL=${INBOX}'/.ul.txt'
rm -f "${CACHETXT}" "${CACHEFILE}" "${CACHEUL}"  #Precautionary cleanup

local FROM="${SELF}"
local TO="${1}"
local POSTBOX="${REPO}/${TO}"
local TEXT
local DONTSIGN="${3}"

card() {
echo "${GREEN}Upload successful. Yaay !!${NORMAL}"
local BLOB=${POSTBOX}'/'${FROM}'#'${EPOCHSECONDS}${2}
echo -e "${1}" > "${CACHEUL}"
if [ -n "${DONTSIGN}" ]; then 
    $gpg -a --no-default-keyring --keyring "${KEYRING}" \
    --batch --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --always-trust -r "${TO}" \
    -o "${BLOB}" -e "${CACHEUL}" > /dev/null 2>&1 || { echo 'Text encryption failed' && return 1 ;}
else
    $gpg -a --no-default-keyring --keyring "${KEYRING}" \
    --batch --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --always-trust -r "${TO}" -s -u "${SELFKEYID}" \
    -o "${BLOB}" -e "${CACHEUL}" > /dev/null 2>&1 || { echo 'Text encryption failed' && return 1 ;}
fi
echo ${GREEN}'Message posted for delivery. To be delivered on next push.'${NORMAL}
}

[ ! -d "${POSTBOX}" ] && echo ${RED}"ERROR: ${POSTBOX} could not be found. Sending failed."${NORMAL} && return 1
echo 'Trying to upload your encrypted correspondence...'
keyretrieve "${TO}" "${EPOCHSECONDS}"

if [ -f "${2}" ]; then
    if [ -n "${DONTSIGN}" ]; then
    $gpg -a --no-default-keyring --keyring "${KEYRING}" \
    --batch --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --always-trust -r "${TO}" \
    -o "${CACHEFILE}" -e "${2}" > /dev/null 2>&1 || { echo "${RED}File encryption failed${NORMAL}" && return 1 ;}
    else
    $gpg -a --no-default-keyring --keyring "${KEYRING}" \
    --batch --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --always-trust -r "${TO}" -s -u "${SELFKEYID}" \
    -o "${CACHEFILE}" -e "${2}" > /dev/null 2>&1 || { echo "${RED}File encryption failed${NORMAL}" && return 1 ;}
    fi
    echo "${GREEN}Fully encrypted. Uploading now...${NORMAL}"
    upload "${CACHEFILE}"
    [ -z "${URL}" ] && echo ${RED}"ERROR: File upload failed. Check internet connectivity."${NORMAL} && return 2
    card "${URL} -o ${BUFFERGARB}/${2##*/}" ".dl"
else
    TEXT=${CYAN}${2}${NORMAL} && echo "${TEXT}" > "${CACHEUL}"
    if [ -n "${DONTSIGN}" ]; then
    $gpg -a --no-default-keyring --keyring "${KEYRING}" \
    --batch --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --always-trust -r "${TO}" \
    -o "${CACHETXT}" -e "${CACHEUL}" > /dev/null 2>&1 || { echo "${RED}Text encryption failed${NORMAL}" && return 1 ;}
    else
    $gpg -a --no-default-keyring --keyring "${KEYRING}" \
    --batch --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --always-trust -r "${TO}" -s -u "${SELFKEYID}" \
    -o "${CACHETXT}" -e "${CACHEUL}" > /dev/null 2>&1 || { echo "${RED}Text encryption failed${NORMAL}" && return 1 ;}
    fi
    echo "${GREEN}Fully encrypted. Uploading now...${NORMAL}"
    upload "${CACHETXT}"
    [ -z "${URL}" ] && echo ${RED}"ERROR: Text upload failed. Check internet connectivity."${NORMAL} && return 3
    card "${URL}" ".txt"
fi
local CHAT="${INBOX}/${TO}.txt"
echo -e ${2}$'\n' >> "${CHAT}"
}

frontend() {

local TIMEREF='/tmp/juff.time'
logwatch() {
    if [ "${PUSH_LOG}" -ot "${TIMEREF}" ]; then 
        if [ "${NOTIFICATION}" -ot "${TIMEREF}" ]; then
            if [ "${DELIVERY}" -ot "${TIMEREF}" ]; then
                if [ "${LASTACT_LOG}" -ot "${TIMEREF}" ]; then
                    touch "${TIMEREF}" ; return
                fi
            fi
        fi
    fi
    NOTIFY='true'
    touch "${TIMEREF}"
}

display() {
        [ -z "${NOTIFY}" ] && [ -z "${REPAINT}" ] && return
        tput home
        if [ -z "${EXITLOOP}" ]; then
            tput el && echo 'Nav mode ON: Esc = quit or go back ; UP, DOWN, LEFT, RIGHT for navigation'
        else
            tput el && echo 'Input mode ON: Press Enter to switch to Nav mode'
        fi
        tput el; tput cud1 && tput el
        tput home ; tput cud ${DROP} ; tput ed
        tail -n 1 ${PUSH_LOG}
        tail -n 1 ${NOTIFICATION}
        tail -n 1 ${DELIVERY}
        tail -n 1 ${LASTACT_LOG}
        echo "${PROMPT}"
        if [ -z "${EXITLOOP}" ]; then
            echo -n "Input: Press any alphanumeric key..."
        else
            tput cnorm
            cd ${TRUSTLOCAL}    #This is just so that bash autocompletes the typed user names on Tab press
            read -ep 'Input: ' INPUT
            local TMP
            [ "${INPUT:0:2}" == '~/' ] && TMP="${HOME}/${INPUT#*/}" && [ -f "${TMP}" ] && INPUT="${TMP}"
            unset TMP
            cd ${OLDPWD}
            tput civis
        fi
        NOTIFY=''
}

local ESC=$'\e'
local CSI=${ESC}'['
local UP=${CSI}'A'
local DOWN=${CSI}'B'
local RIGHT=${CSI}'C'
local LEFT=${CSI}'D'

local DELAY='0.1' #This is the refresh time period (to display new message)
local EXITLOOP ; local TRAILING
local FILE=${1}
local PROMPT="${2}"
local MARGIN='8'
local SCROLL='1'
local HEADER='2'
local SHOWINGTILL; local SHOWINGFROM
local REPAINT='true'
touch "${TIMEREF}"
trap "REPAINT='true'" SIGWINCH
local NOTIFY='true'

[ ! -e "${FILE}" ] && echo > ${FILE}
unset INPUT ; unset EXITLOOP
while [ -z "${INPUT}" ]; do
    while [ -z "${EXITLOOP}" ]; do
        logwatch
        if [ -n "${REPAINT}" ]; then
            local WINDOW=$(set -- $(wc -l ${FILE}) && echo $1)
            [ -z "${SHOWINGTILL}" ] && SHOWINGTILL=${WINDOW}
            local DROP=$(($(tput lines) - MARGIN))
            tput clear ; tput cud 2
            SHOWINGFROM=$((SHOWINGTILL-DROP + HEADER))
            if ((SHOWINGFROM < 1)); then SHOWINGFROM='1'; fi
            awk "NR==${SHOWINGFROM},NR==${SHOWINGTILL}" "${FILE}"
        fi
        display
        read -srt ${DELAY} -n 1 EXITLOOP && read -srt0.001 TRAILING
        REPAINT=''
    done
    if [ ${EXITLOOP} == ${ESC} ]; then 
        case ${EXITLOOP}${TRAILING} in
            ${UP} ) ((SHOWINGTILL-SCROLL > DROP-HEADER)) && SHOWINGTILL=$((SHOWINGTILL-SCROLL)) && REPAINT='true' ;;
            ${DOWN} ) WINDOW=$(set -- $(wc -l ${FILE}) && echo $1) 
                    ((SHOWINGTILL+SCROLL <= WINDOW)) && SHOWINGTILL=$((SHOWINGTILL+SCROLL)) && REPAINT='true' ;;
            ${RIGHT} ) return 2 ;;
            ${LEFT} ) return 3 ;;
            * ) return 1 ;;
        esac
    else
        NOTIFY='true' && display
    fi
    EXITLOOP=''
done
return 0

}   

backend() {
if [ ${PAGE} == '1' ]; then
    if [ ! -d "${REPO}/${CORRESPONDENT}" ]; then
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
trap quit QUIT TERM INT HUP

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
        1 | 3 ) PAGE='1' ; PREV_CORR="${CORRESPONDENT}"
                echo "Back from chatting with ${CORRESPONDENT}" >> ${LASTACT_LOG} 
                unset CORRESPONDENT ;;
        2 ) altscr ;;
        esac
        [ -n "${MESSAGE}" ] && backend ;;
    esac
done

}

#Main

if [ ! -d "${INBOX}" ]; then 
    echo "My defult inbox ${INBOX} doesn't exist"
    echo "Press Enter if you want me to proceed and create it." 
    echo "Type in the directory path if you have any other inbox in mind."
    read -ep 'Type inbox pathname here: '
    if [ -n "${REPLY}" ]; then 
        [ "${REPLY: -1}" == '/' ] && REPLY="${REPLY%/*}"
        if [ "${REPLY:0:2}" == '~/' ]; then
            INBOX="${HOME}/${REPLY#*/}"
        elif [ "${REPLY:0:1}" != '/' ]; then
            INBOX="${PWD}/${REPLY}"
        else
            INBOX="${REPLY}"
        fi
        [ -f "${INBOX}" ] && echo 'This is a file not a directory' && exit
        if [ ! -d "${INBOX}" ]; then
            echo "Should I go ahead and create ${INBOX} ?"
        else
            echo "Should I start configuring ${INBOX} now?"
        fi
        echo "Press any key to proceed. Ctrl-c to exit."
        read -n1
    fi
fi
echo "Inbox is at ${INBOX}"
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
