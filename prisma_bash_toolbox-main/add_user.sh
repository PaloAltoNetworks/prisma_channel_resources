#!/bin/bash
# Requires jq to be installed
# Author Kyle Butler


source ./secrets/secrets
source ./func/func.sh


# Username information. The goal here is to pull this information and assign to a these variables using a different api call. 
PC_USER_FIRSTNAME="<FIRSTNAME>"
PC_USER_LASTNAME="<LASTNAME>"
PC_USER_ROLE="<PUT_THE_NAME_OF_THE_USER_ROLE_HERE>"
PC_USER_EMAIL="<EMAIL_HERE>"
PC_USER_TIMEZONE="America/New_York"
PC_USER_KEY_EXPIRATION_DATE="0"
PC_USER_ACCESSKEY_ALLOW="true"
PC_USER_ACCESSKEY_NAME="$PC_USER_FIRSTNAME accesskey"
PC_USER_KEY_EXPIRATION="false"
PC_USERNAME="$PC_USER_EMAIL"


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



PC_USER_ROLES=$(curl --request GET \
                     --url "$PC_APIURL/user/role" \
                     --header "x-redlock-auth: ${PC_JWT}")

quick_check "/user/role"

PC_USER_ROLE_ID=$(printf %s "${PC_USER_ROLES}" | jq '.[] | {id: .id, name: .name}' | jq -r '.name, .id'| awk "/""${PC_USER_ROLE}""/{getline;print}")

PC_ROLE_PAYLOAD=$(cat <<EOF
{
  "accessKeyExpiration": "$PC_USER_KEY_EXPIRATION_DATE",
  "accessKeyName": "$PC_USER_KEY_NAME",
  "accessKeysAllowed": "$PC_USER_ACCESSKEY_ALLOW",
  "defaultRoleId": "$PC_USER_ROLE_ID",
  "email": "$PC_USER_EMAIL",
  "enableKeyExpiration": "$PC_USER_KEY_EXPIRATION",
  "firstName": "$PC_USER_FIRSTNAME",
  "lastName": "$PC_USER_LASTNAME",
  "roleIds": [
    "$PC_USER_ROLE_ID"
  ],
  "timeZone": "$PC_USER_TIMEZONE",
  "type": "USER_ACCOUNT",
  "username": "$PC_USERNAME"
}
EOF
)

# This adds the new user
curl --request POST \
     --url "$PC_APIURL/v2/user" \
     --header "Content-Type: application/json" \
     --header "x-redlock-auth: $PC_JWT" \
     --data-raw "$PC_ROLE_PAYLOAD"

quick_check "/v2/user"

exit
