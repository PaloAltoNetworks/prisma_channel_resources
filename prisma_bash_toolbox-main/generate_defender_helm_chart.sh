#!/usr/bin/env bash
# written by Kyle Butler
# requires jq to be installed

source ./secrets/secrets
source ./func/func.sh


AUTH_PAYLOAD=$(cat <<EOF
{"username": "$TL_USER", "password": "$TL_PASSWORD"}
EOF
)



HOSTNAME_FOR_CONSOLE=$(printf %s $TL_CONSOLE | awk -F / '{print $3}' | sed  's/':\S*'//g')


# authenticates to the prisma compute console using the access key and secret key. If using a self-signed cert with a compute on-prem version, add -k to the curl command.·
PRISMA_COMPUTE_API_AUTH_RESPONSE=$(curl --header "Content-Type: application/json" \
                                        --request POST \
                                        --data-raw "$AUTH_PAYLOAD" \
                                        --url $TL_CONSOLE/api/v1/authenticate )


TL_JWT=$(printf %s $PRISMA_COMPUTE_API_AUTH_RESPONSE | jq -r '.token')

# alter if necessary
HELM_REQUEST_BODY=$(cat <<EOF
{
  "consoleAddr": "$HOSTNAME_FOR_CONSOLE",
  "namespace": "twistlock",
  "orchestration": "kubernetes",
  "selinux": false,
  "cri": true,
  "privileged": false,
  "serviceAccounts": true,
  "istio": false,
  "collectPodLabels": false,
  "proxy": null,
  "taskName": null,
  "gkeAutopilot": false
}
EOF
)

curl --header "authorization: Bearer $TL_JWT" \
     --header 'Content-Type: application/json' \
     --reqeust POST \
     -o ./temp/twistlock-defender-helm.tar.gz \
     --data "$HELM_REQUEST_BODY" \
     --url "$TL_CONSOLE/api/v1/defenders/helm/twistlock-defender-helm.tar.gz"


tar -xvzf ./temp/twistlock-defender-helm.tar.gz
sleep 2


printf '\n%s\n' "all done your helm chart is in the ./temp/twistlock-defender directory"
