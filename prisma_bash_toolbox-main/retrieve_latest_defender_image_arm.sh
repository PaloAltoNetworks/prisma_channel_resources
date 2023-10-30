#!/usr/bin/env bash
# written by Kyle Butler
# requires jq to be installed
# retrieves the latest defender image version from the prisma cloud compute api endpoint


# retrieves the variables from the secrets file
source ./secrets/secrets
source ./func/func.sh



#### END OF USER CONFIG
AUTH_PAYLOAD=$(cat <<EOF
{"username": "$TL_USER", "password": "$TL_PASSWORD"}
EOF
)


PRISMA_COMPUTE_API_AUTH_RESPONSE=$(curl --header "Content-Type: application/json" \
                                        --request POST \
                                        --data-raw "$AUTH_PAYLOAD" \
                                        --url $TL_CONSOLE/api/v1/authenticate )



TL_JWT=$(printf %s $PRISMA_COMPUTE_API_AUTH_RESPONSE | jq -r '.token')


DEFENDER_RESPONSE=$(curl --url "$TL_CONSOLE/api/v1/defenders/image-name" \
                         --header "Authorization: Bearer $TL_JWT" \
                         --header 'Content-Type: application/json')

printf '\n%s\n%s\n%s' "To retrieve the arm64 version of the defender run:" \
                      "docker pull $DEFENDER_RESPONSE --platform=linux/arm64" \
                      "then tag it so that it can be referenced and differentiated from the x86_64"
