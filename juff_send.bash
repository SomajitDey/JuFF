#TODO: READING FIRST WORD ONLY
#Send text and files:: Take input and push

REPO=~/juff-repo
cd ${REPO}

if [ -z ${1} ]; then
    echo -n 'Type receiver name_email: '
    read TO REPLY
else
    TO=${1}
fi
while [ ! -d "${TO}" ]; do
    echo -n 'User not found. Retype. Press Enter to cancel: '
    read TO
    [ -z "${TO}" ] && exit
done

FROM_NAME=`git config --global user.name`
FROM_EMAIL=`git config --global user.email`
if [ -z "${FROM_NAME}" ]; then
    echo -n 'Set your public name: '
    read FROM_NAME REPLY
    git config --global user.name ${FROM_NAME}
fi
if [ -z "${FROM_NAME}" ]; then
    echo -n 'Set your public email: '
    read FROM_EMAIL REPLY
    git config --global user.email ${FROM_EMAIL}
fi    
FROM=${FROM_NAME}'_'${FROM_EMAIL}

echo -n 'Type message here: '
read MESSAGE

if [ -f "$MESSAGE" ]; then
    LINK=`curl -sF "file=@${MESSAGE}" https://file.io/?expires=2 | grep -o "https://file.io/[A-Za-z0-9]*"`
    EXT='.dl'
else
    LINK=`curl -s --data "text=${MESSAGE}" https://file.io | grep -o "https://file.io/[A-Za-z0-9]*"`
    EXT='.txt'
fi

# Define a timestamp function
timestamp() {
  date +_%s # current time in seconds since Unix epoch
}
echo Creating PUSH_CARD
PUSH_CARD=${TO}'/'${FROM}`timestamp`${EXT}
echo ${PUSH_CARD}
echo ${LINK} > ${PUSH_CARD}
echo 'Done. Enter' $LINK
read

push() {
    git add --all
    git commit -m 'Commit by juff bot'
    git push
}
pull() {
    git pull
}
while ! push ; do
    pull
done 
