#!/usr/bin/env bash
# written by Kyle Butler
# requires jq to be installed
# retrieves the suppressions for Prisma Cloud Code Security across all onboarded projects and creates a report in csv format
# no user configuration needed
# to convert the (suppression) date to human readable UTC use this excel formula
# =(B<row_number>/86400000)+DATE(1970,1,1) 
# make sure to format the new column with a date format 


source ./secrets/secrets
source ./func/func.sh


REPORT_DATE=$(date  +%m_%d_%y)


AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)


PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")



PC_JWT=$(printf %s "$PC_JWT_RESPONSE" | jq -r '.token' )


curl --request GET \
     --url "$PC_APIURL/code/api/v1/policies/table/data" \
     --header "Accept: application/json" \
     --header "authorization: $PC_JWT" | jq '.data[] |{id: .id, title: .title, descriptiveTitle: .descriptiveTitle, constructiveTitle: .constructiveTitle, severity: .severity, category: .category, accountsData: [.accountsData]}' > ./temp/policy_response_$REPORT_DATE.json


account_query_parameters=$(cat ./temp/policy_response_$REPORT_DATE.json | jq '.accountsData[] | keys | .[] ' | sort | uniq | tr -d '\n' | sed  's|""|, |g' | sed 's|"||g')

policy_id_array=($(cat ./temp/policy_response_$REPORT_DATE.json | jq -r '.id' | sort | uniq))

for policy in "${!policy_id_array[@]}"; do \
  curl -s --request GET \
          --url "$PC_APIURL/code/api/v1/suppressions/${policy_id_array[policy]}/justifications?accounts=$(printf '%s' "account_query_parameters")" \
          --header "Accept: application/json" \
          --header "authorization: $PC_JWT" > ./temp/suppression_response_$(printf '%05d' "$policy").json&
done
wait
cat temp/suppression_response_* | jq '.[]' > ./temp/finished_suppression_response_$REPORT_DATE.json

cat ./temp/policy_response_$REPORT_DATE.json | jq '. |{id: .id, title: .title, descriptiveTitle: .descriptiveTitle, constructiveTitle: .constructiveTitle, severity: .severity, category: .category, repo: path(.accountsData[] |..| select( .amounts?.SUPPRESSED > 0)) | .[2]}' > ./temp/policy_response_modified_$REPORT_DATE.json

cat ./temp/finished_suppression_response_$REPORT_DATE.json | jq '. | {customer: .customer, date: .date, resources: .resources, comment: .comment, suppressionType: .suppressionType, origin: .origin, type: .type, active: .active, policyInfo: [(.violationId as $id | $policy_response |..|select(.id? and .id==$id))]}' --slurpfile policy_response "./temp/policy_response_modified_$REPORT_DATE.json" > ./temp/merged_finished_$REPORT_DATE.json

printf '%s\n' 'customer, date, resource,comment,suppressionType, origin, type, active, policyId, policyTitle, policyDescriptiveTitle, policyConstructiveTitle, policySeverity, policyCategory, projectRepo' >  ./reports/prisma_code_security_suppression_report_$REPORT_DATE.csv


cat ./temp/merged_finished_$REPORT_DATE.json | jq -r '[. | {customer: .customer, date: .date, resource: .resources[], comment: .comment, suppressionType: .suppressionType, origin: .origin, type: .type, active: .active, policyInfo: .policyInfo[]}? | {customer: .customer, date: .date, resource: .resource, comment: .comment, suppressionType: .suppressionType, origin: .origin, type: .type, active: .active, policyId: .policyInfo.id, policyTitle: .policyInfo.title, policyDescriptiveTitle: .policyInfo.descriptiveTitle, policyConstructiveTitle: .policyInfo.constructiveTitle, policySeverity: .policyInfo.severity, policyCategory: .policyInfo.category, projectRepo: .policyInfo.repo}]? | map({customer, date, resource,comment,suppressionType, origin, type, active, policyId, policyTitle, policyDescriptiveTitle, policyConstructiveTitle, policySeverity, policyCategory, projectRepo}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $rows[] | @csv' >> ./reports/prisma_code_security_suppression_report_$REPORT_DATE.csv


printf '\n\n%s\n' "All done! Your report is in the ./reports directory saved as: ./reports/prisma_code_security_suppression_report_$REPORT_DATE.csv"


# comment out/delete below lines if you'd like to keep the temp files
{
rm -f ./temp/*
}
