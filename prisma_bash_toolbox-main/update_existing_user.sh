#!/bin/bash
# Requires jq to be installed
# Author Kyle Butler

source ./secrets/secrets
source ./func/func.sh

# This will update an existing user. Can be used to unlock an account, change name, timezone, allow access keys, or disable an existing user from the Prisma Cloud Console. 


USER_EMAIL="<EMAIL_ADDRESS_OF_USER>"
USER_FIRSTNAME="<FIRST_NAME_OF_USER>"
USER_LASTNAME="<LAST_NAME_OF_USER>"
# Enables or disables account
ENABLED="<true_or_false>"
# Allows users to create programmatic access keys
KEYS_ALLOWED="<true_or_false>"
# Adjust timezone as you see fit. 
TIME_ZONE="America/Los_Angeles"





#### NO EDITS NEEDED BELOW

pce-var-check

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


PC_JWT=$(printf %s "$PC_JWT_RESPONSE" | jq -r '.token' )


ROLE_JSON=$(curl --request GET \
                       --url "$PC_APIURL/v2/user/{$USER_EMAIL}" \
                       --header "x-redlock-auth: $PC_JWT")

DEFAULT_ROLE_ID=$(printf %s $ROLE_JSON | jq -r '.defaultRoleId')

declare -a ROLE_ID_ARRAY=$(printf %s $ROLE_JSON | jq -r '.roleIds[]' )

# To add more roles simply add lines under the roleId section with more "%s"
# If you do make sure to add the indexes to the variable ${ROLE_ID_ARRAY[<INDEX_NUMBER_HERE>]} in the $USER_PAYLOAD_VAR

USER_PAYLOAD=$(cat <<EOF
{
  "email": "$USER_EMAIL",
  "firstName": "$USER_FIRSTNAME",
  "lastName": "$USER_LASTNAME",
  "enabled": "$ENABLED",
  "accessKeysAllowed": "$KEYS_ALLOWED",
  "defaultRoleId": "$DEFAULT_ROLE_ID",
  "roleIds": [
    "${ROLE_ID_ARRAY[0]}"
  ],
  "timeZone": "$TIME_ZONE"
}
EOF
)


curl --request PUT \
     --url "$PC_APIURL/v2/user/{$CTF_USER}" \
     --header 'content-type: application/json' \
     --header "x-redlock-auth: $PC_JWT" \
     --data "$USER_PAYLOAD"

quick_check "/v2/user/{$CTF_USER}"

exit
