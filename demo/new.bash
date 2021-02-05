trap exit INT 
unset REPLY
while [ -z "${REPLY}" ]; do
tput clear
timeout 0.5 tail -fn 100 text
read -t 0.5 -n 1
done
echo done