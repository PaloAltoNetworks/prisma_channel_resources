#!/usr/bin/env bash
# Author Kyle Butler
# to run: `bash ./<script_name>.sh`
# requires jq to be installed

# WARNING THIS COULD REQUIRE SIGNIFICANT FREE STORAGE TO GENERATE: Example 2 million cloud resources will require roughly 1 GB of free space.
# EXCEL HAS LIMITATIONS WHICH MAY MAKE THIS REPORT UNABLE TO BE OPENED
# https://support.microsoft.com/en-us/office/excel-specifications-and-limits-1672b34d-7043-467e-8e27-269d656771c3

# Splitting the final report into seperate csvs based on the number of lines might be important if you plan to open the report in EXCEL
# EXAMPLE `split -l 20 report.csv new` will split the report.csv file into new files with 20 lines each in them.

# reads in the variables from the ./secrets/secrets file
source ./secrets/secrets
# uses the functions in the ./func/func.sh file
source ./func/func.sh

# function to check to ensure variables are assigned correctly
pce-var-check

# bash array of cloud providers supported by prisma cloud
csp_pfix_array=("aws-" "azure-" "gcp-" "gcloud-" "alibaba-" "oci-")

# date format example: July 28th 2023 1:09 PM = 20230728-1309
date=$(date +%Y%m%d-%H%M)

# request body for /login endpoint
AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)

# response from the /login endpoint
PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")


# parses the response with jq to find the value assigned to the .token key
PC_JWT=$(printf '%s' "$PC_JWT_RESPONSE" | jq -r '.token')

# loops through each CSP in the array above
for csp in "${!csp_pfix_array[@]}"; do \

# request body for the /search/suggest endpoint
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

# response from the /search/suggest endpoint assigned to var
rql_api_response=$(curl --url "$PC_APIURL/search/suggest" \
                        --header "accept: application/json; charset=UTF-8" \
                        --header "content-type: application/json" \
                        --header "x-redlock-auth: $PC_JWT" \
                        --data "$config_request_body")

# prints the response to a file which will be used later. Labels the file based on the index of the CSP in the CSP array
printf '%s' "$rql_api_response" > "./temp/rql_api_response_$csp.json"


done

# parses the .suggestions[] array in the file from the response from the /search/suggest endpoint and reads the array into a bash array
rql_api_array=($(cat ./temp/rql_api_response_* | jq -r '.suggestions[]'))

# another request body for the /search/suggest endpoint to ultimately create a bash array of cloud accounts connected to prisma cloud
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

# response from the /search/suggest endpoint assigned to var
rql_cloud_account_response=$(curl --url "$PC_APIURL/search/suggest" \
                                  --header "accept: application/json; charset=UTF-8" \
                                  --header "content-type: application/json" \
                                  --header "x-redlock-auth: $PC_JWT" \
                                  --data "$account_request_body")

# prints the response and parses the json for the .suggestions[] array directing output to a temp file 
printf '%s' "$rql_cloud_account_response" | jq -r '.suggestions[]' > "./temp/rql_cloud_account_response.json"

# reads in each line of the ./temp/rql_cloud_account_response.json file into another bash array
rql_cloud_account_array=()
while IFS= read -r line; do
   rql_cloud_account_array+=("$line")
done < "./temp/rql_cloud_account_response.json"

# starts the loop on each cloud account in the cloud account array
for cloud_account in "${!rql_cloud_account_array[@]}"; do \


# makes a seperate folder using the index of the cloud account in the temp directory
mkdir -p ./temp/$(printf '%05d' "$cloud_account")

# sub loop which loops through all the available api-services prisma cloud supports 
for api_query in "${!rql_api_array[@]}"; do \

# creates a request body for the /search/config endpoint using the elements in both the cloud account array and the api-services array
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

# same logic as above. Assigns the response from the request to /login endpoint
PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")

# parses the response and finds the value assigned to the token to the PC_JWT var
PC_JWT=$(printf '%s' "$PC_JWT_RESPONSE" | jq -r '.token')
fi

# used a silent request here so it doesn't look odd due to the multi-processing trick being used here. Ultimately, sends the request using the request body above to the search/config endpoint directs the response to a temp file in the cloud account index folder. 
curl -s --url "$PC_APIURL/search/config" \
     --header "accept: application/json; charset=UTF-8" \
     --header "content-type: application/json" \
     --header "x-redlock-auth: $PC_JWT" \
     --data "${rql_request_body}" > "./temp/$(printf '%05d' "$cloud_account")/other_$(printf '%05d' "$api_query").json" &

done

# wait for all processes to finish before continuing 
wait

# directs the output from all the response files for each cloud account to a temp finished file in the root of the temp folder again using the index of the cloud account. 
cat ./temp/$(printf '%05d' "$cloud_account")/*.json > ./temp/finished_$(printf '%05d' "$cloud_account").json

done

# adds headers to the report file
printf '%s\n' "cloudType,id,accountId,name,accountName,regionId,service,resourceType,prismaApiName" > "./reports/all_cloud_resources_$date.csv"

# cleans up accounts file
rm ./temp/rql_cloud_account_response.json
# cleans up the api-response file
rm ./temp/rql_api_response_*

# takes all the finished json files and parses with jq to filter out everything but the data related to: cloudType,id,accountId,name,accountName,regionId,service,resourceType,prismaApiName. Finally the finished json data is formatted with JQ into csv format. sed filter to filter out the rql parts of the query for better readability
cat ./temp/finished_*.json | jq -r '.  | {query: .query, data: .data.items[]} | {"cloudType": .data.cloudType, "id": .data.id, "accountId": .data.accountId,  "name": .data.name,  "accountName": .data.accountName,  "regionId": .data.regionId, "service": .data.service, "resourceType": .data.resourceType, "query": .query }| [.[]] |@csv ' | sed "s|config from cloud\.resource where cloud\.account = \'.*\' AND api.name =||g" | sed "s|AND resource\.status = Active||g" >> "./reports/all_cloud_resources_$date.csv"

# lets user know report has finished by printing output to the terminal
printf '\n\n\n%s\n\n' "All done your report is in the reports directory and is named ./reports/all_cloud_resources_$date.csv"

# clean-up task. Removes temp files
{
rm -rf ./temp/*
}
exit
