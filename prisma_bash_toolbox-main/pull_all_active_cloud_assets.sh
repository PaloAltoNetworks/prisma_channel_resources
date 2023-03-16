#!/usr/bin/env bash
# Author Kyle Butler
# to run: `bash ./<script_name>.sh`
# requires jq to be installed

# WARNING THIS COULD REQUIRE SIGNIFICANT FREE STORAGE TO GENERATE
# EXCEL HAS LIMITATIONS WHICH MAY MAKE THIS REPORT UNABLE TO BE OPENED
# https://support.microsoft.com/en-us/office/excel-specifications-and-limits-1672b34d-7043-467e-8e27-269d656771c3

# Splitting the final report into seperate csvs based on the number of lines might be important if you plan to open the report in EXCEL
# EXAMPLE `split -l 20 report.csv new` will split the report.csv file into new files with 20 lines each in them. 

source ./secrets/secrets
source ./func/func.sh

pce-var-check

# controls the number of requests a second; uncomment line 119 if you need to use.
number_of_jobs="20"

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

#sub_control;
curl -s --url "$PC_APIURL/search/config" \
     --header "accept: application/json; charset=UTF-8" \
     --header "content-type: application/json" \
     --header "x-redlock-auth: $PC_JWT" \
     --data "${rql_request_body}" > "./temp/other_$(printf '%05d%05d' "$cloud_account" "$api_query").json" &

done
wait

done

printf '%s\n' "cloudType,id,accountId,name,accountName,regionId,regionName,service,resourceType" > "./reports/all_cloud_resources_$date.csv"

cd temp
cat other_* | jq -r '.data.items[] | {"cloudType": .cloudType, "id": .id, "accountId": .accountId,  "name": .name,  "accountName": .accountName,  "regionId": .regionId,  "regionName": .regionName,  "service": .service, "resourceType": .resourceType }' | jq -r '[.[]] | @csv' >> "../reports/all_cloud_resources_$date.csv"

printf '\n\n\n%s\n\n' "All done your report is in the reports directory and is named ./reports/all_cloud_resources_$date.csv"

cd ..

{
rm -f ./temp/*.json
}
