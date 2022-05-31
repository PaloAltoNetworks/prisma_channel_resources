#!/bin/sh
# author Kyle Butler
# for CI 
# downloads the twistcli tool from the Prisma Cloud Compute side of the console. 

source ./secrets/secrets
source ./func/func.sh


tl-var-check

wget --header "Authorization: Basic $(echo -n $TL_USER:$TL_PASSWORD | base64 | tr -d '\n')" "$TL_CONSOLE/api/v1/util/twistcli"

quick_check "/api/v1/util/twistcli"

chmod a+x ./twistcli

exit
