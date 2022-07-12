#!/usr/bin/env bash
# Written by Kyle Butler
# Reports all the files in a particular source type (VCS) which have errors/issues. 


source ./secrets/secrets
source ./func/func.sh

# USER ASSIGNED VARIABLES

# Choose one: "Github" "Bitbucket" "Gitlab" "AzureRepos" "cli" "AWS" "Azure" "GCP" "Docker" "githubEnterprise" "gitlabEnterprise" "bitbucketEnterprise" "terraformCloud" "githubActions" "circleci" "codebuild" "jenkins" "tfcRunTasks"
SOURCE_TYPE="Github"



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

var_response_check "$PC_JWT_RESPONSE"

REPOSITORY_LIST_REQUEST=$(curl --request GET \
                               --url "$PC_APIURL/code/api/v1/repositories" \
                               --header "content-type: applicaion/json; charset=UTF-8" \
                               --header "x-redlock-auth: $PC_JWT")


var_response_check "$REPOSITORY_LIST_REQUEST"


REPOSITORY_LIST_ARRAY=( $(printf '%s' "$REPOSITORY_LIST_REQUEST" | jq -r --arg SOURCE_TYPE "$SOURCE_TYPE" '.[] | select(.source == $SOURCE_TYPE) | (.owner + "/" + .repository)' ) )

for repo in "${!REPOSITORY_LIST_ARRAY[@]}"; do

mkdir "./temp/$repo"

ERROR_FILES_PAYLOAD=$(cat <<EOF
{
     "sourceTypes": [
          "$SOURCE_TYPE"
     ],
     "repository": "${REPOSITORY_LIST_ARRAY[repo]}"
}
EOF
)

ERROR_FILES_ARRAY=$(curl --request POST \
                         --url "$PC_APIURL/code/api/v1/errors/files" \
                         --header "authorization: $PC_JWT" \
                         --header 'content-type: application/json' \
                         --data "$ERROR_FILES_PAYLOAD")

quick_check "/code/api/v1/errors/files"

FILE_PATH_ARRAY=($(printf '%s' "$ERROR_FILES_ARRAY" | jq -r '.data[].filePath' ))
FILE_ERROR_COUNT_ARRAY=($(printf '%s' "$ERROR_FILES_ARRAY" | jq -r '.data[].errorsCount' ))

for file_path in "${!FILE_PATH_ARRAY[@]}"; do

ERROR_FILE_PAYLOAD=$(cat <<EOF
{
  "sourceTypes": [
    "$SOURCE_TYPE"
  ],
    "repository": "${REPOSITORY_LIST_ARRAY[repo]}",
    "filePath": "${FILE_PATH_ARRAY[file_path]}"
  }
EOF
)

for offset in $(seq 0 10 "${FILE_ERROR_COUNT_ARRAY[file_path]}"); do

echo "${FILE_ERROR_COUNT_ARRAY[file_path]} error counts in file. offset is $offset"

curl -s --request POST \
     --url "$PC_APIURL/code/api/v1/errors/file?limit=10&offset=$offset" \
     --header "authorization: $PC_JWT" \
     --header 'content-type: application/json' \
     --data "$ERROR_FILE_PAYLOAD" > "./temp/$repo/$(printf '%05d%05d' "$file_path" "$offset").json" &
   done
  done
done

wait

for repo in "${!REPOSITORY_LIST_ARRAY[@]}"; do

if [ -d "./temp/$repo" ]
then
  if [ "$(ls -A ./temp/"$repo")" ]; then
   cat ./temp/"$repo"/*.json | jq --arg REPO "${REPOSITORY_LIST_ARRAY[repo]}" '.data[] | {repo: $REPO, filePath, frameworkType, status, author, date, runtimeId, errorId, scannerType}' > "./temp/$(printf '%05d' "$repo").json"
  else
    echo "${REPOSITORY_LIST_ARRAY[repo]} has no errors"
 fi
else
 echo "Directory ./temp/$repo not found."
fi


done
REPORT_DATE=$(date  +%m_%d_%y)

cat ./temp/*.json | jq -r  jq -n  -r '[inputs] | map({repo, filePath, frameworkType, status, author, date, runtimeId, errorId, scannerType}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' > ./reports/"code_security_report_$REPORT_DATE.csv"

{
rm -rf ./temp/*
}

printf '\n%s\n' "All done your report is in the reports directory saved as: code_security_report_$REPORT_DATE.csv"



exit
