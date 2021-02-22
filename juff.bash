#!/usr/bin/env bash
#
#   This is the code for JuFF: a FOSS for instant messaging and filesharing
#   with end-to-end encryption.
#
#   Install git, curl and bash. Then run this script with bash.
#   If you are using Windows 10, turn on Windows Subsystem for Linux,
#   install a Linux distro such as Ubuntu and run this script with bash.
#
#   Copyright 2021, Somajit Dey <dey.somajit@gmail.com>
#   License: GNU GPL-3.0-or-later
#   Repo: https://github.com/SomajitDey/JuFF.git
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
#############################################################################
#
#   Features:
#   1) Secure with public key encryption (end-to-end)
#   2) Uses git as its backend 
#   3) Semi-decentralized & distributed: every active peer mirrors the main git repo
#   4) Fully transparent
#   5) No long-term cloud storage of user data, user data cannot be traced
#   6) Everything is digitally signed and verified
#   7) No GUI
#
#############################################################################
#
#   Free ephemeral file hosting servers used by JuFF:
#   https://transfer.sh (Unstable: uploads without error but 'file not found' on download)
#   https://oshi.at
#   https://file.io
#   https://0x0.st
#
#   Public key encryption and digital signature done with GNU Privacy Guard.
#
#   Git repos for the public-key-server and JuFF are hosted at GitHub.
#
#############################################################################
#
#   If you have already chatted with a friend or two using this script and you liked it so much
#   that you wanna create your own chatroom, the following is for you.
#   To create your own ultra-secure chatroom:
#   1) Create a free account at GitHub etc. that you won't be using for anything else.
#   2) Create a public (bare) repo there.
#   3) Assign the default branch to variable BRANCH below.
#   4) Assign the upstream url to REMOTE.
#   5) Make the default branch protected such that it is linear and none can force push to it
#   or delete it.
#   6) Create access token(s) that are as restricted in scope as possible, definitely without 
#   permission to delete the repo. Send this access token along with this code to anybody you 
#   want to join your chatroom.
#   7) Create another public repo at GitHub etc. for hosting the public keys (i.e. key-server).
#   Only you shall push to this repo., so no need for branch-protection or limited scope tokens.
#   8) Assign the url of this repo to TRUSTREMOTE below.
#   9) Create pubkeys for your admin account (such as registration#juff@github.com) and host at 
#   key-server in a file with name=<your admin account name>
#   10) Create a directory for admin account at REMOTE with name = <your admin account name> and  
#   add an "about" file inside it stating that this is the postbox for your account.
#   **Now host the pubkeys you get from your new members at key-server with filename=<account name>,
#   after cross-checking with the KEY_ID they send you from their registered email (i.e. email 
#   verification) and notify them accordingly.
#
#############################################################################
#
#   TODO:
#   1) Add feature: message to all...message does not need to be encrypted, 
#   but needs to be signed. Host the message within directory "all" at REMOTE.
#   Everybody checks out "all/*" after every sync.
#   2) Add feature: create groups...group messages need to be encrypted
#   with a group public key. The other route is to encrypt with every group mem-
#   ber's pubkey by the sender...would take a huge time for large groups.
#   Encrypted group messages may be hosted at REMOTE for eternity as in large groups, the group
#   private key may be compromised anyway.
#   3) Add feature: Send single message to multiple persons encrypting with individual pubkeys.
#   4) Backend: Kanban style cards for hosting the texts after download. This helps list them
#   according to creation time (alphabetically) (ls -t -1) even if they are downloaded randomly.
#   Still have the option to condense all chats with a correspondent in one text file for portablity
#   (may be a command line option).  
#   5) Add feature: Right key at page 2 shows timestamped view...without it one sees focussed view of chat.
#   6) Have .tmp directory inside INBOX and create temp files there with mktemp. Empty .tmp on restart.
#   7) Have a lockfile in INBOX stating another instance of JuFF is on for the same INBOX or account.
#
#############################################################################
#
#   Known issues:
#   1) Sometimes git pull at REPO would fail even though you have internet. Resolve manually as follows:
#   cd to REPO and do git pull...if the problem is around ORIG_HEAD, remove ORIG_HEAD.lock and do pull again.
#   Simultaneous git operations cannot be the reason for this cockup bcoz all git ops are done serially in JuFF.
#   2) Sometimes an empty URL card is being pushed following the proper card with the same timestamp. And  yet,
#   messages are getting delivered properly! What might be the reason?
#
#############################################################################

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
declare -rg SERVERLOG=${LOGS}'/server.log'
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
declare -rg MAILINGLIST='dey.somajit@gmail.com'
declare -g GPGPASSWD
declare -g SELFKEYID
declare -rg REGISTRAR='registration#juff@github.com'
declare -rg gpg="gpg"   #Ideally this should be the path to gpg or gpg2 + options
declare -rg UIUPDATE="$(mktemp /tmp/uiupdate.XXXXXXXX)" #Flag file for communication between parallel processes (bg & fg)
declare -rg ORIG_WD="${PWD}"
#SEED needs to be random for fair load distribution. Decides what server to upload to first before trying others on failure.
declare -g SEED=${RANDOM}
}

whiteline() {
echo `tput smso`"${1}"$'\n'`tput rmso``tput ed`
}

timestamp() {
  date +${GREEN}%c" ${1}${NORMAL}" ${2}
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
echo "Configuring ..."$'\n'
[ -n "$(which git)" ] || { echo "Install git and relaunch me" && exit;}
[ -n "$(which curl)" ] || { echo "Install curl and relaunch me" && exit;}
[ -n "$(which xargs)" ] || { echo "Install xargs and relaunch me" && exit;}
curl -I "${TRUSTREMOTE}" > /dev/null 2>&1 || { echo "Cannot proceed without internet connection...connect & relaunch." && exit;} 
echo "Please don't take me off internet. Please...Otherwise I will develop withdrawal symptoms"$'\n'
mkdir -p ${INBOX}
mkdir -p ${DOWNLOADS}
mkdir -p ${LOGS}
mkdir -p ${DLQUEUE}
mkdir -p ${BUFFERGARB} ; mkdir -p ${BUFFERSENSE}
echo >> ${PUSH_LOG}
echo >> ${NOTIFICATION}
echo >> ${DELIVERY}
echo >> ${LASTACT_LOG}
touch "${LATEST}"
chmod +t "${INBOX}"; chmod og-rw "${INBOX}"; chmod og-rw "${INBOX}"/*; chmod og-rw "${LATEST}"; chmod og-rw "${DOWNLOADS}"

if [ ! -d "${TRUSTLOCAL}/.git" ]; then
    local TOREGISTER='TRUE'
    git clone --quiet "${TRUSTREMOTE}" "${TRUSTLOCAL}" || { echo "Perhaps an issue with your network"; exit;}
    git clone --quiet "${REMOTE}" "${REPO}" || { echo "Perhaps an issue with your network"; exit;}
    cd ${REPO}
    git switch -q "${BRANCH}"
    git branch -q -u "origin/${BRANCH}"
    git tag lastsync > /dev/null 2>&1
    read -ep $'\n''Enter your name without any spaces [you may use _ and .]: ' RESPONSE
    set -- ${RESPONSE}
    git config --local user.name ${1}
    read -ep $'\n''Enter your emailid (this will be verified): ' RESPONSE
    set -- ${RESPONSE}
    git config --local user.email ${1}
else
    trustpull
    local TOREGISTER
    cd ${REPO}
fi

declare -rg SELF_NAME=`git config --local user.name`
declare -rg SELF_EMAIL=`git config --local user.email`
[ -z "${SELF_EMAIL}" ] && echo "Your inbox is corrupt. Please remove ${YELLOW}${INBOX}${NORMAL} with sudo and launch me afresh." && exit
declare -rg SELF=${SELF_NAME}'#'${SELF_EMAIL}
declare -rg GITBOX=${REPO}'/'${SELF}
declare -rg VERIFIED_SELF=${TRUSTLOCAL}'/'${SELF}   #Contains pubkey (verified through mail) signed by admin
declare -rg ABOUT=${GITBOX}'/about.txt'

echo $'\n'"Welcome ${SELF}"$'\n'

key() {
#One can encrypt this PASSWDFILE with a memorable password/PIN which will then become the juff passwd
rm -rf "${GPGHOME}"
if [ -f "${PORT}" ]; then
    echo "Extracting keys from ${PORT##*/}..."$'\n'
    tar -xzf ${PORT} --directory ${INBOX}
    chmod og-rw "${GPGHOME}"; chmod og-rw "${GPGHOME}"/*
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
    echo 'a) Press Enter to proceed with the creation of new key.' 
    echo 'b) If you already have a key, close this with Ctrl-c and relaunch after installing the key as'$'\n'"${PORT}"$'\n'
    read
    echo "Creating new credentials..."$'\n'
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
        echo 'Uploading your public key for registration...'$'\n'
        post "${REGISTRAR}" "${EXPORT_PUB}" "DONTSIGN"
        daemon 1
        tail -n 1 "${DELIVERY}"
    fi
    
    SELFKEYID=$($gpg --no-default-keyring --keyring "${KEYRING}" \
                --no-auto-check-trustdb --keyid-format long -k ${SELF} | awk NR==2)
    
    if [ -n "${SELFKEYID}" ]; then
        echo ${SELFKEYID} >> ${PASSWDFILE}
        echo "Your key id is: "
        echo ${YELLOW}${SELFKEYID}${NORMAL}$'\n'
        echo "Now email this key id to ${MAILINGLIST} from ${SELF_EMAIL} to complete your registration"
        [ "${PUSHOK}" != 'true' ] && echo "Also attach ${EXPORT_PUB} with your mail. Thank you."
        echo "Once verification is done you will receive a message both here and at ${SELF_EMAIL}"
        echo ${UNDERLINE}"Verification may take a while so please check on me later.${NORMAL}"$'\n'
        echo "See ya then!"
        cd ${INBOX} ; tar -czf ${PORT} .gnupg ; cd ${OLDPWD}
        chmod og-rw "${GPGHOME}"; chmod og-rw "${GPGHOME}"/*
    else
        echo "Key creation failed...something went wrong."$'\n'
        echo "Remove ${INBOX} with sudo rm -r ${INBOX} and launch me again."$'\n'
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
    
    mkdir -p "${GITBOX}"
    [ ! -e "${ABOUT}" ] && \
    echo "This is the JuFF postbox of $SELF_NAME.$'\n'For verified pubkey, refer to $TRUSTREMOTE" > ${ABOUT}
    key
else
    if [ -n "${TOREGISTER}" ]; then
        key
    else
        key
        echo "${RED}The account ${SELF} is not present. If this is unexpected, " \
        "${YELLOW}Email ${GREEN}${MAILINGLIST} ${YELLOW}for query.${NORMAL}"
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
        echo "${RED}Key import failed${NORMAL}"
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
            #In the following, we do rebase when push fails once as above because of someone else pushing before us.
            #This is done to keep the branch linear and avoid any merge prompt at pull asking for a merge commit message.
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
        echo "${YELLOW}You've got mail...importing${NORMAL}"
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
    local SENDTIME=${FILE%.*} && SENDTIME=${SENDTIME##*#}
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
            whiteline "$(timestamp "from ${FROM}" --date=@"${SENDTIME}")" >> ${LATEST}
            touch "${UIUPDATE}"

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
            whiteline "$(timestamp "from ${FROM}" --date=@"${SENDTIME}")" >> ${LATEST}
            touch "${UIUPDATE}"
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
    [ -n "${postPID}" ] && wait "${postPID}"
    [ -n "${dPID}" ] && kill ${dPID} >/dev/null 2>&1
    tput cnorm ; tput sgr0 ; tput rmcup
    exit ${1}
}

#Below we use gpg -a or --armor for encrypted output...This is very important..gpg expects ASCII input while decryting
#So, if we don't upload explicitly ascii output from encryption phase, gpg decryption gives neither output nor error!
post() {
local URL=''
upload(){
local NSERVER=3 #No. of ephemeral file hosting servers
local COUNT=0
local ITERATION=$((NSERVER*5))
local PAYLOAD="${1}"
until ((COUNT == ITERATION)); do
case $(((SEED+COUNT)%NSERVER)) in
0)
#    URL=$(curl -sf --no-epsv --upload-file "${PAYLOAD}" "https://transfer.sh/${PAYLOAD##*/}")
#    [ -n "${URL}" ] && timestamp "Uploaded to transfer.sh on count=$COUNT" >> ${SERVERLOG} && break
    URL=$(curl -sfF "file=@${PAYLOAD}" --no-epsv https://0x0.st)
    [ -n "${URL}" ] && timestamp "Uploaded to 0x0.st on count=$COUNT" >> ${SERVERLOG} && break
    ;;
1)
    URL=$(curl -sfF "file=@${PAYLOAD}" --no-epsv https://file.io | grep -o "https://file.io/[A-Za-z0-9]*")
    [ -n "${URL}" ] && timestamp "Uploaded to file.io on count=$COUNT" >> ${SERVERLOG} && break
    ;;
2)
    URL=$(curl -sfF "file=@${PAYLOAD}" --no-epsv https://oshi.at | awk NR==2 | grep -o "https://oshi.at/[.A-Z0-9_a-z/]*")
    [ -n "${URL}" ] && timestamp "Uploaded to oshi.at on count=$COUNT" >> ${SERVERLOG} && break
    ;;
esac
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
    -o "${CACHETXT}" -e "${CACHEUL}" > /dev/null 2>&1 || { echo 'URL encryption failed' && return 1 ;}
else
    $gpg -a --no-default-keyring --keyring "${KEYRING}" \
    --batch --yes -q --no-greeting --passphrase ${GPGPASSWD} --pinentry-mode loopback \
    --always-trust -r "${TO}" -s -u "${SELFKEYID}" \
    -o "${CACHETXT}" -e "${CACHEUL}" > /dev/null 2>&1 || { echo 'URL encryption failed' && return 1 ;}
fi
#Now put this encrypted URL card ATOMICALLY within REPO so that next push adds it once and for all.
mv "${CACHETXT}" "${BLOB}" && echo ${GREEN}'Message posted for delivery. To be delivered on next push.'${NORMAL}
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
    echo "${GREEN}Fully encrypted. Uploading file now...${NORMAL}"
    upload "${CACHEFILE}"
    [ -z "${URL}" ] && echo ${RED}"ERROR: File upload failed. Check internet connectivity."${NORMAL} && return 2
    local FILENAME="${2##*/}" && card "${URL} -o ${BUFFERGARB}/${FILENAME// /\\ }" ".dl"
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
    echo "${GREEN}Fully encrypted. Uploading text now...${NORMAL}"
    upload "${CACHETXT}"
    [ -z "${URL}" ] && echo ${RED}"ERROR: Text upload failed. Check internet connectivity."${NORMAL} && rm -f "${CACHETXT}" && return 3
    card "${URL}" ".txt"
fi
local CHAT="${INBOX}/${TO}.txt"
echo ${2}$'\n' >> "${CHAT}"
touch "${UIUPDATE}"
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
        [ -z "${NOTIFY}" ] && return
        NOTIFY=''
        tput home
        if [ -z "${EXITLOOP}" ]; then
            tput el && echo "${BOLD}${UNDERLINE}Nav mode ON: Esc = quit or go back ; UP, DOWN, LEFT, RIGHT for navigation${NORMAL}"
        else
            tput el && echo "${BOLD}${UNDERLINE}Input mode ON: Press Enter to switch to Nav mode${NORMAL}"
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
            if [[ "${PAGE}" == '1' ]]; then
            cd ${TRUSTLOCAL}    #This is just so that bash autocompletes the typed user names on Tab press
            read -ep 'Input: ' INPUT    #Absence of -r so that backslash is escaped in \@gmail.com etc.
            else
            cd "${ORIG_WD}" #So that users can choose files from their PWD by providing relative path
            read -erp 'Input: ' INPUT   #-r so that backslash is not escaped for Windows paths; C:\users etc.
            local TMP
            { [ "${INPUT:0:2}" == '~/' ] && TMP="${HOME}/${INPUT#*/}";} || \
            { [ "${INPUT:0:1}" != '/' ] && TMP="${PWD}/${INPUT}";}
            [ -f "${TMP}" ] && INPUT="${TMP}"
            TMP=$(wslpath "${INPUT//\"/}" 2>/dev/null) && [ -f "${TMP}" ] && INPUT="${TMP}"  #For WSL, transform Win path to Unix path
            unset TMP
            ((SEED++))
            fi
            cd ${OLDPWD}
            tput civis
        fi
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
        if [ -e "${UIUPDATE}" ]; then
            rm "${UIUPDATE}"
            REPAINT='true' && SHOWINGTILL=''
        fi
        if [ -n "${REPAINT}" ]; then
            REPAINT='' && NOTIFY='true'
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
declare -g postPID
if [ ${PAGE} == '1' ]; then
    if [ ! -d "${REPO}/${CORRESPONDENT}" ]; then
        echo ${RED}'Recipient could not be found.'${NORMAL}
        unset CORRESPONDENT
    else
        PAGE='2'
        echo "Chatting with ${CORRESPONDENT}"
    fi
else
    [ -n "${postPID}" ] && wait "${postPID}"    #Wait for previous post to finish so that gpg runs 1 instance at a time; otherwise error.
    post "${CORRESPONDENT}" "${MESSAGE}" >> "${DELIVERY}" &
    postPID=${!}
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
        frontend "${INBOX}/${CORRESPONDENT}.txt" 'Enter message or path of the file to be sent [you may also drag & drop the file below]'
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
    echo $'\n'"My defult inbox ${INBOX} doesn't exist:"$'\n'
    echo "1) Press Enter if you want me to proceed and create it." 
    echo "2) Type in the directory path if you have any other inbox in mind."$'\n'
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
            echo $'\n'"Should I go ahead and create ${INBOX} ? [Press any key to proceed. Ctrl-c to exit]"
        else
            echo $'\n'"Should I start configuring ${INBOX} now? [Press any key to proceed. Ctrl-c to exit]"
        fi
        read -sn1
    fi
fi
echo $'\n'"Inbox is at ${INBOX}"$'\n'
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
