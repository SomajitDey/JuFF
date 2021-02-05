#Display text with real-life updates. The moment user presses any key 
#even if that key is an arrow key, go back to static view.
trap date INT 
unset REPLY
tput civis
while [ -z "${REPLY}" ]; do
tput clear
timeout 0.5 tail -fn $2 $1
read -st 0.5 -n 1
done
tput clear
sed -n p $1
tput cnorm
echo ${REPLY} | grep ^[A-Za-z0-9] >/dev/null
if [ $? == 0 ]; then
read -p 'Type : '${REPLY} NEXT
echo ${NEXT} | grep ^[A-Za-z0-9] >/dev/null
if [ $? == 0 ]; then 
REPLY=${REPLY}${NEXT}
echo ${REPLY} 'done'
fi
fi
