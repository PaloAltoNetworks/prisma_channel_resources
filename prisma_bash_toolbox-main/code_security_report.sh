#!/usr/bin/env bash
# Written by Kyle Butler
# Requires jq to be installed
# Retrieves all errors 
# No user configuration needed
# Updated with the new CAS APIs
# Retrieves secrets, iac misconfigs, license issues, vulnerabilities, and other errors from onboarded projects/repos
# Utilizes multiprocessing without flock

source ./secrets/secrets
source ./func/func.sh

REPORT_DATE=$(date +%m_%d_%y)

AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)


retrieve_prisma_jwt() {

PC_JWT_RESPONSE=$(curl --silent --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")

PC_JWT=$(printf %s "$PC_JWT_RESPONSE" | jq -r '.token' )
}


retrieve_prisma_jwt


curl --silent --url "$PC_APIURL/code/api/v1/repositories" \
     --header 'Accept: application/json' \
     --header "authorization: $PC_JWT" > ./temp/repo_response.json

REPOSITORY_ID_ARRAY=($(jq -r '.[].id' ./temp/repo_response.json))

# Number of parallel workers
NUM_WORKERS=5

# Function to fetch pages assigned to each worker
function fetch_pages() {
  local WORKER_ID=$1
  local OFFSET=$(( (WORKER_ID - 1) * 100 ))
  local LIMIT=100
  local STEP=$(( NUM_WORKERS * LIMIT ))

  while true; do
    VCS_SCAN_ISSUES_PAYLOAD=$(jq -n \
      --argjson repositories "$(printf '%s\n' "${REPOSITORY_ID_ARRAY[@]}" | jq -R . | jq -s .)" \
      --arg branch "main" \
      --arg checkStatus "Error" \
      --argjson offset "$OFFSET" \
      --argjson limit "$LIMIT" \
      --argjson codeCategories '["IacMisconfiguration","Vulnerabilities","Licenses","Secrets","Weaknesses"]' \
      --argjson sortBy '[{"key": "Severity","direction": "DESC"},{"key": "Count","direction": "DESC"}]' \
      '{
        filters: {
          repositories: $repositories,
          branch: $branch,
          checkStatus: $checkStatus,
          codeCategories: $codeCategories
        },
        offset: $offset,
        search: {
          scopes: [],
          term: ""
        },
        limit: $limit,
        sortBy: $sortBy
      }'
    )

    echo "Worker $WORKER_ID fetching offset $OFFSET"

    RESPONSE_FILE="./temp/vcs_response_$(printf '%06d' "${OFFSET}").json"

    curl --silent --url "$PC_APIURL/bridgecrew/api/v2/errors/branch_scan/resources" \
         --header "Authorization: $PC_JWT" \
         --header 'Accept: application/json, text/plain, */*' \
         --header 'Content-Type: application/json' \
         --data-raw "$VCS_SCAN_ISSUES_PAYLOAD" > "$RESPONSE_FILE"

    ITEMS=$(jq -r '.data | length' "$RESPONSE_FILE")
    HAS_NEXT=$(jq -r '.hasNext' "$RESPONSE_FILE")

    if [[ "$ITEMS" -eq 0 ]]; then
      echo "Worker $WORKER_ID found no items at offset $OFFSET. Exiting."
      break
    fi

    if [[ "$HAS_NEXT" != "true" ]]; then
      echo "Worker $WORKER_ID has no more pages after offset $OFFSET. Exiting."
      break
    fi

    OFFSET=$(( OFFSET + STEP ))
  done
}

# Start multiple worker processes
for (( WORKER_ID=1; WORKER_ID<=NUM_WORKERS; WORKER_ID++ )); do
  fetch_pages "$WORKER_ID" &
done

# Wait for all background processes to finish
wait

echo "All error files have been gathered"

# Combine all JSON files into one
cat ./temp/vcs_response_* | jq -r '.data[] | {counter, fixableIssuesCount, resourceName, resourceUuid, filePath, codeCategory, repository, severity, sourceType, frameworkType}' > ./temp/vcs_all.json

# Prepare repository data
jq '[.[] | {id, repository, source, owner, defaultBranch, isPublic, runs, creationDate, lastScanDate, vcsTokens, description, url, repositoryName: (.owner + "/" + .repository)}]' ./temp/repo_response.json > ./temp/repo_all.json

# Combine VCS and repository data
jq '. | {counter, fixableIssuesCount, resourceName, resourceUuid, filePath, codeCategory, repository, severity, sourceType, frameworkType, repoInfo: [(.repository as $repositoryName | $repo_all | .. | select(.repositoryName? and .repositoryName == $repositoryName))]} | {counter, fixableIssuesCount, resourceName, resourceUuid, filePath, codeCategory, repository, severity, sourceType, frameworkType, repoId: .repoInfo[].id, scanBranch: .repoInfo[].defaultBranch, isPublic: .repoInfo[].isPublic, runs: .repoInfo[].runs, repoCreationDate: .repoInfo[].creationDate, repoLastScanDate: .repoInfo[].lastScanDate, repoDescription: .repoInfo[].description, repoUrl: .repoInfo[].url}' ./temp/vcs_all.json --slurpfile repo_all ./temp/repo_all.json > ./temp/combined_vcs_repo.json

# De-duplicate data
cat ./temp/combined_vcs_repo.json | jq '. | [inputs] |map({resourceUuid, repoId, scanBranch, counter, codeCategory}) | unique' > ./temp/de_duped_vcs_repo.json

FILE_ERROR_INDEX_LENGTH=$(jq 'length' ./temp/de_duped_vcs_repo.json | tr -d '\n')

# Set the maximum number of parallel jobs
MAX_PARALLEL_JOBS=10


# Function to process each item with pagination support
function process_item() {
  local i=$1

# Refresh JWT every 100 requests so it doesn't timeout

  if ! (( $i % 100 )); then \
    retrieve_prisma_jwt
  fi

  echo "Processing item $i out of $FILE_ERROR_INDEX_LENGTH"

  RESOURCE_UUID=$(jq -r --argjson i "$i" '.[$i].resourceUuid' ./temp/de_duped_vcs_repo.json)
  REPO_ID=$(jq -r --argjson i "$i" '.[$i].repoId' ./temp/de_duped_vcs_repo.json)
  SCAN_BRANCH=$(jq -r --argjson i "$i" '.[$i].scanBranch' ./temp/de_duped_vcs_repo.json)
  CODE_CATEGORY=$(jq -r --argjson i "$i" '.[$i].codeCategory' ./temp/de_duped_vcs_repo.json)

  # Debug: Print variable values
  #echo "RESOURCE_UUID: $RESOURCE_UUID"
  #echo "REPO_ID: $REPO_ID"
  #echo "SCAN_BRANCH: $SCAN_BRANCH"
  #echo "CODE_CATEGORY: $CODE_CATEGORY"

  # Check for empty variables
  if [[ -z "$RESOURCE_UUID" || -z "$REPO_ID" || -z "$SCAN_BRANCH" || -z "$CODE_CATEGORY" ]]; then
    echo "Error: One or more required variables are empty. Skipping item $i."
    return
  fi
  # Calculate group number and directory
  local group_num=$(( i / 1000 + 1 ))
  local group_dir="./temp/group_${group_num}"
  mkdir -p "$group_dir"

  local OFFSET=0
  local LIMIT=100
  local HAS_NEXT=true
  local PAGE=1

  while [[ "$HAS_NEXT" == "true" ]]; do
    echo "Fetching page $PAGE for item $i with offset $OFFSET"

    # Construct FILE_ERROR_PAYLOAD using a heredoc and update offset
    FILE_ERROR_PAYLOAD=$(cat <<EOF
{
  "filters": {
    "repositories": ["$REPO_ID"],
    "branch": "$SCAN_BRANCH",
    "checkStatus": "Error",
    "codeCategories": [
      "IacMisconfiguration",
      "Vulnerabilities",
      "Licenses",
      "Secrets",
      "Weaknesses"
    ]
  },
  "codeCategory": "$CODE_CATEGORY",
  "limit": $LIMIT,
  "offset": $OFFSET,
  "sortBy": [],
  "search": {
    "scopes": [],
    "term": ""
  }
}
EOF
)

    # Debug: Print FILE_ERROR_PAYLOAD
    #echo "FILE_ERROR_PAYLOAD:"
    #echo "$FILE_ERROR_PAYLOAD" | jq

    RESPONSE_FILE="${group_dir}/file_error_${i}_page_$(printf '%04d' "$PAGE").json"

    curl --silent "$PC_APIURL/bridgecrew/api/v2/errors/branch_scan/resources/$RESOURCE_UUID/policies" \
         --header 'accept: application/json, text/plain, */*' \
         --header 'accept-language: en-US,en;q=0.9' \
         --header "authorization: $PC_JWT" \
         --header 'content-type: application/json' \
         --data-raw "$FILE_ERROR_PAYLOAD" > "$RESPONSE_FILE"

    # Check for API errors
    if grep -q '"error"' "$RESPONSE_FILE"; then
      echo "Error in API response for item $i, page $PAGE:"
      cat "$RESPONSE_FILE"
      break
    fi

    # Determine if there is a next page
    HAS_NEXT=$(jq -r '.hasNext' "$RESPONSE_FILE")
    ITEMS=$(jq -r '.data | length' "$RESPONSE_FILE")

    if [[ "$HAS_NEXT" != "true" ]]; then
      echo "No more pages for item $i."
      break
    fi

    # Increment offset and page number for the next iteration
    OFFSET=$((OFFSET + LIMIT))
    PAGE=$((PAGE + 1))
  done
}


echo "gathering errors"
# Loop through items and process them in parallel
for index in $(seq 0 $(( $FILE_ERROR_INDEX_LENGTH - 1 ))); do
  # Start the process in the background
  process_item "$index" &
   while (( $(jobs -rp | wc -l) >= MAX_PARALLEL_JOBS )); do
  # Wait for any job to finish
   sleep 0.1
  done
done

# Wait for all background processes to finish
wait

echo "All items have been processed."

# --- Add the following code to combine group files ---

echo "Combining group files into combined JSON files..."

# Loop through the group_* directories
for group_dir in ./temp/group_*; do
  if [ -d "$group_dir" ]; then
    group_name=$(basename "$group_dir")
    group_number=${group_name#group_}
    combined_file="./temp/combined_${group_name}.json"

    echo "Combining files in $group_dir into $combined_file"

    # Combine all 'data' arrays from the JSON files into one array
    find "$group_dir" -type f -name '*.json' -print0 | \
      xargs -0 jq -s '[.[] | .data[]]' > "$combined_file"
  fi
done


echo "All group files have been combined."

echo "Combining all combined_group_*.json files into finished_group_errors.json..."

# Combine all combined_group_*.json files into one JSON file
jq -s '[.[] | .[]]' ./temp/combined_group_*.json > ./temp/finished_group_errors.json

echo "All group files have been combined into finished_group_errors.json."

echo "Combining all data into a csv, this may take a moment"

jq '
  . as $repo_data |
  $error_data[] |    # Access the array inside $error_data
  .[] |              # Iterate over each error object
  select(
    .resourceUuid == $repo_data.resourceUuid and
    .codeCategory == $repo_data.codeCategory
  ) |
  {
    resourceName: $repo_data.resourceName,
    resourceUuid: $repo_data.resourceUuid,
    filePath: $repo_data.filePath,
    codeCategory: $repo_data.codeCategory,
    repository: $repo_data.repository,
    sourceType: $repo_data.sourceType,
    frameworkType: $repo_data.frameworkType,
    repoId: $repo_data.repoId,
    scanBranch: $repo_data.scanBranch,
    isPublic: $repo_data.isPublic,
    runs: $repo_data.runs,
    repoCreationDate: $repo_data.repoCreationDate,
    repoLastScanDate: $repo_data.repoLastScanDate,
    repoDescription: $repo_data.repoDescription,
    repoUrl: $repo_data.repoUrl,
    issue: .policy,
    severity: .severity,
    iacResourceName: .resourceName?,
    resourceId: .resourceId?,
    violationId: .violationId,
    riskFactors: (.riskFactors? |@sh // ""),
    cvss: .cvss?,
    causePackageName: .causePackageName?,
    causePackageId: .causePackageId?,
    firstDetected: .firstDetected?,
    containerImageName: (.labels[0]?.metadata?.imageName? // ""),
    metaDataInfo: (.labels[]?.label? // ""),
    secretsValidationStatus: .secretValidationStatus?,
    secretValidationCode: .resourceCode?,
    secretCommitHash: .commitHash?,
    secretCreatedBy: .createdBy,
    secretCreateDate: .createdOn?,
    license: .license?
  }
' --slurpfile error_data ./temp/finished_group_errors.json ./temp/combined_vcs_repo.json > ./temp/completed_combined_data.json




cat ./temp/completed_combined_data.json | jq -n -r '[inputs] | map({sourceType, repository, repoCreationDate, repoLastScanDate, repoDescription, repoUrl, codeCategory, frameworkType, severity, scanBranch, isPublic, filePath, resourceName, resourceId, iacResourceName, issue, violationId, riskFactors, cvss, causePackageName, causePackageId, firstDetected, containerImageName, metaDataInfo,  secretsValidationStatus, secretValidationCode, secretCommithash, secretCreateDate, license }) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' > ./reports/code_security_report_$REPORT_DATE.csv


printf '\n%s\n' "All done your report is in the reports directory saved as: code_security_report_$REPORT_DATE.csv"

{
rm -rf ./temp/*
}




exit
