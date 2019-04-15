#!/bin/bash

# Run "sync-runs.sh" in the base run directory

# The contents of the base directory will be copied directly into the
# path specified in DEST -- no sub-directory will be created.

DEST="USER@HOST:PATH/TO/RUNS"

while true
do
    rsync -rvz "./" "${DEST}"
    sleep 60
done
