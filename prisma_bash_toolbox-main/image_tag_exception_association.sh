#!/usr/bin/env bash
# written by Kyle Butler
# requires jq to be installed
# What this does: It adds vulnerabilities which have a certain severity to an exisiting prisma cloud compute tag and ensures the related packages and image name are associated with the tag to showcase the ability to add exceptions to CI rules through the api. 
# THIS WILL CREATE A LOT OF TAG RULES. Please make sure to read the user section of this script


####USER CONFIG#################################################################################

# full image name: <repo>/<image_name>:<tag_version>. leaving an example assigned for reference.
IMAGE_NAME="vulnerables/web-dvwa:latest"

# Prisma Compute resource tag for prisma cloud. Tag must exist. Capitilization matters
TAG="test"

# choose one: low, medium, high, critical. Capitilization matters
SEVERITY="critical"

#####END USER CONFIG############################################################################






# retrieves the variables from the secrets file
source ./secrets/secrets
source ./func/func.sh

# Ensures proper formatting of json in bash

tl-var-check

AUTH_PAYLOAD=$(cat <<EOF
{"username": "$TL_USER", "password": "$TL_PASSWORD"}
EOF
)


# authenticates to the prisma compute console using the access key and secret key. If using a self-signed cert with a compute on-prem version, add -k to the curl command.·
PRISMA_COMPUTE_API_AUTH_RESPONSE=$(curl --header "Content-Type: application/json" \
                                        --request POST \
                                        --data-raw "$AUTH_PAYLOAD" \
                                        --url $TL_CONSOLE/api/v1/authenticate )

quick_check "/api/v1/authenticate"

TL_JWT=$(printf '%s' "$PRISMA_COMPUTE_API_AUTH_RESPONSE" | jq -r '.token')



TAG_RESPONSE=$(curl --url "$TL_CONSOLE/api/v1/tags?project=Central+Console" \
                    --header 'Accept: application/json, text/plain, */*' \
                    --header "Authorization: Bearer $TL_JWT")



quick_check "/api/v1/collections?project=Central+Console"


TAG_NAME=$(printf '%s' "$TAG_RESPONSE" | jq -r --arg TAG_NAME "$TAG" '.[] | select(.name == $TAG_NAME) | .name')

IMAGE_RESPONSE=$(curl --url "$TL_CONSOLE/api/v1/images?name=$IMAGE_NAME" \
                    --header 'Accept: application/json, text/plain, */*' \
                    --header 'Accept-Language: en-US,en;q=0.9' \
                    --header "Authorization: Bearer $TL_JWT")


quick_check "/api/v1/images?name=$IMAGE_NAME"

PRISMA_CVES_ARRAY=($(printf '%s' "$IMAGE_RESPONSE" | jq --arg SEVERITY "$SEVERITY" -r '.[].vulnerabilities[] | select(.severity == $SEVERITY) | .cve'))
PRISMA_PACKAGE_ARRAY=($(printf '%s' "$IMAGE_RESPONSE" | jq --arg SEVERITY "$SEVERITY" -r '.[].vulnerabilities[] | select(.severity == $SEVERITY)| .packageName'))

for cve in "${!PRISMA_CVES_ARRAY[@]}"; do

PAYLOAD=$(cat <<EOF
{
"tag":"$TAG_NAME",
"id":"${PRISMA_CVES_ARRAY[cve]}",
"packageName":"${PRISMA_PACKAGE_ARRAY[cve]}",
"resourceType":"image",
"resources":[
  "$IMAGE_NAME"
  ],
"checkBaseLayer":false
}
EOF
)

curl --request POST \
     --url "$TL_CONSOLE/api/v1/tags/{$TAG_NAME}/vuln?project=Central+Console" \
     --header 'Accept: application/json, text/plain, */*' \
     --header "Authorization: Bearer $TL_JWT" \
     --data-raw "$PAYLOAD"

quick_check "/api/v1/tags/{$TAG_NAME}/vuln?project=Central+Console"

done

exit
