#!/bin/sh
# Author Kyle Butler
# For CI pipeline
# Scans VM Image as it's being built using something like packer
# Ideally done before using the image in production
# Add twistcli to runner prior to executing script

source ./secrets/secrets  

# must be run as root user
./twistcli hosts scan --address $TL_CONSOLE -u $PC_ACCESSKEY -p $PC_SECRETKEY --details --skip-docker

exit
