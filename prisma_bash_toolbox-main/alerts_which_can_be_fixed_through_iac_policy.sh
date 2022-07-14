#!/usr/bin/env bash
#------------------------------------------------------------------------------------------------------------------#
# Written By Kyle Butler
#
# REQUIREMENTS: 
# Requires jq to be installed: 'sudo apt-get install jq'


### NO USER CONFIG REQUIRED

# SCRIPT WILL REPORT HOW MANY OPEN ALERTS COULD BE RESOLVED BY USING PRISMA CODE SECURITY BUILD POLICIES
# IT TAKES A WHILE TO RUN, expect to leave running for 10 mins. 

source ./secrets/secrets
source ./func/func.sh




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



POLICY_REQUEST=$(curl --request GET \
                      --url "$PC_APIURL/v2/policy" \
                      --header "x-redlock-auth: $PC_JWT")


quick_check "/v2/policy"



BUILD_POLICY_ID_ARRAY=( $(printf %s "$POLICY_REQUEST" | jq -r '.[] | select( .policySubTypes[] == "build") | .policyId') )
for policy in "${!BUILD_POLICY_ID_ARRAY[@]}"; do
  printf '\n%s\n' "Checking alert count for policyId: ${BUILD_POLICY_ID_ARRAY[policy]}"
  sleep 1
  curl -s --request GET \
          --url "$PC_APIURL/alert/policy?alert.status=open&policy.id=${BUILD_POLICY_ID_ARRAY[policy]}" \
          --header "x-redlock-auth: $PC_JWT" > ./temp/"$(printf '%05d' "$policy")".json &
done
wait

cat ./temp/*.json | jq '.[] | {policyName: .policy.name, numberOfAlerts: .alertCount} ' | jq -r -n '[inputs] | map({policyName, numberOfAlerts}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' > ./reports/"alerts_able_to_be_remediated_by_code_security_$REPORT_DATE.csv"


{
  rm -rf ./temp/*.json
}


printf '\n%s\n' "Process completed! The number of alerts which could be remediated using code security is in a report in the ./reports directory named: alerts_able_to_be_remediated_by_code_security_$REPORT_DATE.csv"
