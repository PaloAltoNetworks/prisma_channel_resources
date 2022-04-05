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


source ./secrets/secrets



COMPLIANCE_NAME="PCI DSS v3.2.1"
TIME_TYPE="relative"
TIME_AMOUNT="1"
TIME_UNIT="month"



#### NO EDITS BELOW


function quick_check {
  res=$?
  if [ $res -eq 0 ]; then
    echo "$1 request succeeded"
  else
    echo "$1 request failed error code: $res" >&2
    exit 1
  fi
}


function loop_response_check {
  res=$?
  if [ $res -eq 0 ]; then
    echo "$1 request succeeded"
  else
    echo "$1 request failed error code: $res" >&2
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



COMPLIANCE_ID_RESPONSE=$(curl --request GET \
                              --url "$PC_APIURL/compliance" \
                              --header "x-redlock-auth: $PC_JWT" )

quick_check "/compliance"

COMPLIANCE_ID=$(printf %s "$COMPLIANCE_ID_RESPONSE" | jq -r --arg COMPLIANCE_NAME "$COMPLIANCE_NAME" '.[] | select(.name == $COMPLIANCE_NAME) | .id')


REQUIREMENT_IDS_RESPONSE=$(curl --request GET \
                                --url "$PC_APIURL/compliance/{$COMPLIANCE_ID}/requirement" \
                                --header "x-redlock-auth: $PC_JWT" )

quick_check "/compliance/{$COMPLICE_ID}/requirement"

REQUIREMENT_IDS=$(printf %s "$REQUIREMENT_IDS_RESPONSE" | jq -r '.[].id')

declare -a REQUIREMENT_ID_ARRAY=($(printf %s "$REQUIREMENT_IDS"))

echo -e "sectionName, description, assignedPolicies, failedResources, passedResources, totalResources, HighSeverityFailedResources, mediumSeverityFailedResources, lowSeverityFailedResources \n" > ./compliance_section_summary_data_$REPORT_DATE.csv

for REQUIREMENT_ID in ${REQUIREMENT_ID_ARRAY[@]}; do
        COMPLIANCE_POSTURE_RESPONSE=$(curl --request GET \
                                           --url "$PC_APIURL/compliance/posture/{$COMPLIANCE_ID}/{$REQUIREMENT_ID}?timeType=$TIME_TYPE&timeAmount=$TIME_AMOUNT&timeUnit=$TIME_UNIT" \
                                           --header "x-redlock-auth: $PC_JWT" )
        loop_response_check "/compliance/posture/{$COMPLIANCE_ID}/{$REQUIREMENT_ID}?timeType=$TIME_TYPE&timeAmount=$TIME_AMOUNT&timeUnit=$TIME_UNIT"
        printf %s "$COMPLIANCE_POSTURE_RESPONSE" | jq '.complianceDetails[] | {sectionName: .name, description: .description, assignedPolicies: .assignedPolicies, failedResources: .failedResources, passedResources: .passedResources, totalResources: .totalResources, HighSeverityFailedResources: .highSeverityFailedResources, mediumSeverityFailedResources: .mediumSeverityFailedResources, lowSeverityFailedResources: .lowSeverityFailedResources}'| jq -r '[.] | map({sectionName, description, assignedPolicies, failedResources, passedResources, totalResources, HighSeverityFailedResources, mediumSeverityFailedResources, lowSeverityFailedResources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $rows[] | @csv' >> ./compliance_section_summary_data_$REPORT_DATE.csv

done

exit
