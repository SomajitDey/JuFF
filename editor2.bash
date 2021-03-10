#The following code is a basic text editor for chatting
#Delete last typed character using Backspace, otherwise just type
#Returns on pressing Enter

#Using this avoids use of curses library, as another process
#can be interleafed to show other outputs, such as notifications
#when the user is still typing

trap 'tput rmcup && exit' INT
tput smcup
#tput civis
save_stty_state="$(stty -g)"  # Involvement of stty is optional.
stty erase $'\x7f'  #This may be default but we take no chances. Hex 7f=^?
char_count=0
until read -rsn1 && [[ -z ${REPLY} ]]; do
  read -rsn256 -t 0.01 trail
  case "${REPLY}${trail}" in
  $'\e[H') REPLY=$'\r' ;; # Home key = Carriage return
  $'\e[F') REPLY=$'\n' ;; # End key = New line
  $'\e[3~') REPLY="$(tput cuf 1)\b$(tput dch 1)"
            ((char_count--));; # Delete key
  $'\e[2~') REPLY="$(tput el1 ; tput el)\r"
            char_count=0 ;; # Insert key
  $'\x7f') REPLY="\b$(tput ech 1)"
           ((char_count--));; # Backspace key
  $'\e[C') REPLY="$(tput cuf 1)" ;; # Right arrow key
  $'\e[D') REPLY="$(tput cub 1)" ;; # Left arrow key
  *) REPLY="$(tput ich 1)${REPLY}"
     ((char_count++));; # Insert character
  esac
  prepend="${prepend}${REPLY}"
  tput home ; tput ed
  echo -en "${prepend}"
done
stty "${save_stty_state}" # Involvement of stty is optional.
#tput cnorm
tput rmcup
echo -e "You typed:\n${prepend}"
echo -e "Character count = ${char_count}"
(( char_count>0 ))