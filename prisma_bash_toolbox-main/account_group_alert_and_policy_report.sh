#!/usr/bin/env bash
#------------------------------------------------------------------------------------------------------------------#
# Written By Kyle Butler
#
# REQUIREMENTS: 
# Requires jq to be installed: 'sudo apt-get install jq'



# copy the account group name from the Prisma Cloud Console under Settings > Account Groups. This is required to run the script. 
ACCOUNT_GROUP="Azure Cloud Accounts"
CLOUD_TYPE="azure"

############################## NO USER CONFIG BELOW ####################################


source ./secrets/secrets
source ./func/func.sh
JSON_LOCATION="./temp"
REPORTS_LOCATION="./reports"

#### This will pull all of the policies and alerts for an account group and create a csv report. 


#### NO EDITS NEEDED BELOW
pce-var-check

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

ACCOUNT_GROUP_RESPONSE=$(curl --request GET \
                              --url "$PC_APIURL/cloud/group" \
                              --header "x-redlock-auth: $PC_JWT" )

quick_check "/cloud/group"


ACCOUNT_GROUP_ID=$(printf '%s' "$ACCOUNT_GROUP_RESPONSE" | jq -r --arg NAME "$ACCOUNT_GROUP" '.[] | select(.name == $NAME) | .id')


POLICY_RESPONSE=$(curl --request GET \
                       --url "$PC_APIURL/alert/policy?alert.status=open&account.group=$ACCOUNT_GROUP_ID&cloud.type=$CLOUD_TYPE" \
                       --header "x-redlock-auth: $PC_JWT" )

quick_check "/alert/policy?alert.status=open&account.group=$ACCOUNT_GROUP_ID&cloud.type=$CLOUD_TYPE"

printf '%s' "$POLICY_RESPONSE" | jq '.[] | del(.policy.complianceMetadata)'  > "$JSON_LOCATION/temp_policy.json"

INVENTORY_RESPONSE=$(curl --request GET \
                          --url "$PC_APIURL/v2/inventory?timeType=to_now&timeUnit=epoch&cloud.type=azure&account.group=$ACCOUNT_GROUP_ID&groupBy=cloud.service" \
                          --header "x-redlock-auth: $PC_JWT")

quick_check "/v2/inventory?timeType=to_now&timeUnit=epoch&cloud.type=azure&account.group=$ACCOUNT_GROUP_ID&groupBy=cloud.service"


# dumps the Inventory response to a temp_inventory.json file
printf '%s' "$INVENTORY_RESPONSE" > "$JSON_LOCATION/temp_inventory.json"




# creates an array of policy ids
POLICY_ID_ARRAY=( $(printf '%s' "$POLICY_RESPONSE"| jq -r '.[].policyId') )



# loops through all of the policies, and gets information about the underlying resources, ultimately pulling out the policyId and the resource cloud service type. 

for policyId in "${POLICY_ID_ARRAY[@]}";
do

ALERT_PAYLOAD=$(cat <<EOF
{
  "detailed": false,
  "filters": [
    {
      "name": "timeRange.type",
      "operator": "=",
      "value": "ALERT_OPENED"
    },
    {
      "name": "alert.status",
      "operator": "=",
      "value": "open"
    },
    {
      "name": "account.group",
      "operator": "=",
      "value": "$ACCOUNT_GROUP"
    },
    {
      "name": "policy.id",
      "operator": "=",
      "value": "$policyId"
    }
  ],
  "timeRange": {
    "type": "to_now",
    "value": "epoch"
  },
  "limit": 1,
  "webClient": true
}
EOF
)


ALERT_INFO_RESPONSE=$(curl --request POST \
                           --url "$PC_APIURL/v2/alert" \
                           --header "content-type: application/json" \
                           --header "x-redlock-auth: $PC_JWT" \
                           --data "$ALERT_PAYLOAD" )


quick_check "/v2/alert"

# dumps the response from the /v2/alert endpoint and filters out the noise, this is simply so we can map the cloud service to the policy.
printf '%s' "$ALERT_INFO_RESPONSE"  |jq '.items[] | {cloudServiceName: .resource.cloudServiceName, policyId: .policyId}' >> "$JSON_LOCATION/temp_alert_info.json"

done

# gets today's date
REPORT_DATE=$(date  +%m_%d_%y)


# takes the response from the policy endpoint and combines it with the alert information endpoint
cat "$JSON_LOCATION/temp_policy.json" | jq '[{policyId: .policyId, policyName: .policy.name, description: .policy.description, recommendation: .policy.recommendation, severity: .policy.severity, alertCount: .alertCount}] | map({policyId, policyName, description, recommendation, severity, alertCount, cloudServiceName: (.policyId as $policyId | $policyData |..| select(.policyId? and .policyId==$policyId))}) | .[0] | {policyId: .policyId, policyName: .policyName, description: .description, recommendation: .recommendation, severity: .severity, alertCount: .alertCount, cloudServiceName: .cloudServiceName.cloudServiceName}' --slurpfile policyData "$JSON_LOCATION/temp_alert_info.json" > "$JSON_LOCATION/temp_combined_alert_policy.json"

# takes the response from the inventory endpoint and combines it with the alert and policy endpoint
cat "$JSON_LOCATION/temp_inventory.json" | jq '[.groupedAggregates[]] | map({cloudTypeName, serviceName, failedResources, passedResources, totalResources, highSeverityFailedResources, mediumSeverityFailedResources, lowSeverityFailedResources, policyDetails: [(.serviceName as $serviceName | $combinedData |..| select(.cloudServiceName? and .cloudServiceName==$serviceName))]})' --slurpfile combinedData "$JSON_LOCATION/temp_combined_alert_policy.json" > "$JSON_LOCATION/temp_finished.json"

# removes duplicate keys and provides the output in csv format
cat "$JSON_LOCATION/temp_finished.json" | jq -r '[.[] | {cloudTypeName: .cloudTypeName, serviceName: .serviceName, failedResources: .failedResources, passedResources: .passedResources, totalResources: .totalResources, highSeverityFailedResources: .highSeverityFailedResources, mediumSeverityFailedResources: .mediumSeverityFailedResources, lowSeverityFailedResources: .lowSeverityFailedResources, policyDetails: .policyDetails[]} | {cloudTypeName: .cloudTypeName, serviceName: .serviceName, failedResources: .failedResources, passedResources: .passedResources, totalResources: .totalResources, highSeverityFailedResources: .highSeverityFailedResources, mediumSeverityFailedResources: .mediumSeverityFailedResources, lowSeverityFailedResources: .lowSeverityFailedResources, policyId: .policyDetails.policyId?, policyName: .policyDetails.policyName?, description: .policyDetails.description?, recommendation: .policyDetails.recommendation?, severity: .policyDetails.severity?, alertCount: .policyDetails.alertCount?}] | map({cloudTypeName, serviceName, failedResources, passedResources, totalResources, highSeverityFailedResources, mediumSeverityFailedResources, lowSeverityFailedResources, policyId, policyName, description, recommendation, severity, alertCount}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' > "$REPORTS_LOCATION/account_group_report_$REPORT_DATE.csv"

# clean up task 
{
sleep 5

printf '%s\n' "cleaning up temp.json files"
rm "$JSON_LOCATION/*.json"

printf '%s\n' "done"
}


printf '\n\n%s\n' "All done! Your report is in the ./reports directory saved as: ./account_group_report_$REPORT_DATE.csv"


exit
