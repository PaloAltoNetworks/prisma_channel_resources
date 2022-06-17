#!/bin/bash 
# requires jq
# written by Kyle Butler
# shows all the policies for a particular cloud provider

source ./secrets/secrets
source ./func/func.sh

pce-var-check

CLOUD_TYPE="azure"
REPORTS_DIR=./reports

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

PC_JWT=$(printf '%s' "$PC_JWT_RESPONSE" | jq -r '.token' )


POLICY_INFO_RESPONSE=$(curl --request GET \
                            --url "$PC_APIURL/v2/policy" \
                            --header "x-redlock-auth: $PC_JWT")

quick_check "/v2/policy"

printf '%s' "$POLICY_INFO_RESPONSE" | jq --arg cloudType "$CLOUD_TYPE" -r '[.[] | {cloudType: .cloudType, name: .name, policyType: .policyType, enabled: .enabled} | select( .cloudType == $cloudType )] | map({cloudType, name, policyType, enabled}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' > "$REPORTS_DIR/policy_$CLOUD_TYPE.csv"
exit
