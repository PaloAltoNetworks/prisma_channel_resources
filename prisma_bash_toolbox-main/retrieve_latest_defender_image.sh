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


TL_CONSOLE_SANS_PROTO=$(printf '%s' "$TL_CONSOLE" | sed -E 's/^\s*.*:\/\///g')

ECS_TASK_DEF_REQ_BODY=$(cat <<EOF
{
  "consoleAddr": "$TL_CONSOLE_SANS_PROTO",
  "namespace": "twistlock",
  "orchestration": "ecs",
  "selinux": false,
  "cri": true,
  "privileged": false,
  "serviceAccounts": true,
  "istio": false,
  "collectPodLabels": false,
  "proxy": null,
  "dockerSocketPath": null,
  "gkeAutopilot": false
}
EOF
)

ECS_TASK_REQUEST=$(curl --url "https://us-east1.cloud.twistlock.com/us-2-158256885/api/v1/defenders/ecs-task.json?project=Central+Console" \
                        --header 'Accept: application/json, text/plain, */*' \
                        --header "Authorization: Bearer $TL_JWT" \
                        --header 'Content-Type: application/json' \
                        --data-raw "$ECS_TASK_DEF_REQ_BODY" \
                        --compressed)

printf '\n\n%s\n\n' "latest prisma compute defender image is: $(printf '%s' "$ECS_TASK_REQUEST" | jq -r '.containerDefinitions[].image')"
