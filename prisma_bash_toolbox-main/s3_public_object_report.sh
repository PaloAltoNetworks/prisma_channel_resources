#!/usr/bin/env bash
# Written by Kyle Butler
# Shows how many events are performed by a user vs automation task



# USER ASSIGNED VARS

# found under settings > licensing
TENANT_ID="2312312321891921"

# time unit choose: hour, day, week, month, year
TIME_UNIT="year"

# integer number of the time units above
TIME_AMOUNT="1"

########### END OF USER CONFIG ############################

REPORT_DATE=$(date  +%m_%d_%y)

JSON_LOCATION="./temp"

REPORTS_LOCATION="./reports"

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

INVENTORY_REQUEST=$(cat <<EOF
{
  "detailed": true,
  "fields": [
    "objectId",
    "objectOwner"
  ],
  "limit": 0,
  "tableLevel": 4,
  "timeRange": {
    "relativeTimeType": "BACKWARD",
    "type": "relative",
    "value": {
      "amount": $TIME_AMOUNT,
      "unit": "$TIME_UNIT"
    }
  }
}
EOF
)

INVENTORY_RESPONSE=$(curl --request POST \
                          --url "$PC_APIURL/dlp/api/v1/inventory/objects/aggregate" \
                          --header 'content-type: application/json; charset=UTF-8' \
                          --header "x-redlock-auth: $PC_JWT" \
                          --data "$INVENTORY_REQUEST")


quick_check "/dlp/api/v1/inventory/objects/aggregate"

OBJECT_IDS=( $(printf '%s' "$INVENTORY_RESPONSE" | jq -r '.[] | select(.objectExposure == "public" ) | .objectId') )

if [ -z $OBJECT_IDS ]; then
  printf '%s\n' "No public objects found, exiting script"
  exit
fi


for ID in "${!OBJECT_IDS[@]}"; do \

OBJECT_DETAILS_PAYLOAD=$(cat <<EOF
{
  "objectId": "${OBJECT_IDS[ID]}",
  "tenantId": "$TENANT_ID"
}
EOF
)


curl -s --request POST \
     --url "$PC_APIURL/dlp/api/v1/inventory/object/details" \
     --header 'content-type: application/json; charset=UTF-8' \
     --header "x-redlock-auth: $PC_JWT" \
     --data "$OBJECT_DETAILS_PAYLOAD" >> "$JSON_LOCATION/object.json" &

done



printf '%s' "$INVENTORY_RESPONSE" | jq -r '[.[]  |select(.objectExposure=="public")] | map({cloudType, accountId, accountName, regionName, serviceName, resourceName, publicResource, objectId, objectName, objectExposure, objectOwner, contentType, dataProfiles, dataPatterns, malware, rrn, objectInformation: [(.objectName as $objectName | $objectData |..|select(.objectName? and .objectName==$objectName))]})' --slurpfile objectData "$JSON_LOCATION/object.json" | jq -r '[.[] | select(.accountId==.objectInformation[].awsAccountId ) |{cloudType, accountId, accountName, regionName, serviceName, resourceName, publicResource, objectId, objectName, objectExposure, objectOwner, contentType, dataProfiles, dataPatterns, malware, rrn, url: .objectInformation[].objectUrl } ] | map({cloudType, accountId, accountName, regionName, serviceName, resourceName, serviceName, resourceName, publicResource, objectId, objectName, objectExposure, objectowner, contentType, dataProfiles: .dataProfiles[], dataPatterns: .dataPatterns[], malware, rrn, url}) |(first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[]| @csv' > "$REPORTS_LOCATION/s3_object_report_$REPORT_DATE.csv"


printf '\n\n%s\n\n%s' "All done! Your report is in the reports directory saved as s3_object_report_$REPORT_DATE.csv" \
                      "cleaning temp json folder"


{
  rm "$JSON_LOCATION/*.json"
}


exit
