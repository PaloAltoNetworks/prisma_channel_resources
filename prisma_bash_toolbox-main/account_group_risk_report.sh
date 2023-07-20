#!/usr/bin/env bash
# Requires jq to be installed
# Author Kyle Butler
# Creates a Risk report in the Prisma Cloud Console and selects the cloud accounts associated to the account group for a specific $CLOUD_TYPE (aws, gcp, azure, oci, alibaba)
# Recommending that once it's created you edit the report and look over the time zones and frequency. I've defaulted this to US East time. This can be changed after the report is created in the console.
# Solves the issue of filters applying when creating the report

source ./secrets/secrets
source ./func/func.sh

#################################################################-USER CONFIG-#####################################################

REPORT_NAME="<title_for_report>"

# 1-24 corresponds to the hour of day to send report. US East timezone. Example below is 7 AM ET
HOUR_ET="7"
MINUTE_ET="0"

# Pick day(s) to send report. For monday and tuesday the value should be "MO,TU" etc. Available options: "MO,SU,TU,WE,TH,FR,SA"
REPORT_DAY="MO"

# gcp, aws, or azure
CLOUD_TYPE="aws"

# account group name exactly as it appears in the Prisma Console
ACCOUNT_GROUP_FOR_REPORT="<account_group_name>"

# Put a space between each email address and wrap each email address in quotes. Example ( "email1@email.com" "email2@email.com")
EMAIL_ARRAY=( "<email_1>" "<email_2>")

##############################################################-END OF USER CONFIG-##################################################

REPORT_START_DATE=$(date +%Y%m01T000000)


AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)


PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")




PC_JWT=$(printf %s "$PC_JWT_RESPONSE" | jq -r '.token')

ACCOUNT_GROUP_RESPONSE=$(curl --request GET \
                              --url "$PC_APIURL/cloud/group" \
                              --header 'Accept: application/json; charset=UTF-8' \
                              --header "x-redlock-auth: $PC_JWT")

ACCOUNT_GROUP_ID=$(printf '%s' "$ACCOUNT_GROUP_RESPONSE" |  jq -r --arg account_group_name "$ACCOUNT_GROUP_FOR_REPORT" '.[] | select(.name == $account_group_name ) | .id ')
ACCOUNT_ID_ARRAY=($(printf '%s' "$ACCOUNT_GROUP_RESPONSE" | jq --arg account_group_name "$ACCOUNT_GROUP_FOR_REPORT" --arg cloud_type "$CLOUD_TYPE" '.[] | select(.name == $account_group_name ) | .accounts[] | select(.type == $cloud_type)| .id'))

ACCOUNT_GROUP_REPORT_REQUEST_BODY=$(cat <<EOF
{
  "cloudType": "$CLOUD_TYPE",
  "locale": "en_us",
  "name": "$REPORT_NAME",
  "target": {
    "accountGroups": [
      "$ACCOUNT_GROUP_ID"
    ],
    "accounts": [
      $(printf '%s,\n' "${ACCOUNT_ID_ARRAY[@]}" | sed '$s/,$//')
    ],
    "complianceStandardIds": null,
    "compressionEnabled": null,
    "notifyTo": [
    $(printf '"%s",\n' "${EMAIL_ARRAY[@]}" | sed '$s/,$//')
    ],
    "regions": [],
    "resourceGroups": [],
    "schedule": "DTSTART;TZID=America/New_York:$REPORT_START_DATE\nBYHOUR=$HOUR_ET;BYMINUTE=$MINUTE_ET;BYSECOND=0;FREQ=WEEKLY;INTERVAL=1;BYDAY=$REPORT_DAY",
    "timeRange": {
      "type": "to_now",
      "value": "epoch"
    }
  },
  "type": "RIS"
}
EOF
)

curl --request POST \
     --url "$PC_APIURL/alert/report" \
     --header 'accept: application/json' \
     --header 'content-type: application/json' \
     --header "x-redlock-auth: $PC_JWT" \
     --data-raw "$ACCOUNT_GROUP_REPORT_REQUEST_BODY"
