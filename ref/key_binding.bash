#!/usr/bin/env bash
# Alternate shebang##!/usr/bin/env -S bash -i
source_me(){
  for key in {a..z}; do
    echo bind -x \'\"${key}\":READLINE_LINE=\$\{READLINE_LINE:0:READLINE_POINT\}${key}\$\{READLINE_LINE:\$\(\(READLINE_POINT++\)\):\$\(\(\$\{#READLINE_LINE\}-\$\(\(READLINE_POINT-1\)\)\)\)\}\;echo hi\' >> source_me
  done
} 
# Use of alias is deprecated, use shell function instead
shopt -s expand_aliases
alias go="read -er"
source_me
. ./source_me 2>/dev/null
go
echo You typed: "$REPLY"
rm ./source_me
