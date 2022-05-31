#!/bin/sh
# Author Kyle Butler
# For CI pipeline
# Scans container after being built from a Dockerfile
# Ideally done before checking image into private container registry
# Add twistcli to runner prior to executing script

source ./secrets/secrets
source ./func/func.sh

# change to correct tag

IMAGE_TAG="python:latest"

tl-var-check
# ./twistcli images scan --podman or --podman-path PATH depending on install --address $TL_CONSOLE -u $TL_USER -p $TL_PASSWORD --details $IMAGE_TAG
./twistcli images scan --address $TL_CONSOLE -u $TL_USER -p $TL_PASSWORD --details $IMAGE_TAG    

exit
