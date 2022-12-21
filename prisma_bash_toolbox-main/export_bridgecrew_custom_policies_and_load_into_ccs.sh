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
# Exports all the custom policies written as code from the BridgeCrew console and imports them into prisma cloud. 
# As of Dec 21st 20222 only the custom policies written in YAML syntax can be exported this way. 

source ./secrets/secrets
source ./func/func.sh

# CREATE BRIDGECREW API KEY IN BRIDGECREW CONSOLE AND ASSIGN IT TO THE VAR BELOW
BC_API_KEY="<BC_API_KEY>"

###### NO EDITS BELOW NECESSARY

REPORT_DATE=$(date  +%m_%d_%y)

BRIDGECREW_POLICY_RESPONSE=$(curl --request GET \
                                   --url https://www.bridgecrew.cloud/api/v1/policies/table/data \
                                   --header 'Accept: application/json' \
                                   --header "authorization: $BC_API_KEY")
                                   
quick_check "https://www.bridgecrew.cloud/api/v1/policies/table/data"
     

printf '%s' "$BRIDGECREW_POLICY_RESPONSE" > ./temp/bridgecrew_policies_table_data.json

cat ./temp/bridgecrew_policies_table_data.json | jq --arg DATE "$REPORT_DATE" '[.data[] | select(.code != null) | {cloudType: .provider, complianceMetadata: [], description: .guideline, labels: [], name: (.title + "_" + $DATE), policySubTypes: ["build"], policyType: "config", recommendation: "", rule: { children: [{metadata: {code: .code}, type: "build", recommendation: ""}], name:  (.title + "_" + $DATE), parameters: {savedSearch: "  false", withIac: "true"}, type: "Config" }, severity: .severity }]' | sed 's/\"severity\"\: \"CRITICAL\"/\"severity\"\: \"HIGH\"  /g' > ./temp/transformed_code_policies.json

NUMBER_OF_POLICIES=$(cat ./temp/transformed_code_policies.json | jq '. |length')

NUMBER_MINUS_ONE=$(( "$NUMBER_OF_POLICIES" - 1 ))

for number in $(seq 0 "$NUMBER_MINUS_ONE"); do

  cat ./temp/transformed_code_policies.json | jq --argjson number "$number" '.[$number]' > "./temp/policy_$(printf '%04d' "$number").json"

done



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

for policy_file in ./temp/policy_*.json; do

curl --request POST \
     --header 'content-type: application/json; charset=UTF-8' \
     --url "$PC_APIURL/policy" \
     --header "x-redlock-auth: $PC_JWT" \
     --data-binary @"$policy_file"

quick_check "/policy"

printf '\n%s\n' "policy uploaded" 

done

# clean up task
{
rm ./temp/*.json
}

printf '\n%s\n' "Custom policies written as code (not the GUI ones) have been exported from your bridgecrew console and loaded into your prisma console"

exit
