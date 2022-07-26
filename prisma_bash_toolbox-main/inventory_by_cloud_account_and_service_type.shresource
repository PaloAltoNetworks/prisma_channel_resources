#!/usr/bin/env bash
# Written by Kyle Butler
# Pulls the Asset Inventory Report in Prisma Cloud as json. Transform to csv. Pulls Inventory grouped on cloud service and cloud account

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

INVENTORY_FILTER_PAYLOAD=$(cat <<EOF
{
  "filters": [],
  "groupBy": [
    "cloud.service",
    "cloud.account"
  ],
  "timeRange": {
    "type": "to_now",
    "value": "epoch"
  }
}
EOF
)

INVENTORY_RESPONSE=$(curl --request POST \
                          --url "$PC_APIURL/v2/inventory" \
                          --header 'content-type: application/json; charset=UTF-8' \
                          --header "x-redlock-auth: $PC_JWT" \
                          --data "$INVENTORY_FILTER_PAYLOAD")

quick_check "/api/v2/inventory"

REPORT_DATE=$(date  +%m_%d_%y)

printf '%s' "$INVENTORY_RESPONSE" | jq -r '.groupedAggregates | map({cloudTypeName, serviceName, accountName, accountId, failedResources, passedResources, totalResources, highSeverityFailedResources, mediumSeverityFailedResources, lowSeverityFailedResources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' > "./reports/asset_inventory_by_service_and_accounts_$REPORT_DATE.csv"

printf '\n%s\n' "All done! Your report is in the reports directory saved as: asset_inventory_by_service_and_accounts_$REPORT_DATE.csv"

exit
