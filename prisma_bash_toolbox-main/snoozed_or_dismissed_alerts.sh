#!/usr/bin/env bash
#------------------------------------------------------------------------------------------------------------------#
# Written By dschmidt@paloaltonetworks.com
#
# REQUIREMENTS:
# Requires jq to be installed: 'sudo apt-get install jq'


# SCRIPT WILL REPORT ALERTS THAT HAVE BEEN DISMISSED OR SNOOZED OVER THE SPECIFIED TIME PERIOD

###
# User Configuration Section
###
TIME_AMOUNT="3" # Represents amount of time (e.g. 3 months).  Valid values: Any positive integer
UNIT="month" # Time unit to search on. Valid values: minute|hour|day|week|month|year

#### NO EDITS NEEDED BELOW
source ./secrets/secrets
source ./func/func.sh

pce-var-check

AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)


PC_JWT_RESPONSE=$(curl -s --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")

quick_check "/login"

PC_JWT=$(printf %s "$PC_JWT_RESPONSE" | jq -r '.token' )

REPORT_DATE=$(date  +%m_%d_%y)

quick_check "/v2/alert"

payload="{\"detailed\":false,\"filters\":[{\"name\":\"timeRange.type\",\"operator\":\"=\",\"value\":\"ALERT_OPENED\"},{\"name\":\"alert.status\",\"operator\":\"=\",\"value\":\"snoozed\"},{\"name\":\"alert.status\",\"operator\":\"=\",\"value\":\"dismissed\"}],\"timeRange\":{\"type\":\"relative\",\"value\":{\"amount\":\"$TIME_AMOUNT\",\"unit\":\"$UNIT\"}}}"

# get the list of alerts that were snoozed or dismissed
curl -s --request POST \
        --url "$PC_APIURL/v2/alert" \
        --data "$payload" \
        -H 'Accept: */*' \
        -H 'Content-Type: application/json; charset=UTF-8' \
        -H "x-redlock-auth: $PC_JWT" | jq '.items[] | { id,status,dismissedBy,dismissalNote,dismissalUntilTs,dismissalDuration,policyId } | .dismissalUntilTs |= ( . / 1000 | strftime("%Y-%m-%d %H:%M:%S UTC") )' | jq -s > ./temp/with_raw_policy_ids.json

# reconcile the policy id
jq -r '.[].policyId' ./temp/with_raw_policy_ids.json | xargs -i \
        curl -s -L -X GET "$PC_APIURL/policy/{}" \
        -H 'Accept: application/json; charset=UTF-8' \
        -H "x-redlock-auth: $PC_JWT" | jq '. | [ { name, policyId } ]' > ./temp/policy_id_to_name_mapping.json


# set the csv headers
echo "id,status,dismissedBy,dismissalNote,dismissalUntilTs,dismissalDuration,policyId,policyName" > ./reports/snoozed_or_dismissed_$REPORT_DATE.csv

# add the csv data
jq -r --slurp 'flatten | group_by( .policyId ) | map(add) | .[] | [.id,.status,.dismissedBy,.dismissalNote,.dismissalUntilTs,.dismissalDuration,.policyId,.name] | @csv' ./temp/with_raw_policy_ids.json ./temp/policy_id_to_name_mapping.json >> ./reports/snoozed_or_dismissed_$REPORT_DATE.csv

# get rid of the temp files
rm -rf ./temp/*.json

# great success!
printf '\n%s\n' "Process completed! Snoozed alerts for the past 3 months is in a report in the ./reports directory named: snoozed_or_dismissed_$REPORT_DATE.csv"
