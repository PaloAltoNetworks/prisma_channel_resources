#!/bin/bash

source ./secrets/secrets

# Put container image tag here

IMAGE_TAG="swaggerapi/petstore:latest"

#### NO EDITS NEEDED BELOW

LEARNING_PAYLOAD=$(cat <<EOF
{"state":"manualLearning"}
EOF
)

function quick_check {
  res=$?
  if [ $res -eq 0 ]; then
    echo "$1 request succeeded"
  else
    echo "$1 request failed error code: $res" >&2
    exit 1
  fi
}

# Retrieves the IMAGE PROFILE ID from the compute console
# self-hosted may require curl -k depending on if you're using a self-signed cert
PROFILE_ID_RESPONSE=$(curl -X GET \
                           -u $TL_USER:$TL_PASSWORD \
                           --url "$TL_CONSOLE/api/v1/profiles/container?search=$IMAGE_TAG")

quick_check "/api/v1/profiles/container"

PROFILE_ID=$(printf %s "$PROFILE_ID_RESPONSE" | jq -r '.[]._id')

# Turns on the learning mode for the container image
# self-hosted may require curl -k depending on if you're using a self-signed cert
curl -X POST \
     -u $TL_USER:$TL_PASSWORD \
     --url "$TL_CONSOLE/api/v1/profiles/container/$PROFILE_ID/learn" \
     -H "Content-Type: application/json" \
     -d $LEARNING_PAYLOAD


quick_check "/api/v1/profiles/container/$PROFILE_ID/learn"

exit
