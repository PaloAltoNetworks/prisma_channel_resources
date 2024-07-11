#!/usr/bin/env bash
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
source ./func/func.sh

### USE WHEN THERE ARE MORE THAN 10000 resources in scope for the report

#### This will pull all the alerts by the policy ids associated to the compliance framework and export everything as a CSV. 

# comes from the console
COMPLIANCE_STD_NAME="CIS v1.4.0 (AWS)"
TIME_TYPE="relative"
TIME_UNIT="month"
TIME_AMOUNT="1"
STATUS="open"


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

REPORT_DATE=$(date  +%m_%d_%y)

COMPLIANCE_ID_RESPONSE=$(curl --request GET \
                              --url "$PC_APIURL/compliance" \
                              --header "x-redlock-auth: $PC_JWT" )

quick_check "/compliance"

COMPLIANCE_ID=$(printf %s "$COMPLIANCE_ID_RESPONSE" | jq -r --arg COMPLIANCE_NAME "$COMPLIANCE_STD_NAME" '.[] | select(.name == $COMPLIANCE_NAME) | .id')


SECTION_ID_RESPONSE=$(curl --request GET \
                           --url "$PC_APIURL/compliance/{$COMPLIANCE_ID}/requirement" \
                           --header "x-redlock-auth: $PC_JWT")

quick_check "/compliance/{$COMPLIANCE_ID}/requirement"

SECTION_ID=$(printf %s "$SECTION_ID_RESPONSE" | jq -r '.[].id')

SECTION_ID_ARRAY=( $(printf '%s' "$SECTION_ID") )

COMPLIANCE_SECTION_RESPONSE=$(for SECTION_ID in "${SECTION_ID_ARRAY[@]}"; do
                                    curl --request GET \
                                         --url $PC_APIURL/compliance/{$SECTION_ID}/section \
                                         --header "x-redlock-auth: $PC_JWT" | jq '.[]';
                              done)

POLICY_ID_ARRAY=( $(printf %s "$COMPLIANCE_SECTION_RESPONSE" | jq -r '.associatedPolicyIds[]') )

REPORT_LOCATION="./reports/detailed_compliance_alert_report_$COMPLIANCE_STD_NAME-$REPORT_DATE.csv"

printf '%s\n' "account,cloudAccountOwners,cloudType,firstSeen,lastSeen,lastUpdated,policyName,policyRecommendation,policySeverity,policyType,prismaResourceApiName,region,requirementId,requirementName,resourceId,resourceName,resourceTagKeys,resourceTagValues,resourceType,sectionDescription,sectionId,sectionLabel,standardDescription,standardName,url" > "$REPORT_LOCATION" 


for POLICY_ID in "${POLICY_ID_ARRAY[@]}"; do
  POLICY_RESPONSE=$(curl --request GET \
                         --url "$PC_APIURL/v2/alert?timeType=$TIME_TYPE&timeAmount=$TIME_AMOUNT&timeUnit=$TIME_UNIT&detailed=true&policy.id=$POLICY_ID&status=$STATUS" \
                         --header "x-redlock-auth: $PC_JWT")
  quick_check "/v2/alert?timeType=$TIME_TYPE&timeAmount=$TIME_AMOUNT&timeUnit=$TIME_UNIT&detailed=true&policy.id=$POLICY_ID&status=$STATUS"
  printf '%s' "$POLICY_RESPONSE" | jq -r --arg COMPLIANCE_NAME "$COMPLIANCE_STD_NAME" '.items[] | select(.status == "open" ) | {policyName: .policy.name, policyDescription: .policy.description, policySeverity: .policy.severity, policyType: .policy.policyType, policyRecommendation: .policy.recommendation, account: .resource.account, resourceName: .resource.name, resourceType: .resource.resourceType, resourceId: .resource.rrn, complianceMetadata: (.policy.complianceMetadata[] | select( .standardName == $COMPLIANCE_NAME )), resourceId: .resource.id, resourceTagKeys: (.resource.data.tags |from_entries? | keys|@sh),resourceTagValues: (.resource.data.tags |from_entries? | flatten | @sh), region: .resource.region, cloudServiceName: .resource.cloudServiceName, cloudType: .resource.cloudType, cloudAccountOwners: (.resource.cloudAccountOwners? | @sh), firstSeen, lastSeen, lastUpdated, url: .resource.url, prismaResourceApiName: .resource.resourceApiName, resourceType: .resource.resourceType, reason} | [{cloudType, cloudAccountOwners: (.cloudAccountOwners // ""), account, region, resourceType, resourceName, resourceId, resourceTagKeys, resourceTagValues, url, policyName, policyType, policySeverity, policyRecommendation, standardName: .complianceMetadata.standardName, standardDescription: .complianceMetadata.standardDescription, requirementId: .complianceMetadata.requirementId, requirementName: .complianceMetadata.requirementName, sectionId: .complianceMetadata.requirementName, sectionDescription: .complianceMetadata.sectionDescription, sectionLabel: .complianceMetadata.sectionLabel, firstSeen, lastSeen, lastUpdated, prismaResourceApiName}] |(first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $rows[] | @csv ' >>  "$REPORT_LOCATION"
  sleep 1
done

printf '\n\n%s\n' "All done! Your report is in the ./reports directory saved as: detailed_compliance_alert_report_$COMPLIANCE_STD_NAME-$REPORT_DATE.csv"

exit
