#!/usr/bin/env bash
# written by Kyle Butler
# requires jq to be installed
# retrieves all errors (suppressed, passed) for Prisma Cloud Code Security across all onboarded projects and creates a report in csv format
# no user configuration needed
# will take a while to complete


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



REPOSITORY_LIST_REQUEST=$(curl --request GET \
                               --url "$PC_APIURL/code/api/v1/repositories" \
                               --header "content-type: applicaion/json; charset=UTF-8" \
                               --header "x-redlock-auth: $PC_JWT")


printf '%s' "$REPOSITORY_LIST_REQUEST" | jq '[.[] |{source: .source, ownerRepository: (.owner + "/" + .repository)}]' > ./temp/repository_list_$REPORT_DATE.json

REPOSITORY_LIST_ARRAY=( $(cat ./temp/repository_list_$REPORT_DATE.json | jq -r '.[]| .ownerRepository' ) )

REPO_INDEX=$( cat temp/repository_list_$REPORT_DATE.json | jq '.|length')

for index in $(seq 0 $(($REPO_INDEX -1))); do \

mkdir ./temp/$(printf '%05d' "$index")

SOURCE_TYPE=$(cat temp/repository_list_$REPORT_DATE.json | jq --argjson index "$index" '.[$index] | .source')
REPOSITORY=$(cat temp/repository_list_$REPORT_DATE.json | jq --argjson index "$index" '.[$index] | .ownerRepository')

ERROR_FILES_PAYLOAD=$(cat <<EOF
{
     "sourceTypes": [
          $SOURCE_TYPE
     ],
     "repository": $REPOSITORY
}
EOF
)


curl -s --request POST \
        --url "$PC_APIURL/code/api/v1/errors/files" \
        --header "authorization: $PC_JWT" \
        --header 'content-type: application/json' \
        --data "$ERROR_FILES_PAYLOAD" > ./temp/error_file_response_$(printf '%05d' "$index").json

FILE_PATH_ARRAY=($(cat ./temp/error_file_response_$(printf '%05d' "$index").json | jq '.data[].filePath' ))
FILE_ERROR_COUNT_ARRAY=($(cat ./temp/error_file_response_$(printf '%05d' "$index").json | jq '.data[].errorsCount' ))


if !(( $index % 100)); then \

PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")

PC_JWT=$(printf '%s' "$PC_JWT_RESPONSE" | jq -r '.token')
fi


for file_path in "${!FILE_PATH_ARRAY[@]}"; do

ERROR_FILE_PATH_PAYLOAD=$(cat <<EOF
{
  "sourceTypes": [
    $SOURCE_TYPE
  ],
    "repository": $REPOSITORY,
    "filePath": ${FILE_PATH_ARRAY[file_path]}
  }
EOF
)

for offset in $(seq 0 10 "${FILE_ERROR_COUNT_ARRAY[file_path]}"); do

echo "${FILE_ERROR_COUNT_ARRAY[file_path]} error counts in ${FILE_PATH_ARRAY[file_path]}. offset is $offset"

curl -s --request POST \
     --url "$PC_APIURL/code/api/v1/errors/file?limit=10&offset=$offset" \
     --header "authorization: $PC_JWT" \
     --header 'content-type: application/json' \
     --data "$ERROR_FILE_PATH_PAYLOAD" > "./temp/$(printf '%05d' "$index")/$(printf '%05d%05d' "$file_path" "$offset").json" &
   done
  done
done


wait
echo "collecting data please wait for this to finish"

for repo in "${!REPOSITORY_LIST_ARRAY[@]}"; do

if [ -d "./temp/$(printf '%05d' $index)" ]
then
  if [ "$(ls -A ./temp/$(printf '%05d' $index))" ]; then
   cat ./temp/$(printf '%05d' $index)/*.json | jq --arg REPO "${REPOSITORY_LIST_ARRAY[repo]}" '.data[] | {repo: $REPO, filePath, sourceType, frameworkType, status, author, date, runtimeId, errorId, scannerType}' > "./temp/finished_$(printf '%05d' "$repo").json"
  else
    echo "${REPOSITORY_LIST_ARRAY[repo]} has no errors"
 fi
else
 echo "Directory ./temp/$repo not found."
fi


done

wait

cat ./temp/finished_* > ./temp/all_errors_$REPORT_DATE.json

mkdir ./temp/policy
curl --request GET \
     --url "$PC_APIURL/code/api/v1/policies/table/data" \
     --header "Accept: application/json" \
     --header "authorization: $PC_JWT" | jq '.data[] |{id: .id, title: .title, descriptiveTitle: .descriptiveTitle, constructiveTitle: .constructiveTitle, severity: .severity, category: .category, accountsData: [.accountsData]}' > ./temp/policy/policy_response_$REPORT_DATE.json


account_query_parameters=$(cat ./temp/policy/policy_response_$REPORT_DATE.json | jq '.accountsData[] | keys | .[] ' | sort | uniq | tr -d '\n' | sed  's|""|, |g' | sed 's|"||g')

policy_id_array=($(cat ./temp/policy/policy_response_$REPORT_DATE.json | jq -r '.id' | sort | uniq))

for policy in "${!policy_id_array[@]}"; do \
  curl -s --request GET \
          --url "$PC_APIURL/code/api/v1/suppressions/${policy_id_array[policy]}/justifications?accounts=$(printf '%s' "account_query_parameters")" \
          --header "Accept: application/json" \
          --header "authorization: $PC_JWT" > ./temp/policy/suppression_response_$(printf '%05d' "$policy").json&
done
wait

cat ./temp/policy/policy_response_$REPORT_DATE.json | jq '. |{id, title, descriptiveTitle, constructiveTitle, severity, category}' > ./temp/policy/filtered_policy_response_$REPORT_DATE.json


echo "merging data please wait for this to finish, it could take a bit"

cat ./temp/all_errors_$REPORT_DATE.json | jq '. |{repo, filePath, sourceType, frameworkType, status, author, date, runtimeId, scannerType, policyInfo: [(.errorId as $id | $policy_response |..|select(.id? and .id==$id))] } | {repo: .repo, filePath: .filePath, sourceType: .sourceType, frameworkType: .frameworkType, status: .status, author: .author, date: .date, runtimeId: .runtimeId, scannerType: .scannerType, policyId: .policyInfo[0].id, policyTitle: .policyInfo[0].title, policySeverity: .policyInfo[0].severity, policyCategory: .policyInfo[0].category, policyDescriptiveTitle: .policyInfo[0].descriptiveTitle, policyConstructiveTitle: .policyInfo[0].constructiveTitle}' --slurpfile policy_response ./temp/policy/filtered_policy_response_$REPORT_DATE.json > ./temp/merged_policy_and_errors_$REPORT_DATE.json

# to do map response from suppressions to merged_policy_and_errors_DATE.json file
# cat ./temp/policy/suppression_response_* | jq '.[]' > ./temp/finished_suppression_response_$REPORT_DATE.json

cat ./temp/merged_policy_and_errors_$REPORT_DATE.json | jq -n -r '[inputs] | map({repo, filePath, sourceType, frameworkType, status, author, date, runtimeId, scannerType, policyId, policyTitle, policySeverity, policyCategory, policyDescriptiveTitle, policyConstructiveTitle}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' > ./reports/"code_security_report_$REPORT_DATE.csv"


printf '\n%s\n' "All done your report is in the reports directory saved as: code_security_report_$REPORT_DATE.csv"

## Remove to keep temp
{
rm -rf ./temp/*
}


exit
