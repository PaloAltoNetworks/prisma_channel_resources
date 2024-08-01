#!/usr/bin/env bash
# Written by Kyle Butler

source ./secrets/secrets



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
mkdir -p ./temp/host

# authenticates to the prisma compute console using the access key and secret key.
# If using a self-signed cert with a compute on-prem version, add -k to the curl command.·
PRISMA_COMPUTE_API_AUTH_RESPONSE=$(curl --header "Content-Type: application/json" \
                                        --request POST \
                                        --data-raw "$AUTH_PAYLOAD" \
                                        --url $TL_CONSOLE/api/v1/authenticate )


# parses response for the API token. Token lives for 15 minutes
TL_JWT=$(printf %s "$PRISMA_COMPUTE_API_AUTH_RESPONSE" | jq -r '.token')


# pulls the out of the box report from the console for deployed hosts.
curl --request GET \
     --url "$TL_CONSOLE/api/v1/hosts/download" \
     --header "Authorization: Bearer $TL_JWT" > ./temp/out-of-box-report.csv



# Provides the number of unique rows based on the columns we care about
DEPLOYED_HOST_RESULTS=($( tail -n+2 ./temp/out-of-box-report.csv  | awk -F ',' '{print $1 }' | sort | uniq ))

# Loop through the number of unique lines to satisify the limit and offset parameters in the request. Writes responses to files in the host directory
for host_results_offset in "${!DEPLOYED_HOST_RESULTS[@]}"; do \

          HOST_RESPONSE=$(curl --request GET \
                               --url "$TL_CONSOLE/api/v1/hosts?hostname=${DEPLOYED_HOST_RESULTS[$host_results_offset]}" \
                               --header "Authorization: Bearer $TL_JWT" \
                               --header 'Accept: application/json')  
                      
  if [[ $HOST_RESPONSE != null ]]; then \
     printf '%s' "$HOST_RESPONSE" > "./temp/host/$(printf '%08d' "$host_results_offset").json"
  else
     echo "response is empty"
  fi
  sleep 2
 

done

printf '\n%s\n' "Finished with gathering response data. Formatting and processing will take a moment, please don't quit the process"


# Creates a file with a list of all the file paths to the responses
for host_response_file in ./temp/host/*.json; do \
  printf '%s\n' "$host_response_file" >> ./temp/host_file_response_array.txt
done

# Reads those file paths into a bash array
HOST_RESPONSE_FILE_ARR=()
while IFS= read -r line; do
  HOST_RESPONSE_FILE_ARR+=("$line")
done < ./temp/host_file_response_array.txt


printf '\n%s\n' "Formatting host response data, please wait."

# Loops through the IMAGE_RESPONSE_FILE_ARR and parses the json from the requests for vulnerability data
for host_response_index in "${!HOST_RESPONSE_FILE_ARR[@]}"; do \
  cat ${HOST_RESPONSE_FILE_ARR[$host_response_index]} | jq '[
    .[]?
    | .vulnerabilities[]? as $vuln
    | { 
        id: ._id?,
        cluster: (.clusters[]? // ""),
        cloudMetadata: (.cloudMetadata? | del(.labels) // ""),
        distro: .osDistro?, 
        distroRelease: .osDistroRelease?, 
        distroVersion: .osDistroVersion?, 
        collections: (.collections? | @sh // ""),         
        vulnerability: $vuln,
        path: (
            .binaries?
            | map(select(.name == $vuln.packageName) | .path)
            | if length > 0 then .[0] else "" end
          )
      }
    | {
        id: .id?,
        distro: .distro?,
        distroRelease: .distroRelease?,
        distroVersion: .distroVersion?,
        cve: .vulnerability.cve?,
        cvss: .vulnerability.cvss?,
        cveStatus: .vulnerability.status?,
        vulnerabilityTitle: .vulnerability.title?,
        vulnerabilityText: .vulnerability.text?,
        vectorStr: .vulnerability.vecStr?,
        exploit: .vulnerability.exploit?,
        riskFactors: (.vulnerability.riskFactors? 
          | keys 
          | @sh // ""),
        vulnerabilityDesc: .vulnerability.description?,
        severity: .vulnerability.severity?,
        vulnerabilityLink: .vulnerability.link?,
        vulnerabilityType: .vulnerability.type?,
        vulnID: .vulnerability.id?,
        sourcePackageName: .vulnerability.packageName?,
        path: (.path // ""),
        packages: (
          (.vulnerability.binaryPkgs? 
            | values 
            | @sh) // ""),
        packageVersion: .vulnerability.packageVersion?,
        discovered: .vulnerability.discovered?,
        fixDate: .vulnerability.fixDate?,
        published: .vulnerability.published?,
        accountID: .cloudMetadata.accountID?,
        cluster: .cluster?,
        cspProvider: .cloudMetadata.provider?,
        cspResourceID: .cloudMetadata.resourceID?,
        cspRegion: .cloudMetadata.region?,
        cspVMimageID: .cloudMetadata.image?,
        collections: .collections?
    }
]  
| unique 
| select(length > 0)' > ./temp/finished_vuln_$(printf '%08d' "$host_response_index").json&

done

wait

# Loops through the HOST_RESPONSE_FILE_ARR and parses the json from the requests for config/compliance issues
for host_response_index in "${!HOST_RESPONSE_FILE_ARR[@]}"; do \
  cat ${HOST_RESPONSE_FILE_ARR[$host_response_index]} | jq '[
        .[]?  
      |{
        id: ._id?,
        cluster: (.clusters[]? // ""), 
        cloudMetadata: (.cloudMetadata? | del(.labels) // ""),
        distro: .osDistro?, 
        distroRelease: .osDistroRelease?, 
        distroVersion: .osDistroVersion?,
        collections: (.collections? | @sh // ""), 
        configData: .complianceIssues[]?, 
       }
      |{
        id, 
        cloudMetadata,
        cluster,
        distro, 
        distroRelease, 
        distroVersion,
        collections: .collections?,
        configPolicyTitle: .configData.title, 
        configDescription: .configData.description, 
        severity: .configData.severity, 
        configPolicyType: .configData.type, 
        configCause: .configData.cause, 
        complianceID: .configData.id, 
        } 
      |{
        id, 
        distro, 
        distroRelease, 
        distroVersion, 
        configPolicyTitle, 
        complianceID,
        configDescription, 
        severity, 
        configPolicyType, 
        configCause,
        accountID: .cloudMetadata.accountID?,
        cluster,
        cspProvider: .cloudMetadata.provider, 
        cspResourceID: .cloudMetadata.resourceID, 
        cspRegion: .cloudMetadata.region, 
        cspVMimageID: .cloudMetadata.image,
        collections: .collections?
        }
      ] 
    | unique 
    | select(length > 0)' > ./temp/finished_config_$(printf '%08d' "$host_response_index").json&

done
wait


printf '\n%s\n' "gathering epss scores please wait" 

CVE_ARRAY_FOR_RISK=($(cat ./temp/finished_vuln_* | jq -r '.[].cve' | sort | uniq))
mkdir -p ./temp/epss

for cve in "${!CVE_ARRAY_FOR_RISK[@]}"; do \
  curl -s "https://api.first.org/data/v1/epss?cve=${CVE_ARRAY_FOR_RISK[$cve]}" > ./temp/epss/$(printf '%05d' $cve).json&
done

wait

cat ./temp/epss/*.json | jq '[.data[]| {cve, epss, percentile, epssPulldate: .date}]' > ./temp/finished_epss.json


printf '\n%s\n' "adding epss scores, this may take a moment"
for vuln_response_file in ./temp/finished_vuln_*; do \
  printf '%s\n' "$vuln_response_file" >> ./temp/for_vuln_array.txt
done

# Reads those file paths into a bash array
VULN_FILE_ARRAY=()
while IFS= read -r line; do
  VULN_FILE_ARRAY+=("$line")
done < ./temp/for_vuln_array.txt

for vuln_file in "${!VULN_FILE_ARRAY[@]}"; do \
 cat ${VULN_FILE_ARRAY[$vuln_file]} | jq ' .[] |{id,distro,distroRelease,distroVersion,cve,cvss,cveStatus,vulnerabilityTitle,vulnerabilityText,vectorStr,exploit,riskFactors,vulnerabilityDesc,severity,vulnerabilityLink,vulnerabilityType,vulnID,sourcePackageName,path,packages,packageVersion,discovered,fixDate,published,hostname,accountID,cspProvider,cspResourceID,cspRegion,cspVMimageID,collections,epss_data: [(.cve as $cve | $epss_data |..|select( .cve? and .cve==$cve ))]} | {id,distro,distroRelease,distroVersion,cve,cvss,cveStatus,vulnerabilityTitle,vulnerabilityText,vectorStr,exploit,riskFactors,vulnerabilityDesc,severity,vulnerabilityLink,vulnerabilityType,vulnID,sourcePackageName,path,packages,packageVersion,discovered,fixDate,published,hostname,accountID,cspProvider,cspResourceID,cspRegion,cspVMimageID,collections, cveEpss: .epss_data[].cve, epss: .epss_data[].epss, percentile: .epss_data[].percentile, epssPulldate: .epss_data[].epssPulldate}' --slurpfile epss_data ./temp/finished_epss.json > ./temp/completed_vuln_and_epss_$(printf '%05d' $vuln_file).json&

done

wait

# provides headers for config/compliance report
printf '%s\n' "id,distro,distroRelease,distroVersion,configPolicyTitle,complianceID,configDescription,severity,configPolicyType,configCause,accountID,cluster,cspProvider,cspResourceID,cspRegion,cspVMimageID,collections" > ./reports/config_report_hosts_$REPORT_DATE.csv

# provides headers for vulnerability report
printf '%s\n' "id,distro,distroRelease,distroVersion,cve,cvss,cveStatus,vulnerabilityTitle,vulnerabilityText,vectorStr,exploit,riskFactors,vulnerabilityDesc,severity,vulnerabilityLink,vulnerabilityType,vulnID,sourcePackageName,path,packages,packageVersion,discovered,fixDate,published,accountID,cluster,cspProvider,cspResourceID,cspRegion,cspVMimageID,collections,cveEpss,epss,percentile,epssPulldate" > ./reports/vulnerability_report_hosts_$REPORT_DATE.csv


# formats the vulnerability data into csv
cat ./temp/completed_vuln_and_epss* | jq -r ' . | [inputs] | map(.) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $rows[] | @csv'>> ./reports/vulnerability_report_hosts_$REPORT_DATE.csv

# formats the config compliance data into csv
cat ./temp/finished_config_* | jq -r ' . |map(.) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $rows[] | @csv' >> ./reports/config_report_hosts_$REPORT_DATE.csv

# user notification
printf '\n%s\n' "Reports are done, they can be retrieved from the following locations: ./reports/vulnerability_report_hosts_$REPORT_DATE.csv and ./reports/config_report_hosts_$REPORT_DATE.csv"


# remove the lines below if you want to keep the response data
{
rm -rf ./temp/*
}


exit
