#!/usr/bin/env -S bash -i
source_me(){
  for key in {a..z}; do
    echo bind -x \'\"${key}\":READLINE_LINE=\$\{READLINE_LINE:0:READLINE_POINT\}${key}\$\{READLINE_LINE:\$\(\(READLINE_POINT++\)\):\$\(\(\$\{#READLINE_LINE\}-\$\(\(READLINE_POINT-1\)\)\)\)\}\;echo hi\' >> source_me
  done
  . ./source_me
  rm ./source_me
  alias read="read -er"
} 2>/dev/null
source_me
read
echo You typed: "$REPLY"
