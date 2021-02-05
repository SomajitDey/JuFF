#Display text with real-life updates. The moment user presses any key 
#even if that key is an arrow key, go back to static view.
trap exit INT 
unset REPLY
tput civis
while [ -z "${REPLY}" ]; do
tput clear
timeout 0.5 tail -f text
read -st 0.5 -n 1
done
tput clear
sed -n p text
tput cnorm