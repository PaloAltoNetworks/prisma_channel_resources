#!/usr/bin/env bash

# Steve Brown ([stebrown@paloaltonetworks.com](mailto:stebrown@paloaltonetworks.com))
# Cloud Discovery Report  1/12/23
# Community work product, not supported nor maintained by Palo Alto Networks.
# Ensure that $TL_USER, $TL_PASSWORD, and $TL_CONSOLE variables are assigned in ./secrets/secrets file.


source ./secrets/secrets

REPORT_DATE=$(date  +%m_%d_%y)

# Authenticate with Prisma Cloud to retrieve access token

AUTH_PAYLOAD=$(cat <<EOF
{"username": "$TL_USER", "password": "$TL_PASSWORD"}
EOF
)

TL_JWT_RESPONSE=$(curl --silent \
                       --request POST \
                       --url "$TL_CONSOLE/api/v1/authenticate" \
                       --header 'Content-Type: application/json' \
                       --data "$AUTH_PAYLOAD")

TL_JWT=$(printf '%s' "$TL_JWT_RESPONSE" | jq -r '.token' )


# Pull a Cloud Discovery Report to CSV

CLOUD_DISCOVERY_REPORT_LOCATION="./reports/cloud_discovery_report_$REPORT_DATE.csv"

curl -H "Authorization: Bearer $TL_JWT" \
     -H 'Content-Type: text/csv' \
     -X GET \
     --url "$TL_CONSOLE/api/v1/cloud/discovery/download" > "$CLOUD_DISCOVERY_REPORT_LOCATION"


#  Print output filename and location

printf '\n%s\n\n' "All done! Your report is saved as: ./reports/cloud_discovery_report_$REPORT_DATE.csv"
