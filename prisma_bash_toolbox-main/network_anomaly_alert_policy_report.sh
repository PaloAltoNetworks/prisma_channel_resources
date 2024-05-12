#!/usr/bin/env bash
# requires jq
# written by Kyle Butler
# shows all the network anomaly alerts and includes the target host IP as a column

source ./secrets/secrets
source ./func/func.sh

REPORT_DATE=$(date  +%m_%d_%y)

AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)


PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")

PC_JWT=$(printf %s "$PC_JWT_RESPONSE" | jq -r '.token' )

NETWORK_ANOMALY_LIST=$(curl --url "$PC_APIURL/v2/policy?policy.subtype=network&policy.type=anomaly" \
     --header "accept: application/json; charset=UTF-8" \
     --header "content-type: application/json" \
     --header "x-redlock-auth: $PC_JWT" | jq  '.[]  | {policyId, name}')


echo $NETWORK_ANOMALY_LIST  | jq -c . | while read -r anomaly_report; do
  POLICY_ID=$(echo "$anomaly_report" | jq -r '.policyId')
  POLICY_NAME=$(echo "$anomaly_report" | jq -r '.name' | sed 's/ /_/g')
  REPORT_LOCATION="./reports/${POLICY_NAME}_report_${REPORT_DATE}.csv"
  echo $REPORT_LOCATION
  echo "Alert Id, Resource Name, Resource ID, Account Id, Account, Region, Resource Type, Anomalous Public IP" > $REPORT_LOCATION
  curl -L -X GET \
        --url "$PC_APIURL/v2/alert?timeType=relative&timeAmount=2&timeUnit=year&detailed=false&alert.status=open&policy.id=$POLICY_ID" \
        --header "accept: application/json; charset=UTF-8" \
        --header "content-type: application/json" \
        --header "x-redlock-auth: $PC_JWT" | jq ' .items[]' | jq -r '[.id, .resource.name, .resource.id, .resource.accountId, .resource.account, .resource.region, .resource.resourceType, .anomalyDetail.targetHost.ip] | @csv' >> $REPORT_LOCATION
done
