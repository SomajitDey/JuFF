#The following code is a basic text editor for chatting
#Delete last typed character using Backspace, otherwise just type
#Returns on pressing Enter
#Supports yanking/pasting previously copied text
#Supports backslash escaped characters, such as \n

#Using this avoids use of curses library, as another process
#can be interleafed to show other outputs, such as notifications
#when the user is still typing

trap break INT
tput smcup
tput civis
save_stty_state="$(stty -g)"  # Involvement of stty is optional.
stty erase $'\x7f'  #This may be default but we take no chances. Hex 7f=^?
until read -p "${prepend}" -rst 0.1 -n 256 ; do
  prepend="${prepend}${REPLY}"
  prepend="${prepend//$'\x7f'/$'\b' $'\b'}"
  tput home
done
stty "${save_stty_state}" # Involvement of stty is optional.
tput cnorm
tput rmcup
echo -e "You typed:\n${prepend}"