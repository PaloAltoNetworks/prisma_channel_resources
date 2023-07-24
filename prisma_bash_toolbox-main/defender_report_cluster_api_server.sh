#!/usr/bin/env bash
# author Kyle Butler
# to run: `bash <script_name>.sh`
# requires jq to be installed
# Creates a defender report which shows what monitoring is enabled, the k8s cluster api server name and additional information
# Also outputs in json

# doesn't need to be assigned if the secrets file has the variables assigned
TL_CONSOLE="<PATH_TO_CONSOLE_IN_COMPUTE>"
PC_ACCESSKEY="<ACCESS_KEY>"
PC_SECRETKEY="<SECRET_KEY>"


# default for the repo

TEMP_DIR="./temp"
REPORTS_DIR="./reports"

source secrets/secrets
date=$(date +%Y%m%d-%H%M)


retrieve_token(){
AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)





PRISMA_COMPUTE_API_AUTH_RESPONSE=$(curl --header "Content-Type: application/json" \
                                        --request POST \
                                        --data-raw "$AUTH_PAYLOAD" \
                                        --url "$TL_CONSOLE/api/v1/authenticate" )


TL_JWT=$(printf '%s' "$PRISMA_COMPUTE_API_AUTH_RESPONSE" | jq -r '.token')
}
retrieve_token

# retrieves the csv file for deployed defenders which shows the total number of defenders
curl --request GET \
     --url "$TL_CONSOLE/api/v1/defenders/download" \
     --header 'Accept: application/json' \
     --header "authorization: Bearer $TL_JWT" \
     -o "$TEMP_DIR/defenders.csv"

# read the "hosts" column or first column of the csv into a bash array
hosts_array=( $(tail -n +2 $TEMP_DIR/defenders.csv | cut -d ',' -f1) )

# if there's more than 50 hosts then loop through with limit and offset gathering all the data to a file paying attention to the rate limiting
if [ "${#hosts_array[@]}" -gt 50 ]; then \
  for host in $(seq 0 50 "${#hosts_array[@]}"); do \
    if [ $(( "$host" % 1500 )) -eq 0 ]; then \
      echo "sleeping for a minute to avoid rate limiting"
      sleep 60
      retrieve_token
    fi

    curl --request GET \
         --url "$TL_CONSOLE/api/v1/hosts?limit=50&offset=$host" \
         --header 'Accept: application/json' \
         --header "authorization: Bearer $TL_JWT" >> "$TEMP_DIR/hosts.json"

    curl --request GET \
         --url "$TL_CONSOLE/api/v1/defenders?limit=50&offset=$host" \
         --header 'Accept: application/json' \
         --header "authorization: Bearer $TL_JWT" >> "$TEMP_DIR/defenders.json"
  done
 else
   curl --request GET \
        --url "$TL_CONSOLE/api/v1/hosts" \
        --header 'Accept: application/json' \
        --header "authorization: Bearer $TL_JWT" > "$TEMP_DIR/hosts.json"

   curl --request GET \
        --url "$TL_CONSOLE/api/v1/defenders" \
        --header 'Accept: application/json' \
        --header "authorization: Bearer $TL_JWT" > "$TEMP_DIR/defenders.json"
fi

# parses the hosts.json file downloaded from the /api/v1/hosts endpoint to pull out custerName (for matching) and apiServerName
cat "$TEMP_DIR/hosts.json" | jq '.[] | { apiServerName: .k8sClusterAddr?, clusterName: .clusters[]?} | select(.apiServerName != null)' | jq '[inputs]' > "$TEMP_DIR/modified_hosts.json"


# parses the defender.json file and filters for hostname, type, version, and connected. Additionally, it flattens the cloudMetadata and status objects. Then combines the two arrays based on the .clusterName in the modified_hosts.json file matching
# the .cluster key in the defenders.json file

cat "$TEMP_DIR/defenders.json" | jq '[.[] | {hostname, type, version, connected, processMonitoring: .status.process.enabled?, networkMonitoring: .status.process.enabled?, filesystemMonitoring: .status.filesystem.enabled?, appFirewall: .status.appFirewall.enabled?, cloudProvider: .cloudMetadata.provider?, cloudRegion: .cloudMetadata.region?, cloudAccountName: .cloudMetadata.accountID?, cluster: .cluster}] |map({hostname, type, version, connected, processMonitoring, networkMonitoring, filesystemMonitoring, appFirewall, cloudProvider,cloudRegion, cloudAccountName, cluster, clusterApiServer: [(.cluster as $clusterName | $hosts_data | ..|select(.clusterName? and .clusterName == $clusterName ))]})' --slurpfile hosts_data "$TEMP_DIR/modified_hosts.json" | jq '.[] | {hostname, type, version, connected, processMonitoring, networkMonitoring, filesystemMonitoring, appFirewall, cloudProvider,cloudRegion, cloudAccountName, cluster, clusterApiServer: .clusterApiServer[].apiServerName?}' | jq '[inputs]' > "$REPORTS_DIR/defender_data_$date.json"

printf '%s\n' 'hostname, type, version, connected, processMonitoring, networkMonitoring, filesystemMonitoring, appFirewall, cloudProvider, cloudRegion, cloudAccountName, cluster, clusterApiServer' > "$REPORTS_DIR/defender_report_$date.csv"
cat "$REPORTS_DIR/defender_data_$date.json" | jq  '.[]' | jq -r '[.[]] | @csv' >> "$REPORTS_DIR/defender_report_$date.csv"

cat "$REPORTS_DIR/defender_data_$date.json"

printf '\n\n\n\n%s' "csv report is in the reports directory named defender_report.csv"

#clean up temp
{
rm "$TEMP_DIR/hosts.json"
rm "$TEMP_DIR/defenders.json"
rm "$TEMP_DIR/modified_hosts.json"
rm "$TEMP_DIR/defenders.csv"
}

exit
