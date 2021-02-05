backend() {
if [ ${PAGE} == '1' ]; then
    if [ -n ${MESSAGE} ]; then
        CORRESPONDENT=${MESSAGE}
        PAGE='2'
    else
        quit 1
    fi
else
    if [ -n ${MESSAGE} ]; then
        MESSAGE=${MESSAGE}  #${MESSAGE} should be INPUT
        PAGE='2'
        post ${CORRESPONDENT} ${MESSAGE}
    else
        PAGE='1'
    fi
fi
}