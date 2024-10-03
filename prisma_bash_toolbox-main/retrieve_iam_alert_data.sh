#!/usr/bin/env bash
# written by Kyle Butler
# requires jq to be installed
# gets the full alert data for each IAM alert which is open
# specifically the granted by fields

source ./secrets/secrets

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


# creates temp directory if it doesn't exist
if [ ! -d ./temp ]; then
  mkdir ./temp
fi




# gets alerts from the last year related to IAM
ALERT_URL="$PC_APIURL/v2/alert?timeType=relative&timeAmount=1&timeUnit=year&detailed=true&policy.type=iam&alert.status=open"


gather_iam_alerts () {
  local iam_alert_url=$1
  local file_name=$2

curl --url "$iam_alert_url" \
     --header 'Accept: application/json' \
     --header "x-redlock-auth: $PC_JWT" > "$file_name"
}

IAM_ALERT_RESPONSE_FILE="./temp/iam_alert_response.json"

gather_iam_alerts "$ALERT_URL" "$IAM_ALERT_RESPONSE_FILE"


while true; do

  NEXT_PAGE_TOKEN=$(jq -r '.nextPageToken // empty' "$IAM_ALERT_RESPONSE_FILE")

  if [[ -z "$NEXT_PAGE_TOKEN" ]]; then
    echo "no more alerts. exiting loop"
    break
  fi
  ((FILE_COUNTER++))

  NEXT_URL="$ALERT_URL&pageToken=$NEXT_PAGE_TOKEN"
  IAM_ALERT_RESPONSE_FILE="./temp/iam_alert_response_$FILE_COUNTER.json"

  echo "gathering next page: $NEXT_URL"
  gather_iam_alerts "$NEXT_URL" "$IAM_ALERT_RESPONSE_FILE"
done


# parses the response and gets a single alert id for each policy
IAM_ALERTS=( $(cat ./temp/iam_alert_response*.json | jq -r '[.items[] | {alertId: .id, policyName: .policy.name}] | group_by(.policyName) | map({policyName: .[0].policyName, alertIds: map(.alertId)}) |sort | .[] | {policyName: .policyName, alertId: .alertIds[0]} | .alertId') )





# for each alertId get the RQL logic behind the policy
for alert in "${!IAM_ALERTS[@]}"; do \
  curl --url "$PC_APIURL/api/v1/permission/alert/search?alertId=${IAM_ALERTS[$alert]}" \
       --header 'Accept: application/json' \
       --header "x-redlock-auth: $PC_JWT" > ./temp/rql_$(printf '%04d' "$alert").json&
done
wait

# parse the response for the rql query and write it to a file
cat ./temp/rql_* | jq -r '.query' > ./temp/rql_array.json

# read each line in the file into an array
IAM_RQL_ARRAY=()
while IFS= read -r line; do
  IAM_RQL_ARRAY+=("$line")
done < ./temp/rql_array.json


# for each rql query in the array get all the alert data
for rql_query in "${!IAM_RQL_ARRAY[@]}"; do \


PAYLOAD=$(cat <<EOF
{
  "query": "${IAM_RQL_ARRAY[$rql_query]}",
  "groupByFields": [
    "source",
    "sourceCloudAccount",
    "grantedByEntity",
    "entityCloudAccount",
    "grantedByPolicy",
    "policyCloudAccount",
    "grantedByLevel",
    "action",
    "destination",
    "destCloudAccount",
    "lastAccess"
  ]
}
EOF
)

# get all the alert data and write to a file in temp
curl --url "$PC_APIURL/iam/api/v4/search/permission" \
     --header 'accept: application/json' \
     --header 'accept-language: en-US,en;q=0.9' \
     --header 'content-type: application/json' \
     --header "x-redlock-auth: $PC_JWT" \
     --data-raw "$PAYLOAD" > ./temp/alert_$(printf '%08d' "$rql_query").json&
done
wait

# combine all the alert data from the temp folder into a combined_alert.json
cat ./temp/alert_* > ./reports/finished_combined_alert.json


echo "all IAM alert data is in the ./reports/finished_combined_alert.json file"

## Remove to keep temp
{
rm -rf ./temp/*
}

exit
