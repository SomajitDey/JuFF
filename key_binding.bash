# Sourcing this file will automatically set all the key-bindings
# One way to do it is include this sourcing in an alias: alias go="source ./test.bash" in .bashrc
(
for key in {a..z}; do
echo bind -x \'\"${key}\":READLINE_LINE=\$\{READLINE_LINE:0:READLINE_POINT\}${key}\$\{READLINE_LINE:\$\(\(READLINE_POINT++\)\):\$\(\(\$\{#READLINE_LINE\}-\$\(\(READLINE_POINT-1\)\)\)\)\}\;echo hi\' >> source_me
done
. ./source_me
read -er
)
