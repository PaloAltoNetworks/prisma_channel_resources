#!/bin/sh
# author Kyle Butler
# for CI 
# downloads the twistcli tool from the Prisma Cloud Compute side of the console. 

source ./secrets/secrets


quick_check () {
  res=$?
  if [ $res -eq 0 ]; then
    echo "$1 request succeeded"
  else
    echo "$1 request failed error code: $res" >&2
    exit 1
  fi
}

wget --header "Authorization: Basic $(echo -n $PC_ACCESSKEY:$PC_SECRETKEY | base64 | tr -d '\n')" "$TL_CONSOLE/api/v1/util/twistcli"

quick_check "/api/v1/util/twistcli"

chmod a+x ./twistcli

exit
