#!/usr/bin/env bash
# written by Jonathan Hurtt with collaboration from Kyle Butler

# creates a csv report showing all active cloud resources without a tag
# no user configuration required
# to run: `bash ./<script_name>.sh`
# requires jq to be installed


source ./secrets/secrets
source ./func/func.sh

pce-var-check

csp_pfix_array=("aws-" "azure-" "gcp-" "gcloud-" "alibaba-" "oci-")


date=$(date +%Y%m%d-%H%M)


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

PC_JWT=$(printf '%s' "$PC_JWT_RESPONSE" | jq -r '.token')

for csp in "${!csp_pfix_array[@]}"; do \

config_request_body=$(cat <<EOF
{
  "query":"config from cloud.resource where api.name = ${csp_pfix_array[csp]}",
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

rql_api_response=$(curl --url "$PC_APIURL/search/suggest" \
                        --header "accept: application/json; charset=UTF-8" \
                        --header "content-type: application/json" \
                        --header "x-redlock-auth: $PC_JWT" \
                        --data "$config_request_body")


printf '%s' "$rql_api_response" > "./temp/rql_api_response_$csp.json"


done


rql_api_array=($(cat ./temp/rql_api_response_* | jq -r '.suggestions[]'))


for api_query in "${!rql_api_array[@]}"; do \

rql_request_body=$(cat <<EOF
{
  "query":"config from cloud.resource where api.name = ${rql_api_array[api_query]} AND resource.status = Active AND json.rule='$.tags[*] size equals 0'",
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

curl -s --url "$PC_APIURL/search/config" \
     --header "accept: application/json; charset=UTF-8" \
     --header "content-type: application/json" \
     --header "x-redlock-auth: $PC_JWT" \
     --data "${rql_request_body}" > "./temp/other_$api_query.json" &

done
wait

printf '%s\n' "cloudType,id,accountId,name,accountName,regionId,regionName,service,resourceType" > "./reports/cloud_resources_without_tags_$date.csv"

cat ./temp/other_* | jq -r '.data.items[] | {"cloudType": .cloudType, "id": .id, "accountId": .accountId,  "name": .name,  "accountName": .accountName,  "regionId": .regionId,  "regionName": .regionName,  "service": .service, "resourceType": .resourceType }' | jq -r '[.[]] | @csv' >> "./reports/cloud_resources_without_tags_$date.csv"

printf '\n\n\n%s\n\n' "All done your report is in the reports directory and is named ./reports/cloud_resources_without_tags_$date.csv"

{
rm -f ./temp/*.json
}
