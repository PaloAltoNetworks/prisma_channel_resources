#!/bin/sh

# Written by Kyle Butler
# Will pull down a vulnerability report for all deployed images visable to the prisma cloud compute platform
# Ensure that $TL_USER, $TL_PASSWORD, and $TL_CONSOLE variables are assigned in ./secrets/secrets file. 


# No user configuration required. Expectations are you'd schedule this with cron

source ./secrets/secrets


REPORT_DATE=$(date  +%m_%d_%y)

function quick_check {
  res=$?
  if [ $res -eq 0 ]; then
    echo "$1 request succeeded"
  else
    echo "$1 request failed error code: $res"
    exit
  fi
}

TL_API_LIMIT=50
AUTH_PAYLOAD=$(cat <<EOF
{"username": "$TL_USER", "password": "$TL_PASSWORD"}
EOF
)

# add -k to curl if using self-hosted version with a self-signed cert
TL_JWT=$(curl --silent \
              --request POST \
              --url "$TL_CONSOLE/api/v1/authenticate" \
              --header 'Content-Type: application/json' \
              --data "$AUTH_PAYLOAD" | jq -r '.token' )

quick_check "/api/v1/authenticate"

# add -k to curl if using self-hosted version with a self-signed cert
curl -H "Authorization: Bearer $TL_JWT" \
     -H 'Content-Type: application/json' \
     -X GET \
     --url "$TL_CONSOLE/api/v1/images/download?" > ./deployed_images_report_$REPORT_DATE.csv

quick_check "/api/v1/images/download"
