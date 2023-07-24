#!/usr/bin/env bash
# Author Kyle Butler
# to run: `bash ./<script_name>.sh`
# requires jq to be installed

# Lists out all the licensable resources in Prisma Cloud by cloud account

source ./secrets/secrets
source ./func/func.sh

pce-var-check

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



rql_api_array=("'aws-ec2-describe-instances'" "'aws-rds-describe-db-instances'" "'aws-redshift-describe-clusters'" "'aws-ec2-describe-internet-gateways'" "'aws-elb-describe-load-balancers'" "'azure-network-lb-list'" "'azure-sql-db-list'" "'azure-vm-list'" "'azure-postgresql-server'" "'azure-sql-managed-instance'" "'gcloud-compute-instances-list'" "'gcloud-sql-instances-list'" "'gcloud-compute-nat'" "'gcloud-compute-internal-lb-backend-service'" "'alibaba-cloud-ecs-instance'" "'oci-compute-instance'" "'oci-oracledatabase-bmvm-dbsystem'" "'oci-networking-loadbalancer'" )


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

# every 600 api requests refresh the JWT so it doesn't timeout.
if [ $api_query = 600 ]; then \

PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")

PC_JWT=$(printf '%s' "$PC_JWT_RESPONSE" | jq -r '.token')
fi

curl -s --url "$PC_APIURL/search/config" \
     --header "accept: application/json; charset=UTF-8" \
     --header "content-type: application/json" \
     --header "x-redlock-auth: $PC_JWT" \
     --data "${rql_request_body}" > "./temp/$(printf '%05d' "$cloud_account")/other_$(printf '%05d' "$api_query").json" &

done
wait

cat ./temp/$(printf '%05d' "$cloud_account")/*.json > ./temp/finished_$(printf '%05d' "$cloud_account").json

done

printf '%s\n' "cloudType,id,accountId,name,accountName,regionId,regionName,service,resourceType" > "./reports/all_cloud_resources_$date.csv"

rm ./temp/rql_cloud_account_response.json


cat ./temp/finished_*.json | jq -r '.data.items[] | {"cloudType": .cloudType, "id": .id, "accountId": .accountId,  "name": .name,  "accountName": .accountName,  "regionId": .regionId,  "regionName": .regionName,  "service": .service, "resourceType": .resourceType }' | jq -r '[.[]] | @csv' >> "./reports/all_cloud_resources_$date.csv"

printf '\n\n\n%s\n\n' "All done your report is in the reports directory and is named ./reports/all_cloud_resources_$date.csv"

{
rm -rf ./temp/*
}
