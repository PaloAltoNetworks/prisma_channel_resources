#!/bin/bash
#------------------------------------------------------------------------------------------------------------------#
# Written By Kyle Butler
# Tested on 7.6.2021 on prisma_cloud_enterprise_edition using Ubuntu 20.04
#
# REQUIREMENTS: 
# Requires jq to be installed: 'sudo apt-get install jq'
# Requires cowsay: 'sudo apt install cowsay'
#
# SET-UP:
# Create Access Key and Secret Key in the Prisma Cloud Console
# Access keys and Secret keys are created in the Prisma Cloud Console under: Settings > Access Keys
# Find the Prisma Cloud Enterprise Edition API URL specific to your deployment: https://prisma.pan.dev/api/cloud/api-url
#
# SECURITY RECOMMENDATIONS:
# Don't leave your keys in the script. Use a secret manager or export those variables from a seperate script. Designed so that it will prompt you if the variables aren't assigned. 
# Example of a better way: PC_APIURL=$(vault kv get -format=json <secret/path> | jq -r '.<resources>')
#
#
# OPTIONAL: to assign below variables, if you don't assign them you will get prompted to enter them when the script is run;
#
# VARIABLE ASSIGNMENTS:

source ./secrets/secrets


IAC_ASSET_NAME="test asset"
IAC_ASSET_TYPE="GitHub"
TAG_KEY_1="user"
TAG_VALUE_1="prisma-presenter"
TAG_KEY_2="email"
TAG_VALUE_2="prisma-presenter@fakeemail.com"
TAG_KEY_3="env"
TAG_VALUE_3="staging"
SCAN_ATTRIBUTE_KEY="dev"
SCAN_ATTRIBUTE_VALUE="kb"
SCRIPT_KEY="script"
SCRIPT_VALUE="iac_rev_4"
FAILURE_CRITERIA_HIGH="1"
FAILURE_CRITERIA_MED="1"
FAILURE_CRITERIA_LOW="1"
FAILURE_OPERATOR="or"

# FOR IAC_CONFIG
IAC_TEMPLATE_TYPE="tf"
IAC_TEMPLATE_VERSION="0.13"
IAC_VAR_PROPERTY1=""
IAC_VAR_VALUE1=""
IAC_VAR_PROPERTY2=""
IAC_VAR_VALUE2=""
IAC_VAR_FILE="/home/prisma-presenter/Project/terragoat/terraform/aws/consts.tf"
IAC_POLICY_ID=""
IAC_FILE_TO_SCAN=""
IAC_FOLDER_TO_SCAN=""


#### NO EDITS NEEDED BELOW

function quick_check {
  res=$?
  if [ $res -eq 0 ]; then
    echo "$1 request succeeded"
  else
    echo "$1 request failed error code: $res"
    exit
  fi
}

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


IAC_PAYLOAD=$(cat <<EOF
{
  "data": {
    "type": "async-scan",
    "attributes": {
      "assetName": "$IAC_ASSET_NAME",
      "assetType": "$IAC_ASSET_TYPE",
      "tags": {
        "$TAG_KEY_1": "$VALUE_KEY_1",
        "$TAG_KEY_2": "$VALUE_KEY_2",
	"$TAG_KEY_3": "$VALUE_KEY_3"
      },
      "scanAttributes": {
        "$SCAN_ATTRIBUTE_KEY": "$SCAN_ATTRIBUTE_VALUE",
        "$SCRIPT_KEY": "$SCRIPT_VALUE"
      },
      "failureCriteria": {
        "high": "$FAILURE_CRITERIA_HIGH",
        "medium": "$FAILURE_CRITERIA_MED",
        "low": "$FAILURE_CRITERIA_LOW",
        "operator": "$FAILURE_OPERATOR"
      }
    }
  }
}
EOF
)


# IAC_CONFIG_PRE='{
#   "data": {
#    "id": "%s",
#    "attributes": {
#      "templateType": "%s",
#      "templateVersion": "%s",
#      "templateParameters": {
#        "variables": {
#          "%s": "%s",
#          "%s": "%s"
#        },
#        "variableFiles": [
#          "%s"
#        ],
#        "policyIdFilters": [
#          "%s"
#        ],
#        "files": [
#          "%s"
#        ],
#        "folders": [
#          "%s"
#        ]
#      }
#    }
#  }
#}'




PC_SCAN=$(curl --silent \
               --request POST \
               --url "$PC_APIURL/iac/v2/scans" \
               --header "x-redlock-auth: $PC_JWT" \
               --header 'Content-Type: application/vnd.api+json' \
               --data-raw "$IAC_PAYLOAD")

quick_check "/iac/v2/scans"

PC_SCAN_ID=$(printf %s "$PC_SCAN" | jq -r '.[].id')


PC_UPLOAD_URL=$(printf %s "$PC_SCAN" | jq -r '.[].links.url')


IAC_CONFIG=$(cat <<EOF
{
  "data": {
    "id": "$PC_SCAN_ID",
    "attributes": {
      "templateType": "$IAC_TEMPLATE_TYPE",
      "templateVersion": "$IAC_TEMPLATE_VERSION",
      "templateParameters": {
        "variableFiles": [
          "$IAC_VAR_FILE"
        ]
      }
    }
  }
}
EOF
)

curl -X PUT \
     --url "$PC_UPLOAD_URL" \
     -T "$IAC_FILE_TO_SCAN"

quick_check "$PC_UPLOAD_URL"

curl -s \
     --request POST \
     --header 'Content-Type: application/vnd.api+json' \
     --header "x-redlock-auth: $PC_JWT" \
     --url "$PC_APIURL/iac/v2/scans/$PC_SCAN_ID" \
     --data-raw "$IAC_CONFIG"

quick_check "/iac/v2/scans/$PC_SCAN_ID"

processing_wait(){
 sleep 10;
         PC_SCAN_STATUS_RESPONSE=$(curl -s --request GET "$PC_APIURL/iac/v2/scans/$PC_SCAN_ID/status" \
                                           --header "x-redlock-auth: $PC_JWT" \
                                           --header 'Content-Type: application/vnd.api+json')
         quick_check "/iac/v2/scans/$PC_SCAN_ID/status"
         PC_SCAN_STATUS=$(printf %s "$PC_SCAN_STATUS_RESPONSE" | jq -r '.[].attributes.status')
}

processing_wait

if [[ "$PC_SCAN_STATUS" == "processing" ]]; then
        processing_wait
fi
if [[ "$PC_SCAN_STATUS" == "processing" ]]; then
        processing_wait
fi
if [[ "$PC_SCAN_STATUS" == "processing" ]]; then
        processing_wait
fi
if [[ "$PC_SCAN_STATUS" == "processing" ]]; then
        processing_wait
fi
if [[ "$PC_SCAN_STATUS" == "processing" ]]; then
        processing_wait
fi
if [[ "$PC_SCAN_STATUS" == "processing" ]]; then
        processing_wait
fi
if [[ "$PC_SCAN_STATUS" == "processing" ]]; then
        processing_wait
fi
if [[ "$PC_SCAN_STATUS" == "processing" ]]; then
        processing_wait
fi
if [[ "$PC_SCAN_STATUS" == "processing" ]]; then
        processing_wait
fi
if [[ "$PC_SCAN_STATUS" == "processing" ]]; then
        processing_wait
fi

# retrives the results
IAC_RESULTS=$(curl --silent \
                   --request GET \
                   --url "$PC_APIURL/iac/v2/scans/$PC_SCAN_ID/results/sarif" \
                   --header "Content-Type: application/json" \
                   --header "x-redlock-auth: $PC_JWT" )

quick_check "/iac/v2/scans/$PC_SCAN_ID/results/sarif"
SCAN_DATE=$(date +%m_%d_%y_%S)

echo "On today's date: $SCAN_DATE"
echo "$(printf %s "$IAC_RESULTS" | jq '.meta.matchedPoliciesSummary.high') high severity issue(s) found"
echo "$(printf %s "$IAC_RESULTS" | jq '.meta.matchedPoliciesSummary.medium') medium severity issue(s) found"
echo "$(printf %s "$IAC_RESULTS" | jq '.meta.matchedPoliciesSummary.low') low severity issue(s) found"

echo
echo 
echo
echo "$IAC_RESULTS" | jq '[.data[].attributes]' | jq 'sort_by(.severity)'
echo
echo
echo

printf '%s\n' "File,Severity_Level,RQL_Query,Issue,Pan_Link,Description,IaC_Resource_Path,IaC_Code_Line" > "./iac_scan_results_$SCAN_DATE.csv";

printf '\n%s\n' "$IAC_RESULTS" | jq '[.data[] | {issue: .attributes.name, severity: .attributes.severity, rule: .attributes.rule, description: .attributes.desc, pan_link: .attributes.docUrl, file: .attributes.blameList[].file, path: .attributes.blameList[].locations[].path, line: .attributes.blameList[].locations[].line}]' | jq 'group_by(.file)[] | {(.[0].file): [.[] | {file: .file, severity: .severity, rule: .rule, issue: .issue, pan_link: .pan_link, description: .description, tf_resource_path: .path, tf_file_line: .line }]}' | jq '.[]' |jq -r 'map({file,severity,rule,issue,pan_link,description,tf_resource_path,tf_file_line}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $rows[] | @csv' >>  "./iac_scan_results_$SCAN_DATE.csv";


exit


