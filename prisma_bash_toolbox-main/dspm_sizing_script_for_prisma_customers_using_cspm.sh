#!/usr/bin/env bash
# Written by Kyle Butler
# Count licensable resources for DSPM
# Requires jq

# Load secrets
source ./secrets/secrets

# function to check directories
directory_check () {
DIR_PATH=$1
if [ ! -d "$DIR_PATH" ]; then
  # Create the directory
  mkdir -p "$DIR_PATH"
  echo "Directory '$DIR_PATH' created."
else
  echo "Directory '$DIR_PATH' exists."
fi
}

directory_check "./temp"
directory_check "./reports"

# Authentication payload
AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)

# Function to retrieve Prisma JWT
retrieve_prisma_jwt() {
    PC_JWT_RESPONSE=$(curl --silent --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")
    PC_JWT=$(printf %s "$PC_JWT_RESPONSE" | jq -r '.token')
}

# Retrieve initial JWT
retrieve_prisma_jwt

# Set report date
REPORT_DATE=$(date +%Y%m%d-%H%M)

# Array of licensable services
SERVICE_ARRAY=(
'aws-elasticache-cache-clusters'
'aws-rds-describe-db-instances'
'aws-rds-db-cluster'
'aws-s3api-get-bucket-acl'
'aws-dynamodb-describe-table'
'aws-docdb-db-cluster'
'aws-emr-instance'
'aws-emr-describe-cluster'
'aws-redshift-describe-clusters'
'aws-dax-cluster'
'aws-efs-describe-file-systems'
'aws-es-describe-elasticsearch-domain'
'aws-opensearch-list-domain-names'
'azure-storage-account-list'
'azure-cosmos-db'
'azure-database-maria-db-server'
'azure-documentdb-cassandra-clusters'
'azure-sql-db-list'
'azure-sql-managed-instance'
'azure-sql-server-list'
'azure-cache-redis'
'azure-mysql-flexible-server'
'azure-postgres-flexible-server'
'azure-synapse-workspace'
'gcloud-filestore-instance'
'gcloud-memorystore-memcached-instance'
'gcloud-redis-instances-list'
'gcloud-bigtable-instance-list'
'gcloud-sql-instances-list'
'gcloud-bigquery-dataset-list'
'gcloud-storage-buckets-list'
'gcloud-cloud-spanner-database'
)

# Account request body
ACCOUNT_REQUEST_BODY=$(cat <<EOF
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

# Retrieve cloud account details
RQL_CLOUD_ACCOUNT_RESPONSE=$(curl --url "$PC_APIURL/search/suggest" \
                                  --header "accept: application/json; charset=UTF-8" \
                                  --header "content-type: application/json" \
                                  --header "x-redlock-auth: $PC_JWT" \
                                  --data "$ACCOUNT_REQUEST_BODY")

# Store cloud accounts into a temporary file and array
printf '%s' "$RQL_CLOUD_ACCOUNT_RESPONSE" | jq -r '.suggestions[]' > "./temp/rql_cloud_account_response.json"
RQL_CLOUD_ACCOUNT_ARRAY=()
while IFS= read -r line; do
   RQL_CLOUD_ACCOUNT_ARRAY+=("$line")
done < "./temp/rql_cloud_account_response.json"

# Loop through each cloud account
for CLOUD_ACCOUNT in "${!RQL_CLOUD_ACCOUNT_ARRAY[@]}"; do
    # Re-authenticate after every 50 accounts
    if ! (( $CLOUD_ACCOUNT % 50 )); then
        retrieve_prisma_jwt
    fi

    # Create a temporary directory for the cloud account
    mkdir -p ./temp/$(printf '%05d' "$CLOUD_ACCOUNT")

    # Loop through each service for the cloud account
    for SERVICE in "${!SERVICE_ARRAY[@]}"; do
        # Request body for RQL
        RQL_REQUEST_BODY=$(cat <<EOF
{
  "query":"config from cloud.resource where cloud.account = ${RQL_CLOUD_ACCOUNT_ARRAY[$CLOUD_ACCOUNT]} AND resource.status = Active AND api.name = '${SERVICE_ARRAY[$SERVICE]}'",
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

        echo "Checking cloud account: ${RQL_CLOUD_ACCOUNT_ARRAY[$CLOUD_ACCOUNT]} for ${SERVICE_ARRAY[$SERVICE]}"

        # Query Prisma Cloud for the service and store the result
        curl -s --url "$PC_APIURL/search/config" \
             --header "accept: application/json; charset=UTF-8" \
             --header "content-type: application/json" \
             --header "x-redlock-auth: $PC_JWT" \
             --data "${RQL_REQUEST_BODY}" > "./temp/$(printf '%05d' "$CLOUD_ACCOUNT")/other_$(printf '%05d' "$SERVICE").json" &
    done

    # Wait for all background processes to complete before moving on
    wait
    echo "Combining all licensable services for cloud account ${RQL_CLOUD_ACCOUNT_ARRAY[$CLOUD_ACCOUNT]}"
    cat ./temp/$(printf '%05d' "$CLOUD_ACCOUNT")/*.json > ./temp/finished_$(printf '%05d' "$CLOUD_ACCOUNT").json

done

# Create a report in the reports directory
echo "Creating report in the reports directory, please wait"
printf '%s\n' "resourceCount, cloudType, cloudAccount, accountName, service, resourceType, regionId, prismaApiName" > "./reports/dspm_resources_summary_$REPORT_DATE.csv"

# Combine all finished JSON files into a CSV report
for finished_file in ./temp/finished_*.json; do
   echo "Processing $finished_file for report"
   cat "$finished_file" | jq -r '. | {query: .query?, data: .data?.items[]?} | {"cloudType": .data.cloudType, "accountId": .data.accountId,  "accountName": .data.accountName,  "service": .data.service, "resourceType": .data.resourceType, "regionId": .data.regionId, "query": .query }| [.[]] |@csv ' \
   | sed "s|config from cloud\.resource where cloud\.account = .* AND resource.status = Active AND api.name = ||g" \
   | tr -s '\n' | sort | uniq -c | awk '{sub($1, "&,"); print}' | sort -r >> "./reports/dspm_resources_summary_$REPORT_DATE.csv"
done

# Notify user of completion and location of the report
echo "Report finished and is located here: ./reports/dspm_resources_summary_$REPORT_DATE.csv"

# Exit the script
exit
