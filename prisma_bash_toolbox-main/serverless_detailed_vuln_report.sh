#!/usr/bin/env bash
# written by Kyle Butler
# requires jq to be installed
# creates a vulnerability report with more data than is available through the UI through compute api endpoint

# retrieves the variables from the secrets file
source ./secrets/secrets
source ./func/func.sh


REPORT_DATE=$(date  +%m_%d_%y)

retrieve_token () {

AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)


PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")

PC_JWT=$(printf '%s' "$PC_JWT_RESPONSE" | jq -r '.token')



PRISMA_COMPUTE_API_AUTH_RESPONSE=$(curl --header "Content-Type: application/json" \
                                        --request POST \
                                        --data-raw "$AUTH_PAYLOAD" \
                                        --url "$TL_CONSOLE/api/v1/authenticate" )


TL_JWT=$(printf '%s' "$PRISMA_COMPUTE_API_AUTH_RESPONSE" | jq -r '.token')
}

retrieve_token


curl --request GET "$TL_CONSOLE/api/v1/serverless/download" \
     --header "Authorization: Bearer $TL_JWT" > ./temp/response_temp_dl.csv

TOTAL_FUNCTIONS_PLUS_ONE=$( cat ./temp/response_temp_dl.csv |  awk -F "," '{ print $4}' | sort | uniq | wc -l)

TOTAL_FUNCTIONS=$(( $TOTAL_FUNCTIONS_PLUS_ONE - 1))

echo "$TOTAL_FUNCTIONS"

for function_offset in $(seq 0 50 "$TOTAL_FUNCTIONS"); do \
  if [ $(( $function_offset % 1500 )) -eq 0 ]; then \
    echo "sleeping for 60 seconds to avoid rate limit";
    sleep 60
    retrieve_token
  fi

  curl --request GET "$TL_CONSOLE/api/v1/serverless?offset=$function_offset&limit=50" \
       --header 'Accept: application/json' \
       --header "Authorization: Bearer $TL_JWT" > "./temp/serverless_$(printf '%06d' "$function_offset").json"
done


cat ./temp/serverless* | jq '.[] | {provider: .provider, accountID: .accountID, applicationName: .applicationName,id: ._id,architecture: .architecture,platform: .platform, vulnerabilities: .vulnerabilities[]?} | {provider, accountID, applicationName, id, architecture, platform, cveId: .vulnerabilities.cve, packages: .vulnerabilities.packageName, sourcePkg: .vulnerabilities.binaryPkgs, packageVersion: .vulnerabilities.packageVersion, cvss: .vulnerabilities.cvss, status: .vulnerabilities.status, fixDate: .vulnerabilities.fixDate, graceDays: .vulnerabilities.gracePeriodDays, riskFactors: (.vulnerabilities.riskFactors|keys|@sh), vulnerabilityTags: .vulnerabilities.vulnTagInfos, description: .vulnerabilities.description, cause: .vulnerabilities.cause, customLabel: .vulnerabilities.custom, published: .vulnerabilities.published, discovered: .vulnerabilities.discovered,vulnerabilityLink: .vulnerabilities.link, vulnerableLayer: .vulnerabilities.functionLayer,  collections: .collections?}' > ./temp/combined_serverless_temp.json


cat ./temp/combined_serverless_temp.json| jq -n -r '[inputs] | map({provider, accountID, applicationName, id, architecture, platform, cveId, packages, sourcePkg, packageVersion, cvss, status, fixDate, graceDays, riskFactors, vulnerabilityTags, description, cause, customLabel, published, discovered, vulnerabilityLink, vulnerabilityLayer, collections}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' > ./reports/serverless_vulnerability_report_$REPORT_DATE.csv

printf '\n%s\n' "All done your report is in the reports directory saved as: serverless_vulnerability_report_$REPORT_DATE.csv"

## Remove to keep temp
{
rm -rf ./temp/*
}
