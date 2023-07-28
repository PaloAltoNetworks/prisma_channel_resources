#!/usr/bin/env bash
# Author Kyle Butler
# to run: `bash ./<script_name>.sh`
# requires jq to be installed

# WARNING this will take a while to generate but will pull the most accurate summary
# data on existing cloud assets by resource type and cloud service and show distribution
# across cloud accounts. Expect a csv with the following table headers:
# resourceCount, cloudType, accountId, accountName, service, resourceType

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


account_request_body=$(cat <<EOF
{
  "query":"config from cloud.resource where cloud.account =",
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

rql_cloud_account_response=$(curl --url "$PC_APIURL/search/suggest" \
                                  --header "accept: application/json; charset=UTF-8" \
                                  --header "content-type: application/json" \
                                  --header "x-redlock-auth: $PC_JWT" \
                                  --data "$account_request_body")

printf '%s' "$rql_cloud_account_response" | jq -r '.suggestions[]' > "./temp/rql_cloud_account_response.json"

rql_cloud_account_array=()
while IFS= read -r line; do
   rql_cloud_account_array+=("$line")
done < "./temp/rql_cloud_account_response.json"


for cloud_account in "${!rql_cloud_account_array[@]}"; do \


mkdir -p ./temp/$(printf '%05d' "$cloud_account")

for api_query in "${!rql_api_array[@]}"; do \


# every 600 api requests refresh the JWT so it doesn't timeout. 
if [ $api_query = 600 ]; then \

PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")

PC_JWT=$(printf '%s' "$PC_JWT_RESPONSE" | jq -r '.token')
fi


rql_request_body=$(cat <<EOF
{
  "query":"config from cloud.resource where cloud.account = ${rql_cloud_account_array[cloud_account]} AND api.name = ${rql_api_array[api_query]} AND resource.status = Active",
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
     --data "${rql_request_body}" > "./temp/$(printf '%05d' "$cloud_account")/other_$(printf '%05d' "$api_query").json" &

done
wait

cat ./temp/$(printf '%05d' "$cloud_account")/*.json > ./temp/finished_$(printf '%05d' "$cloud_account").json

done

printf '%s\n' "resourceCount, cloudType, cloudAccount, accountName, service, resourceType, regionId, prismaApiName" > "./reports/all_cloud_resources_$date.csv"

rm ./temp/rql_cloud_account_response.json
rm ./temp/rql_api_response_*

for finished_file in ./temp/finished_*.json; do \
cat $finished_file |  jq -r '.  | {query: .query, data: .data.items[]} | {"cloudType": .data.cloudType, "accountId": .data.accountId,  "accountName": .data.accountName,  "service": .data.service, "resourceType": .data.resourceType, "regionId": .data.regionId, "query": .query }| [.[]] |@csv ' | sed "s|config from cloud\.resource where cloud\.account = \'.*\' AND api.name =||g" | sed "s|AND resource\.status = Active||g" | tr -s '\n' | sort | uniq -c | awk '{sub($1, "\"&\","); print}' >> "./reports/all_cloud_resources_$date.csv";
done

printf '\n\n\n%s\n\n' "All done your report is in the reports directory and is named ./reports/all_cloud_resources_$date.csv"


{
rm -rf ./temp/*
}
