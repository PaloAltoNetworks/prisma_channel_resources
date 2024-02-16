#!/usr/bin/env bash
# Written by Kyle Butler
# Pulls a de-aggregated vulnerability report and config/compliance report for deployed container images
# This allows for pivoting and drilling down into the data from the CSP Account -> Cluster -> Namespace -> Node -> Pod
# Huge shout out to Scott R from UA for all the assistance developing this!
# Works with both defender secured workloads (EKS K8S Docker OpenShift ECS/Fargate ECS EC2) and agentless
# Functionality in Prisma Cloud
# Access key requires at min read permissions to the runtime security section of the platform
# No user configuration required
# Requires jq to be installed
# Script assumes you have two relative directories: ./temp and ./reports in the directory you run the script from

# brings in the $TL_USER and $TL_PASSWORD values from the secrets file
source ./secrets/secrets
source ./func/func.sh


# report date added to the final reports
REPORT_DATE=$(date  +%m_%d_%y)




# Ensures proper formatting of json in bash
AUTH_PAYLOAD=$(cat <<EOF
{
 "username": "$TL_USER",
 "password": "$TL_PASSWORD"
}
EOF
)


# creates directory structure for temp directory
mkdir -p ./temp/image
mkdir -p ./temp/container

# authenticates to the prisma compute console using the access key and secret key.
# If using a self-signed cert with a compute on-prem version, add -k to the curl command.·
PRISMA_COMPUTE_API_AUTH_RESPONSE=$(curl --header "Content-Type: application/json" \
                                        --request POST \
                                        --data-raw "$AUTH_PAYLOAD" \
                                        --url $TL_CONSOLE/api/v1/authenticate )


# parses response for the API token. Token lives for 15 minutes
TL_JWT=$(printf %s "$PRISMA_COMPUTE_API_AUTH_RESPONSE" | jq -r '.token')


# pulls the out of the box report from the console for deployed images.
curl --request GET \
     --url "$TL_CONSOLE/api/v1/images/download" \
     --header "Authorization: Bearer $TL_JWT" > ./temp/out-of-box-report.csv



# Provides the number of unique rows based on the columns we care about
DEPLOYED_IMAGE_RESULTS=$(($(cat ./temp/out-of-box-report.csv | awk -F ',' '{print $1$2$3$4 }' | sort | uniq | wc -l ) - 1))

# Loop through the number of unique lines to satisify the limit and offset parameters in the request. Writes responses to files in the image directory
for image_results_offset in $(seq 0 50 $DEPLOYED_IMAGE_RESULTS); do \

  curl --request GET \
       --url "$TL_CONSOLE/api/v1/images?limit=50&offset=$image_results_offset" \
       --header "Authorization: Bearer $TL_JWT" \
       --header 'Accept: application/json' > "./temp/image/$(printf '%08d' "$image_results_offset").json"

done

printf '\n%s\n' "Finished with gathering response data. Formatting and processing will take a moment, please don't quit the process"


# Creates a file with a list of all the file paths to the responses
for image_response_file in ./temp/image/*.json; do \
  printf '%s\n' "$image_response_file" >> ./temp/image_file_response_array.txt
done

# Reads those file paths into a bash array
IMAGE_RESPONSE_FILE_ARR=()
while IFS= read -r line; do
  IMAGE_RESPONSE_FILE_ARR+=("$line")
done < ./temp/image_file_response_array.txt


printf '\n%s\n' "Formatting image response data, please wait."

# Loops through the IMAGE_RESPONSE_FILE_ARR and parses the json from the requests for vulnerability data
for image_response_index in "${!IMAGE_RESPONSE_FILE_ARR[@]}"; do \
  cat ${IMAGE_RESPONSE_FILE_ARR[$image_response_index]} |  jq '[.[]? | {id, cloudMetadata, registry: .repoTag.registry, repository: .repoTag.repo, tag: .repoTag.tag, distro: .osDistro, distroRelease: .osDistroRelease, distroVersion: .osDistroVersion, vulnerabilityData: .vulnerabilities[]?, hosts} | {id, cloudMetadata, registry, repository, tag, distro, distroRelease, distroVersion, cve: .vulnerabilityData.cve, cvss: .vulnerabilityData.cvss, cveStatus: .vulnerabilityData.status, vulnerabilityTitle: .vulnerabilityData.title, vulnerabilityText: .vulnerabilityData.text, vectorStr: .vulnerabilityData.vecStr, exploit: .vulnerabilityData.exploit, riskFactors: (.vulnerabilityData.riskFactors | keys | @sh), vulnerabilityDesc: .vulnerabilityData.description, severity: .vulnerabilityData.severity, vulnerabilityLink: .vulnerabilityData.link, vulnerabilityType: .vulnerabilityData.type, packageName: .vulnerabilityData.packageName, packageVersion: .vulnerabilityData.packageVersion, discovered: .vulnerabilityData.discovered, fixDate: .vulnerabilityData.fixDate, published: .vulnerabilityData.published, hostnames: (.hosts? | keys), hostData: .hosts} | .hostnames as $hostnames | . + { "hostname": $hostnames[] } | del(.hostnames) |  {id, registry, repository, tag, distro, distroRelease, distroVersion, cve, cvss, cveStatus, vulnerabilityTitle, vulnerabilityText, vectorStr, exploit, riskFactors, vulnerabilityDesc, severity, vulnerabilityLink, vulnerabilityType, packageName, packageVersion, discovered, fixDate, published, hostname, cluster: .hostData[.hostname].cluster?, namespace: .hostData[.hostname].namespaces[]?, accountID: .hostData[.hostname].accountID?, cspProvider: .cloudMetadata.provider, cspResourceID: .cloudMetadata.resourceID, cspRegion: .cloudMetadata.region, cspVMimageID: .cloudMetadata.image }] | unique | select(length > 0)' > ./temp/finished_vuln_$(printf '%08d' "$image_response_index").json&
done
wait

# Loops through the IMAGE_RESPONSE_FILE_ARR and parses the json from the requests for config/compliance issues
for image_response_index in "${!IMAGE_RESPONSE_FILE_ARR[@]}"; do \
  cat ${IMAGE_RESPONSE_FILE_ARR[$image_response_index]} | jq '[.[]?  | {id, cloudMetadata,registry: .repoTag.registry, repository: .repoTag.repo, tag: .repoTag.tag, distro: .osDistro, distroRelease: .osDistroRelease, distroVersion: .osDistroVersion, configData: .complianceIssues[]?, hosts}| {id, cloudMetadata,registry, repository, tag, distro, distroRelease, distroVersion, configPolicyTitle: .configData.title, configDescription: .configData.description, severity: .configData.severity, configPolicyType: .configData.type, configCause: .configData.cause, complianceID: .configData.id, hostnames: (.hosts? | keys), hostData: .hosts} | .hostnames as $hostnames | . + { "hostname": $hostnames[] } | del(.hostnames) | {id, registry, repository, tag, distro, distroRelease, distroVersion, configPolicyTitle, complianceID,configDescription, severity, configPolicyType, configCause, hostname, cluster: .hostData[.hostname].cluster?, namespace: .hostData[.hostname].namespaces[]?, accountID: .hostData[.hostname].accountID?, cspProvider: .cloudMetadata.provider, cspResourceID: .cloudMetadata.resourceID, cspRegion: .cloudMetadata.region, cspVMimageID: .cloudMetadata.image}] | unique | select(length > 0)' > ./temp/finished_config_$(printf '%08d' "$image_response_index").json&

done
wait

# provides headers for config/compliance report
printf '%s\n' "id,registry,repository,tag,distro,distroRelease,distroVersion,configPolicyTitle,complianceID,configDescription,severity,configPolicyType,configCause,hostname,cluster,namespace,accountID,cspProvider,cspResourceID,cspRegion,cspVMimageID" > ./reports/config_report_containers_$REPORT_DATE.csv

# provides headers for vulnerability report
printf '%s\n' "id,registry,repository,tag,distro,distroRelease,distroVersion,cve,cvss,cveStatus,vulnerabilityTitle,vulnerabilityText,vectorStr,exploit,riskFactors,vulnerabilityDesc,severity,vulnerabilityLink,vulnerabilityType,packageName,packageVersion,discovered,fixDate,published,hostname,cluster,namespace,accountID,cspProvider,cspResourceID,cspRegion,cspVMimageID" > ./reports/vulnerability_report_containers_$REPORT_DATE.csv


# formats the vulnerability data into csv
cat ./temp/finished_vuln_* | jq -r ' . |map(.) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $rows[] | @csv'>> ./reports/vulnerability_report_containers_$REPORT_DATE.csv

# formats the config compliance data into csv
cat ./temp/finished_config_* | jq -r ' . |map(.) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $rows[] | @csv' >> ./reports/config_report_containers_$REPORT_DATE.csv

# user notification
printf '\n%s\n' "Reports are done, they can be retrieved from the following locations: ./reports/vulnerability_report_containers_$REPORT_DATE.csv and ./reports/config_report_containers_$REPORT_DATE.csv"



# remove the lines below if you want to keep the response data
{
rm -rf ./temp/*
}

exit
