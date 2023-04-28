#!/usr/bin/env bash
# written by Kyle Butler
# requires jq and curl
# purpose: queries the prisma cloud api to report how many nodes are in Azure AKS clusters. Reports both the active and deleted clusters



source ./secrets/secrets
source ./func/func.sh


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

CONFIG_SEARCH=$(cat <<EOF
{
  "query":"config from cloud.resource where cloud.type = 'azure' and api.name = 'azure-kubernetes-cluster'",
  "timeRange":{
     "type":"relative",
     "value":{
        "unit":"hour",
        "amount":24
     }
  }
}
EOF
)

REPORT_DATE=$(date  +%m_%d_%y)

CONFIG_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/search/config" \
                       --header 'content-type: application/json; charset=UTF-8' \
                       --header "x-redlock-auth: $PC_JWT" \
                       --data "$CONFIG_SEARCH")



printf '%s' "$CONFIG_RESPONSE" > "./temp/response_$REPORT_DATE.json"

cat ./temp/response_$REPORT_DATE.json | jq -r '[.data.items[] | {name: .name, service: .service, accountName: .accountName, regionName: .regionName, deleted: .deleted, propertiesAgentPoolProfilesCount: .data.properties.agentPoolProfiles[].count?}] | map({name, service, accountName, regionName, deleted, propertiesAgentPoolProfilesCount})| (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' > "./reports/azure_aks_nodepool_report_$REPORT_DATE.csv"



printf '\n\n%s\n\n' "All done, your report is located here: ./reports/azure_aks_nodepool_report_$REPORT_DATE.csv"

{
rm ./temp/response_$REPORT_DATE.json
}
