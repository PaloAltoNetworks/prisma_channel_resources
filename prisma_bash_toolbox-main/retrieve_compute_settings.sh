#!/usr/bin/env bash
# written by Kyle Butler
# requires jq to be installed
# pulls the console settings from the CWPP side of Prisma Cloud the CNAPP platform 


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

curl --url "$TL_CONSOLE/api/v1/settings/system?project=Central+Console" \
     --header "Authorization: Bearer $TL_JWT" \
     --header 'Content-Type: application/json' > ./reports/compute_console_settings.json

printf '\n%s\n' "compute settings have been pulled and are in the reports folder named: ./reports/compute_console_settings.json"
