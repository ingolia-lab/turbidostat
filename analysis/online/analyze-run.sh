#!/bin/bash

export WWWPATH="/PATH/TO/WWW"
export ANALYSIS="/PATH/TO/analysis-turbidostat.R"

if [[ "$#" != 1 ]]; then
    echo "Usage: $0 <EXPT-DIR>"
    exit 1
fi

export EXPTDIR="$1"
COPIED="${EXPTDIR}/copied.txt"
ANALYZED="${EXPTDIR}/analyzed.txt"

if [[ ! -d "${EXPTDIR}" ]]; then
    echo "$0: No experiment directory ${EXPTDIR}"
    exit 1
elif [[ ! -e "${COPIED}" ]]; then
    echo "$0: No sential file ${COPIED}"
    exit 1
fi

while true
do
    if [[ "${COPIED}" -nt "${ANALYZED}" ]];
    then
        R --no-save < "${ANALYSIS}"
        touch "${ANALYZED}"
    fi
    sleep 1
done
