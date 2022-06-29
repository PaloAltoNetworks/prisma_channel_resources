#!/usr/bin/env bash
# written by Kyle Butler
# requires jq to be installed

# retrieves the variables from the secrets file
source ./secrets/secrets
source ./func/func.sh

# Ensures proper formatting of json in bash

tl-var-check

AUTH_PAYLOAD=$(cat <<EOF
{"username": "$TL_USER", "password": "$TL_PASSWORD"}
EOF
)

# checks request, if it fails will echo the error code.·
quick_check () {
  res=$?
  if [ $res -eq 0 ]; then
    echo "$1 request succeeded"
  else
    echo "$1 request failed error code: $res" >&2
    exit 1
  fi
}


# authenticates to the prisma compute console using the access key and secret key. If using a self-signed cert with a compute on-prem version, add -k to the curl command.·
PRISMA_COMPUTE_API_AUTH_RESPONSE=$(curl --header "Content-Type: application/json" \
                                        --request POST \
                                        --data-raw "$AUTH_PAYLOAD" \
                                        --url $TL_CONSOLE/api/v1/authenticate )

quick_check "/api/v1/authenticate"

#create some space
echo
echo
echo "API token is:"

printf %s $PRISMA_COMPUTE_API_AUTH_RESPONSE | jq -r '.token'
