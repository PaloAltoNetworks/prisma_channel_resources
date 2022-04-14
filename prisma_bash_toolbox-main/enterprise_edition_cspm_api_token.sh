#!/bin/bash
# Requires jq to be installed
# Author Kyle Butler


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

AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)


PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")

quick_check "/login"


#create some space
echo
echo
echo "API token is:"

printf %s "$PC_JWT_RESPONSE" | jq -r '.token' 
