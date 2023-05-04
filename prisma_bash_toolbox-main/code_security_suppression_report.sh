#!/usr/bin/env bash
# written by Kyle Butler
# requires jq to be installed
# retrieves all suppressions for Prisma Cloud Code Security across all onboarded projects and creates a report in csv format
# no user configuration needed
# to convert the (suppression) date to human readable UTC use this excel formula
# =(Q<row_number>/86400000)+DATE(1970,1,1) 
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


curl --request GET \
     --url "$PC_APIURL/code/api/v1/suppressions" \
     --header "Accept: application/json" \
     --header "authorization: $PC_JWT"  | jq '.[] | {suppressionType: .suppressionType, id: .id, policyId: .policyId, creationDate: .creationDate, comment: .comment, accountIds: (.accountIds? |..| .?), tagsKey: (.tags? |..| .key?), tagsValue: (.tags? |..| .value?), resources: (.resources[]?|..| .resourceId?), repoId: (.resources[]? |..| .accountId?)}' > ./temp/suppressions_response_$REPORT_DATE.json




cat ./temp/suppressions_response_$REPORT_DATE.json | jq '. | {suppressionType: .suppressionType, id: .id, policyId: .policyId, creationDate: .creationDate, comment: .comment, accountIds: .accountIds, tagsKey: .tagsKey, tagsValue: .tagsValue, resource: .resources, repoId: .repoId, policyInfo: [( .policyId as $policyId | $policy_response |..| select(.id? and .id==$policyId))]} | {suppressionType, id, policyId, creationDate, comment, accountIds, tagsKey, tagsValue, resource, repoId, policyTitle: .policyInfo[0].title, policySeverity: .policyInfo[0].severity, policyCategory: .policyInfo[0].category, policyDescriptiveTitle: .policyInfo[0].descriptiveTitle, policyConstructiveTitle: .policyInfo[0].constructiveTitle}' --slurpfile policy_response ./temp/policy_response_$REPORT_DATE.json > ./temp/merged_suppressions_and_policy_response_$REPORT_DATE.json




cat ./temp/merged_suppressions_and_policy_response_$REPORT_DATE.json | jq '. | {suppressionType, id, policyId, creationDate, comment, accountIds, tagsKeys, tagsValue, resource, repoId, policyTitle, policySeverity, policyCategory, policyDescriptiveTitle, policyConstructiveTitle, suppressInfo: [( .id as $suppression_id | $finished_suppression |..| select(.id? and .id==$suppression_id))]} | {suppressionType, id, policyId, creationDate, comment, accountIds, tagKeys: .tagsKeys, tagValues: .tagValues, resource, repoId, policyTitle, policySeverity, policyCategory, policyDescriptiveTitle, policyConstructiveTitle, suppressionId: .suppressInfo[0]?.id?, suppressionDate: .suppressInfo[0]?.date?, suppressionOwner: .suppressInfo[0]?.owner?, suppressionComment: .suppressInfo[0]?.comment, suppressionOrigin: .suppressInfo[0]?.origin?, suppressionActive: .suppressInfo[0]?.active?}' --slurpfile finished_suppression ./temp/finished_suppression_response_$REPORT_DATE.json > ./temp/completed_merged_response_$REPORT_DATE.json




cat ./temp/completed_merged_response_$REPORT_DATE.json | jq -n -r '[inputs] | map({suppressionType, id, policyId, creationDate, comment, accountIds, tagKeys, tagValues, resource, repoId, policyTitle, policySeverity, policyCategory, policyDescriptiveTitle, policyConstructiveTitle, suppressionId, suppressionDate, suppressionOwner, suppressionComment, suppressionOrigin, suppressionActive})| (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' > ./reports/code_security_suppression_report_$REPORT_DATE.csv



printf '\n%s\n' "All done your report is in the reports directory saved as: ./reports/code_security_suppression_report_$REPORT_DATE.csv"

## Remove to keep temp
{
rm -rf ./temp/*
}

exit
