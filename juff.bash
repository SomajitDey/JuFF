REMOTE=
REPO=
INBOX=
LATEST=${INBOX}'/latest.txt'
DOWNLOADS=
SELF=
GITBOX=${REPO}'/'${SELF}

CWD=${PWD}

push() {
    git add --all
    git diff --quiet HEAD -- ${1} || git commit ${1} -qm 'bot' && git push -q origin main
}

quit() {
    cd ${CWD} ; tput cnorm ; tput sgr0 ; tput rmcup ; exit ${1}
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
local POSTBOX=${REPO}'/'${TO}

[ ! -d "${POSTBOX}" ] && return 1

if [ -f "${2}" ]; then
    local URL=`curl -sfF "file=@${2}" https://file.io/?expires=2 | grep -o "https://file.io/[A-Za-z0-9]*"`
    [ -z "${URL}" ] && return 2
    card '${URL} -o ${2##*/}' .dl
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
        DOWNLOADED=`xargs curl -sfw %{filename_effective}'\n' < ${FILE}`
        local DIR='${DOWNLOADS}/${FROM}/'
        [ ! -d "${DIR}"] mkdir ${DIR}
        [ -e "${DOWNLOADED}"] mv --backup=numbered ${DOWNLOADED} ${DIR}
    esac
    git rm -q ${FILE}
done
fi
}

daemon() {
while true ; do 
    pull
    push
done
}



##########################################################################
########################  TEST  ##########################################
daemon &
tput smcup && tput clear


ui() {
read -p 'Whom:' CORRESPONDENT && tput clear
tput cud 5
CHAT=${INBOX}'/'${CORRESPONDENT}'.txt'
[ -e "${CHAT}"] && cat ${CHAT}
}