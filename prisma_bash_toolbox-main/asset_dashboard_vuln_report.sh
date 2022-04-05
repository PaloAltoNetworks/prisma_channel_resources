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


# adjust the below variables TIMEUNIT and TIMEAMOUNT as necessary. By default will pull the last 1 month of data
TIMEUNIT="month"
TIMEAMOUNT="1"



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






OVERALL_SUMMARY=$(curl --request GET \
                       --url "$PC_APIURL/v2/inventory?timeType=relative&timeAmount=$TIMEAMOUNT&timeUnit=$TIMEUNIT" \
                       --header "x-redlock-auth: $PC_JWT" | jq -r '[{summary: "all_accounts",total_number_of_resources: .summary.totalResources, resources_passing: .summary.passedResources, resources_failing: .summary.failedResources, high_severity_issues: .summary.highSeverityFailedResources, medium_severity_issues: .summary.mediumSeverityFailedResources, low_severity_issues: .summary.lowSeverityFailedResources}]')

quick_check "/v2/inventory"

COMPLIANCE_SUMMARY=$(curl --request GET \
                          --header "x-redlock-auth: $PC_JWT" \
                          --url "$PC_APIURL/compliance/posture?timeType=relative&timeAmount=1&timeUnit=month" | jq '[.complianceDetails[] | {framework_name: .name, number_of_policy_checks: .assignedPolicies, high_severity_issues: .highSeverityFailedResources, medium_severity_issues: .mediumSeverityFailedResources, low_severity_issues: .lowSeverityFailedResources, total_number_of_resources: .totalResources}]')

quick_check "/compliance/posture"

SERVICE_SUMMARY=$(curl --request GET \
                       --url "$PC_APIURL/v2/inventory?timeType=relative&timeAmount=1&timeUnit=month&groupBy=cloud.service&scan.status=all" \
                       --header "x-redlock-auth: $PC_JWT" | jq '[.groupedAggregates[]]' | jq 'group_by(.cloudTypeName)[] | {(.[0].cloudTypeName): [.[] | {service_name: .serviceName, high_severity_issues: .highSeverityFailedResources, medium_severity_issues: .mediumSeverityFailedResources, low_severity_issues: .lowSeverityFailedResources, total_number_of_resources: .totalResources}]}')

quick_check "/v2/inventory"

REPORT_DATE=$(date  +%m_%d_%y)

echo -e "summary\n" >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null # ignore jq error
printf %s $OVERALL_SUMMARY | jq -r 'map({summary,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources,resources_passing,resources_failing}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null # ignores the null error from jq

echo -e "\ncompliance summary\n" >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null
printf %s $COMPLIANCE_SUMMARY | jq -r 'map({framework_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources,number_of_policy_checks}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null

echo -e "\naws \n" >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null
printf %s $SERVICE_SUMMARY | jq -r '.aws' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null

echo -e "\nazure \n" >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null
printf %s $SERVICE_SUMMARY | jq -r '.azure' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null

echo -e "\ngcp \n" >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null
printf %s $SERVICE_SUMMARY | jq -r '.gcp' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null

echo -e "\noci \n" >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null
printf %s $SERVICE_SUMMARY | jq -r '.oci' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null

echo -e "\nalibaba_cloud \n" >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null
printf %s $SERVICE_SUMMARY | jq -r '.alibaba_cloud' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$REPORT_DATE.csv 2>/dev/null
echo "                                                                     "
echo "                                                                     "
echo "report created here: $PWD/pcee_cspm_kpi_report_$REPORT_DATE.csv" 
echo "                                                                     "
echo "                                                                     "

exit
