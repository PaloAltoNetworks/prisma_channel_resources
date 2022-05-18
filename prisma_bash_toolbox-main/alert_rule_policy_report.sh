#!/bin/bash 
# requires jq
# written by Kyle Butler
# shows all the policies mapped to alert rules in the Prisma Cloud Enterprise edition console for alert rule troubleshooting and routing

source ./secrets/secrets

quick_check () {
  res=$?
  if [ $res -eq 0 ]; then
      echo "$1 request succeeded"
  else
      echo "$1 request failed error code: $res" >&2
      exit 1
  fi
}


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

ALERT_RULE_RESPONSE=$(curl --request GET \
                           --url "$PC_APIURL/v2/alert/rule" \
                           --header "x-redlock-auth: $PC_JWT")

quick_check "/alert/rule"

POLICY_INFO_RESPONSE=$(curl --request GET \
                            --url "$PC_APIURL/v2/policy/" \
                            --header "x-redlock-auth: $PC_JWT")

quick_check "/v2/policy"

POLICY_JSON=$(printf %s "$POLICY_INFO_RESPONSE" | jq '.[] | {policyId: .policyId, name: .name}')


printf %s "$POLICY_JSON" > ./policy_temp.json


printf %s "$ALERT_RULE_RESPONSE" | jq '[.[] |{name: .name, enabled: .enabled, policies: .policies[]}] | map({name, enabled, policies, policyName: (.policies as $policyId | $policydata |..|select(.name? and .policyId==$policyId))})' --slurpfile policydata ./policy_temp.json | jq '[.[] |{name: .name, enabled: .enabled, policyId: .policies, policyName: .policyName.name}]' | jq -r 'map({name, enabled, policyId, policyName}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' > ./alert_rule_policy_rep
ort.csv

