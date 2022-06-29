#!/usr/bin/env bash
# Written by Kyle Butler
# Shows how many events are performed by a user vs automation task

# choose aws, azure, gcp, oci....capitilization matters
CLOUD_TYPE="aws"
# choose hour, day, month, year
TIME_UNIT="hour"
# choose integer amount
TIME_AMOUNT="24"



########### END OF USER CONFIG ############################
pce-var-check

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

quick_check "/login"


PC_JWT=$(printf %s "$PC_JWT_RESPONSE" | jq -r '.token' )

EVENT_SEARCH=$(cat <<EOF
{
  "query":"event from cloud.audit_logs where cloud.type = '$CLOUD_TYPE'",
  "timeRange":{
     "type":"relative",
     "value":{
        "unit":"$TIME_UNIT",
        "amount":$TIME_AMOUNT
     }
  }
}
EOF
)

EVENT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/search/event" \
                       --header 'content-type: application/json; charset=UTF-8' \
                       --header "x-redlock-auth: $PC_JWT" \
                       --data "$EVENT_SEARCH")

quick_check "/search/event"

NUMBER_OF_EVENTS=$(printf '%s' "$EVENT_RESPONSE" | jq '.data.items[] | .id' | wc -l)
NUMBER_OF_MANUAL_EVENTS=$(printf '%s' "$EVENT_RESPONSE" | jq '.data.items[]| select(.ip != null) | .ip ' | wc -l)
NUMBER_OF_AUTOMATED_EVENTS=$(printf '%s' "$EVENT_RESPONSE" | jq '.data.items[]| select(.ip == null) | .ip ' | wc -l)
PERCENTAGE_MANUAL=$(bc -l <<< "($NUMBER_OF_MANUAL_EVENTS/$NUMBER_OF_EVENTS)* 100")
PERCENTAGE_AUTOMATED=$(bc -l <<< "($NUMBER_OF_AUTOMATED_EVENTS/$NUMBER_OF_EVENTS)* 100")

METRICS_JSON=$(cat <<EOF
{
 "cloudType": "$CLOUD_TYPE",
 "reportTimeUnit": "$TIME_UNIT",
 "reportTimeAmount": "$TIME_AMOUNT",
 "manualEvents": "$NUMBER_OF_MANUAL_EVENTS",
 "automatedEvents": "$NUMBER_OF_AUTOMATED_EVENTS",
 "totalEvents": "$NUMBER_OF_EVENTS",
 "percentageEventsManual": "$PERCENTAGE_MANUAL",
 "percentageEventsAutomated": "$PERCENTAGE_AUTOMATED"
}
EOF
)



printf '%s' "$METRICS_JSON" | jq
