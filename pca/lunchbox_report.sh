#!/bin/bash
# Written By Kyle Butler
# Edited By John Chavanne

# Most recent tests:
# Tested on 10.1.2021 on prisma_cloud_enterprise_edition using MacOS Big Sur
# Tested on 6.29.2021 on prisma_cloud_enterprise_edition using Ubuntu 20.04

# Requires jq to be installed on the system you are running the script: https://stedolan.github.io/jq/download/ 

# Recommendations for hardening are: store variables in a secret manager of choice or export the access_keys/secret_key as env variables in a separate script. 
# Decision here is to use environment variables to simplify the workflow and mitigate risk of including credentials in the script.

# Access key should be created in the Prisma Cloud Enterprise Edition Console under: Settings > Accesskeys
# Example of a better way: pcee_console_api_url=$(vault kv get -format=json <secret/path> | jq -r '.<resources>')

# Before running the script, EXPORT the below variables in your terminal/shell.
# Replace the "<CONSOLE_API_URL>" by mapping the API URL found on https://prisma.pan.dev/api/cloud/api-urls
# Replace the "<ACCESS_KEY>", "<SECRET_KEY>" marks respectively below.

# export API_URL="<CONSOLE_API_URL>"
# export ACCESS_KEY="<ACCESS_KEY>"
# export SECRET_KEY="<SECRET_KEY>"

# adjust the below variables TIMEUNIT and TIMEAMOUNT as necessary. By default will pull the last 1 month of data
TIMEUNIT="month"
TIMEAMOUNT="1"

# No edits needed below this line

##########################
### SCRIPT BEGINS HERE ###
##########################

# The environment variables you exported in your shell will be consumed here.
pcee_console_api_url=$API_URL
pcee_accesskey=$ACCESS_KEY
pcee_secretkey=$SECRET_KEY

error_and_exit() {
  echo
  echo "ERROR: ${1}"
  echo
  exit 1
}

# Because why not?
echo "                                                  "
echo "                                                  "
echo "                                                  "
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@\033[36m((\033[0m@@@@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@\033[36m((((\033[0m@@@@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@@@@@@@@\033[36m(((((((\033[0m@@@@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@@@@@@\033[36m(((((((((%\033[0m@@@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@@@\033[36m(((((((((((\033[0m@\033[36m((\033[0m@@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@\033[36m(((((((((((%\033[0m@@\033[36m(((\033[0m@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@\033[36m(((((((((((((\033[0m@@@@\033[36m((((\033[0m@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@\033[36m((((((((((((((\033[0m@@@@@\033[36m((((((\033[0m@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@\033[36m((((((((((((((((\033[0m@@@@@@\033[36m(((((((\033[0m@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@\033[36m((((((((((((\033[0m@@@@@@@@\033[36m((((((((\033[0m@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@\033[36m((((((((\033[0m@@@@@@@@@\033[36m((((((((((\033[0m@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@\033[36m(((((\033[0m@@@@@@@@@@\033[36m(((((((((((\033[0m@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@@@\033[36m((((((((((((\033[0m@@@@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@@@@@\033[36m((((((((((\033[0m@@@@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@@@@@@@@\033[36m(((((((\033[0m@@@@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@@@@@@@@@@\033[36m(((((\033[0m@@@@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@\033[36m((\033[0m@@@@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
sleep .01
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "                                                  "
echo "                                                  "
echo "                                                  "


# formats above json correctly for the call below:

pcee_auth_body_single="
{
 'username':'${pcee_accesskey}', 
 'password':'${pcee_secretkey}'
}"

pcee_auth_body="${pcee_auth_body_single//\'/\"}"

# debugging to ensure jq and cowsay are installed

if ! type "jq" > /dev/null; then
  error_and_exit "jq not installed or not in execution path, jq is required for script execution."
fi


# debugging to ensure the variables are assigned correctly not required

if [ ! -n "$pcee_console_api_url" ] || [ ! -n "$pcee_secretkey" ] || [ ! -n "$pcee_accesskey" ]; then
  echo "pcee_console_api_url or pcee_accesskey or pcee_secret key came up null";
  exit;
fi

if [[ ! $pcee_console_api_url =~ ^(\"\')?https\:\/\/api[2-3]?\.prismacloud\.io(\"|\')?$ ]]; then
  echo "pcee_console_api_url variable isn't formatted or assigned correctly";
  exit;
fi

if [[ ! $pcee_accesskey =~ ^.{35,40}$ ]]; then
  echo "check the pcee_accesskey variable because it doesn't appear to be the correct length";
  exit;
fi

if [[ ! $pcee_secretkey =~ ^.{27,31}$ ]]; then
  echo "check the pcee_accesskey variable because it doesn't appear to be the correct length";
  exit;
fi


# Saves the auth token needed to access the CSPM side of the Prisma Cloud API to a variable named $pcee_auth_token

pcee_auth_token=$(curl -s --request POST \
                       --url "${pcee_console_api_url}/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${pcee_auth_body}" | jq -r '.token')


if [ -z "${pcee_auth_token}" ]; then
	echo
	echo -e "\033[32mauth token not recieved, recommending you check your variable assignment\033[0m";
	echo
	exit;
else
	echo
	echo "auth token recieved"
	echo
fi

# Assigns the Summary results to var
overall_summary=$(curl --request GET \
     --url "${pcee_console_api_url}/v2/inventory?timeType=relative&timeAmount=${TIMEAMOUNT}&timeUnit=${TIMEUNIT}" \
     --header "x-redlock-auth: ${pcee_auth_token}" | jq -r '[{summary: "all_accounts",total_number_of_resources: .summary.totalResources, resources_passing: .summary.passedResources, resources_failing: .summary.failedResources, high_severity_issues: .summary.highSeverityFailedResources, medium_severity_issues: .summary.mediumSeverityFailedResources, low_severity_issues: .summary.lowSeverityFailedResources}]')


# Assigns the Compliance Posture results to var
compliance_summary=$(curl --request GET \
     --header "x-redlock-auth: ${pcee_auth_token}" \
     --url "${pcee_console_api_url}/compliance/posture?timeType=relative&timeAmount=1&timeUnit=month" | jq '[.complianceDetails[] | {framework_name: .name, number_of_policy_checks: .assignedPolicies, high_severity_issues: .highSeverityFailedResources, medium_severity_issues: .mediumSeverityFailedResources, low_severity_issues: .lowSeverityFailedResources, total_number_of_resources: .totalResources}]')


# Assigns the Service summary results to var
service_summary=$(curl --request GET \
  --url "${pcee_console_api_url}/v2/inventory?timeType=relative&timeAmount=1&timeUnit=month&groupBy=cloud.service&scan.status=all" \
  --header "x-redlock-auth: ${pcee_auth_token}" | jq '[.groupedAggregates[]]' | jq 'group_by(.cloudTypeName)[] | {(.[0].cloudTypeName): [.[] | {service_name: .serviceName, high_severity_issues: .highSeverityFailedResources, medium_severity_issues: .mediumSeverityFailedResources, low_severity_issues: .lowSeverityFailedResources, total_number_of_resources: .totalResources}]}')



echo -e "summary\n" >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null # ignore jq error
printf %s ${overall_summary} | jq -r 'map({summary,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources,resources_passing,resources_failing}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null # ignores the null error from jq




echo -e "\ncompliance summary\n" >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null
printf %s ${compliance_summary} | jq -r 'map({framework_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources,number_of_policy_checks}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null


echo -e "\naws \n" >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null
printf %s ${service_summary} | jq -r '.aws' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null

echo -e "\nazure \n" >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null
printf %s ${service_summary} | jq -r '.azure' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null

echo -e "\ngcp \n" >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null
printf %s ${service_summary} | jq -r '.gcp' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null

echo -e "\noci \n" >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null
printf %s ${service_summary} | jq -r '.oci' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null

echo -e "\nalibaba_cloud \n" >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null
printf %s ${service_summary} | jq -r '.alibaba_cloud' | jq -r 'map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv 2>/dev/null
echo "                                                                     "
echo "                                                                     "
echo "report created here: $PWD/pcee_cspm_kpi_report_$(date  +%m_%d_%y).csv" 
echo "                                                                     "
echo "                                                                     "
exit