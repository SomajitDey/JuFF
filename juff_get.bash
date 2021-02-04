#ls -t1 test_test@email.com | grep -o ^[A-Za-z0-9.]*_[a-z0-9.]*[@][a-z0-9.]*[a-z0-9.]*
#FROMDO: READING FIRST WORD ONLY
#Send text and files:: Take input and push

REPO=~/juff-repo
cd ${REPO}

if [ -z ${1} ]; then
    echo -n 'Type sender name_email: '
    read FROM REPLY
else
    FROM=${1}
fi
while [ ! -d "${FROM}" ]; do
    echo -n 'User not found. Retype. Press Enter to cancel: '
    read FROM
    [ -z "${FROM}" ] && exit
done

TO_NAME=`git config --global user.name`
TO_EMAIL=`git config --global user.email`
if [ -z "${TO_NAME}" ]; then
    echo -n 'Set your public name: '
    read TO_NAME REPLY
    git config --global user.name ${TO_NAME}
fi
if [ -z "${TO_NAME}" ]; then
    echo -n 'Set your public email: '
    read TO_EMAIL REPLY
    git config --global user.email ${TO_EMAIL}
fi    
TO=${TO_NAME}'_'${TO_EMAIL}


pull() {
    git pull
}

GIT_INBOX=${REPO}'/'${TO}
#LIST1=~/sender.list
#LIST2=~/messages.list
#ls -t1 ${GIT_INBOX} | grep -o ^[A-Za-z0-9.]*_[a-z0-9.]*[@][a-z0-9.]*[a-z0-9.]* > ${LIST1}
#ls -t1 ${GIT_INBOX} > ${LIST2}

INBOX=~/inbox/
LATEST=${INBOX}'/latest.txt'
mkdir -p ${INBOX}
#Is not the following glob expansion making it slow
if [ `ls ${GIT_INBOX}/*.txt` ]; then
for FILE in ${GIT_INBOX}/*.txt; do
    xargs curl -sfw "\n" < ${FILE} >> ${LATEST}
    git rm ${FILE}
done
fi
cat ${LATEST}
push() {
    git add --all
    git diff-index --quiet HEAD || git commit -m 'Commit by juff bot' && git push
#    if git commit --dry-run -am 'dry-run'; then
#        git commit --allow-empty -m 'Commit by juff bot'
#    fi
}
while ! push ; do
    pull
done
