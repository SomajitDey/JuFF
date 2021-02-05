trap exit INT 
unset REPLY
while [ -z "${REPLY}" ]; do
tput clear
timeout 1.5 sed -n 5,10p text
read -t 0.5 -n 1
done
echo done