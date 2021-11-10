#!/bin/sh
# author Kyle Butler
# for CI 
# downloads the twistcli tool from the Prisma Cloud Compute side of the console. 

source ./secrets/secrets

wget --header "Authorization: Basic $(echo -n $PC_ACCESSKEY:$PC_SECRETKEY | base64 | tr -d '\n')" "$TL_CONSOLE/api/v1/util/twistcli"
chmod a+x ./twistcli

exit
