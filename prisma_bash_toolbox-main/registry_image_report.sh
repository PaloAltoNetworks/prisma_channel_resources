#!/usr/bin/env bash
# Written by Kyle Butler
# No user configuration required
# Requires jq to be installed
# Tested with jq-1.7.1
# Script assumes you have two relative directories: ./temp and ./reports in the directory you run the script from

# brings in the $TL_USER and $TL_PASSWORD values from the secrets file
source ./secrets/secrets
source ./func/func.sh


# report date added to the final reports
REPORT_DATE=$(date  +%m_%d_%y)



# Ensures proper formatting of json in bash
AUTH_PAYLOAD=$(cat <<EOF
{
 "username": "$TL_USER",
 "password": "$TL_PASSWORD"
}
EOF
)


# creates directory structure for temp directory
mkdir -p ./temp/image
mkdir -p ./temp/container

# authenticates to the prisma compute console using the access key and secret key.
# If using a self-signed cert with a compute on-prem version, add -k to the curl command.·
PRISMA_COMPUTE_API_AUTH_RESPONSE=$(curl --header "Content-Type: application/json" \
                                        --request POST \
                                        --data-raw "$AUTH_PAYLOAD" \
                                        --url $TL_CONSOLE/api/v1/authenticate )


# parses response for the API token. Token lives for 15 minutes
TL_JWT=$(printf %s "$PRISMA_COMPUTE_API_AUTH_RESPONSE" | jq -r '.token')


# pulls the out of the box report from the console for deployed images.
curl --request GET \
     --url "$TL_CONSOLE/api/v1/registry/download" \
     --header "Authorization: Bearer $TL_JWT" > ./reports/registry_image_report_$REPORT_DATE.csv


echo "done. your report is located here: ./reports/registry_image_report_$REPORT_DATE.csv"
exit
