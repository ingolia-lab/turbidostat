#!/bin/bash

DEST="USER@HOST:PATH/TO/DIR"

SUBDIR=`basename $PWD`

while true
do
    touch copied.txt
    scp -r . "${DEST}/${SUBDIR}"
    sleep 60
done
