#!/usr/bin/env bash

# Author: Naman Shah

# REQUIREMENTS: 
# Requires jq to be installed: 'sudo apt-get install jq'

# SET-UP:
# Create Access Key and Secret Key in the Prisma Cloud Console
# Access keys and Secret keys are created in the Prisma Cloud Console under: Settings > Access Keys
# Find the Prisma Cloud Enterprise Edition API URL specific to your deployment: https://api3.prismacloud.io


# Script to interact with Prisma Cloud API to fetch and aggregate ci/cd risks
# ---------------------------------------------------------------------------------
# This script performs the following tasks:
# 1. Retrieves authentication credentials from environment variables.
# 2. Authenticates with Prisma Cloud API and obtains an authorization token.
# 3. Fetches a list of policy IDs and iteratively retrieves detailed policy data of ci/cd risks.
# 4. Extracts and processes relevant policy and risk information, appending it to a CSV file.
# 5. Supports pagination for fetching large sets of alerts associated with each policy.
# 6. Outputs results into a structured CSV file for further analysis.

# Variables
outputfile="./reports/prisma_ci_cd_risks.csv" # Output file

BASE_URL="https://api3.prismacloud.io"     # Base URL for Prisma Cloud API

# Ensure necessary directories exist
mkdir -p ./temp
mkdir -p ./reports
mkdir -p ./secrets
mkdir -p ./func

source ./secrets/secrets
source ./func/func.sh

# Prepare the authentication payload for login request
AUTH_PAYLOAD=$(cat <<EOF
{
  "username": "$TL_USER",
  "password": "$TL_PASSWORD"
}
EOF
)

# Authenticate and obtain a JWT token
PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$BASE_URL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")

# Extract Auth Token from the response
PC_AUTH_TOKEN=$(echo "$PC_JWT_RESPONSE" | jq -r '.token')

# Fetch the array of policy IDs
policy_ids=$(curl -s "$BASE_URL/bridgecrew/api/v1/pipeline-risks" \
                  -X 'POST' \
                  -H 'Accept: application/json, text/plain, */*' \
                  -H 'Accept-Language: en-US,en;q=0.9' \
                  -H "Authorization: ${PC_AUTH_TOKEN}" \
                  -H 'Connection: keep-alive' \
                  -H 'Content-Length: 0'  | jq -r '.data[].policyId')

# Create or clear the output CSV file
echo "PolicyID,Name,Severity,System,Category,Description,Steps_to_solve,Title,Details,DetectedOn" > ${outputfile}

# Loop through each policy ID
for POLICY_ID in $policy_ids; do
  echo "Processing Policy ID: $POLICY_ID"

  # Fetch policy details
  policy_details=$(curl -s "$BASE_URL/bridgecrew/api/v1/pipeline-risks/$POLICY_ID/details" \
                        -H 'Accept: application/json, text/plain, */*' \
                        -H 'Accept-Language: en-US,en;q=0.9' \
                        -H "Authorization: ${PC_AUTH_TOKEN}" \
                        -H 'Connection: keep-alive' \
                        -H 'Content-Type: application/json' \
                        --data-raw '{}')

  # Extract policy details
  policy_id=$(echo "$policy_details" | jq -r '.data.policyId')
  name=$(echo "$policy_details" | jq -r '.data.name')
  severity=$(echo "$policy_details" | jq -r '.data.severity')
  system=$(echo "$policy_details" | jq -r '.data.system')
  category=$(echo "$policy_details" | jq -r '.data.category')
  description=$(echo "$policy_details" | jq -r '.data.description' | sed 's/\\n/ /g')
  steps_to_solve=$(echo "$policy_details" | jq -r '.data.stepsToSolve' | sed -e 's/–/-/g' -e 's/\n/ /g' -e 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Initialize pagination variables
  LIMIT=100
  OFFSET=0
  HAS_NEXT=true
  TOTAL=0

  # Fetch all data for the policy
  while $HAS_NEXT; do
    response=$(curl -s "$BASE_URL/bridgecrew/api/v1/pipeline-risks/$POLICY_ID/alerts?limit=$LIMIT&offset=$OFFSET" \
      -H 'Accept: application/json, text/plain, */*' \
      -H 'Accept-Language: en-US,en;q=0.9' \
      -H "Authorization: ${PC_AUTH_TOKEN}" \
      -H 'Connection: keep-alive' \
      -H 'Content-Type: application/json' \
      --data-raw '{"status":"open"}')

    # Extract findings and append to CSV
    echo "$response" | jq -r --arg policy_id "$policy_id" --arg name "$name" --arg severity "$severity" --arg system "$system" --arg category "$category" --arg description "$description" --arg steps_to_solve "$steps_to_solve" \
      '.data[] | [$policy_id, $name, $severity, $system, $category, $description, $steps_to_solve, .title, .details, .detectedOn] | @csv' | sed 's/<[^>]*>//g' >> ${outputfile}

    HAS_NEXT=$(echo "$response" | jq -r '.hasNext // false')
    TOTAL=$(echo "$response" | jq -r '.total // 0')
    OFFSET=$((OFFSET + LIMIT))
  done

  echo "Policy ID: $POLICY_ID, Total Findings: $TOTAL"
done

echo ""All done! Your report is in the ./reports directory saved as prisma_ci_cd_risks.csv"
