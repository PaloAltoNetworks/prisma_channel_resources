#!/bin/bash
#------------------------------------------------------------------------------------------------------------------#
# Written By Kyle Butler
#
# REQUIREMENTS: 
# Requires jq to be installed: 'sudo apt-get install jq'
#
# SET-UP:
# Create Access Key and Secret Key in the Prisma Cloud Console
# Access keys and Secret keys are created in the Prisma Cloud Console under: Settings > Access Keys
# Find the Prisma Cloud Enterprise Edition API URL specific to your deployment: https://prisma.pan.dev/api/cloud/api-url
#
# SECURITY RECOMMENDATIONS:

source ./secrets/secrets

### THIS SCRIPT IS USABLE WHEN THERE ARE LESS THAN 10,000 resources in scope for the report. Use the detailed_compliance_alert_report.sh when there are more than 10,000 resources
#### This will pull all the alerts by the policy ids associated to the compliance framework and export everything as a CSV. 

# comes from the console
COMPLIANCE_STD_NAME="CIS v1.4.0 (AWS)"


TIME_TYPE="relative"
TIME_UNIT="month"
TIME_AMOUNT="1"
STATUS="open"


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

REPORT_DATE=$(date  +%m_%d_%y)



ALERT_RESPONSE=$(curl --request GET \
                      --url "$PC_APIURL/v2/alert?timeType=$TIME_TYPE&timeAmount=$TIME_AMOUNT&timeUnit=$TIME_UNIT&detailed=true" \
                      --header "x-redlock-auth: $PC_JWT" )

quick_check "v2/alert"
printf '%s\n' "policyName, policyDescription, policySeverity, policyType, policyRecommendation, account, resourceName, resourceType, resourceId, standardName, requirementName, sectionId" > "./$REPORT_DATE-$COMPLIANCE_STD_NAME-detailed-compliance-report.csv"

printf '%s' "$ALERT_RESPONSE" | jq -r --arg COMPLIANCE_NAME "$COMPLIANCE_STD_NAME" '.items[] | select(.status == "open" ) | {policyName: .policy.name, policyDescription: .policy.description, policySeverity: .policy.severity, policyType: .policy.policyType, policyRecommendation: .policy.recommendation, account: .resource.account, resourceName: .resource.name, resourceType: .resource.resourceType, resourceId: .resource.rrn, complianceMetadata: [.policy.complianceMetadata[] | select( .standardName == $COMPLIANCE_NAME )]} | {policyName: .policyName, policyDescription: .policyDescription, policySeverity: .policySeverity, policyType: .policyType, policyRecommendation: .policyRecommendation, account: .account, resourceName: .resourceName, resourceType: .resourceType, resourceId: .resourceId, complianceMetadata: .complianceMetadata[]} | [{policyName: .policyName, policyDescription: .policyDescription, policySeverity: .policySeverity, policyType: .policyType, policyRecommendation: .policyRecommendation, account: .account, resourceName: .resourceName, resourceType: .resourceType, resourceId: .resourceId, standardName: .complianceMetadata.standardName, requirementName: .complianceMetadata.requirementName, sectionId: .complianceMetadata.sectionId}] | map({policyName, policyDescription, policySeverity, policyType, policyRecommendation, account, resourceName, resourceType, resourceId, standardName, requirementName, sectionId})| (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $rows[] | @csv' >> "./$REPORT_DATE-$COMPLIANCE_STD_NAME-detailed-compliance-report.csv"


exit
