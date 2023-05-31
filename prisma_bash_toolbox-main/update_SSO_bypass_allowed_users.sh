#!/usr/bin/env bash
# requires jq and curl
# must have a sysadmin role in Prisma Cloud to work
# adds a user to the SSO Bypass list in case people have made a mistake in the SSO configuration section of the platform
# author Kyle Butler

# assign user email to variable below

USER_EMAIL="<YOUR_USER_EMAIL>"

source ./secrets/secrets
source ./func/func.sh

AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)


PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")



PC_JWT=$(printf %s "$PC_JWT_RESPONSE" | jq -r '.token' )


curl -L -X PUT \
        --url "$PC_APIURL/user/saml/bypass" \
        --header 'Content-Type: application/json' \
        --header "x-redlock-auth: $PC_JWT" \
        --data-raw "[ $USER_EMAIL ]"
