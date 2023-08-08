#!/usr/bin/env bash
# written by Kyle Butler
# requires jq to be installed
# This will remove unused AWS credentials from the COMPUTE cloud accounts section of the Prisma Cloud Compute Platform. It will also create a report showing where the maunally created credentials are being used.

# I commented out the section of the code which does the next part so no mistakes are made. Please read the next part carefully.
# The commented out part of the code looks at registry scanning accounts and remove any credentials which were manually created to do registry scanning# This will unassociate the manually created credentials with the registry scanning feature, so that when the script is run again, those credentials can be removed. .
source ./secrets/secrets
source ./func/func.sh

pce-var-check


AUTH_PAYLOAD=$(cat <<EOF
{
 "username": "$TL_USER",
 "password": "$TL_PASSWORD"
}
EOF
)

if [ ! -d "./temp" ]
then
  mkdir ./temp
fi

if [ ! -d "./reports" ]
then
    mkdir ./reports
fi

# authenticates to the prisma compute console using the access key and secret key. If using a self-signed cert with a compute on-prem version, add -k to the curl command.·
PRISMA_COMPUTE_API_AUTH_RESPONSE=$(curl --header "Content-Type: application/json" \
                                        --request POST \
                                        --data-raw "$AUTH_PAYLOAD" \
                                        --url $TL_CONSOLE/api/v1/authenticate )


TL_JWT=$(printf '%s' "$PRISMA_COMPUTE_API_AUTH_RESPONSE" | jq -r '.token')



curl --url "$TL_CONSOLE/api/v1/credentials" \
     --header 'Accept: application/json, text/plain, */*' \
     --header "Authorization: Bearer $TL_JWT" > ./temp/credentials_response.json

curl --url "$TL_CONSOLE/api/v1/settings/registry?project=Central+Console" \
     --request GET \
     --header 'Accept: application/json, text/plain, */*' \
     --header "Authorization: Bearer $TL_JWT" > ./temp/registry_settings_response.json

cat ./temp/credentials_response.json | jq -r '.[] | select(.type == "aws") | select(._id | test("\\D")) | ._id' | sed 's/ /%20/g' > ./temp/id_list.txt
cat ./temp/credentials_response.json | jq -r '.[] | select(.type == "aws") | select(._id | test("\\D")) | .accountID' |sed 's/ /%20/g' > ./temp/account_name_list.txt



ID_ARRAY=()
while IFS= read -r line; do
   ID_ARRAY+=("$line")
done < "./temp/id_list.txt"


for id in "${!ID_ARRAY[@]}"; do \

  USAGE_RESPONSE=$(curl --url "$TL_CONSOLE/api/v1/credentials/${ID_ARRAY[$id]}/usages?project=Central+Console" \
                        --header 'Accept: application/json, text/plain, */*' \
                        --header "Authorization: Bearer $TL_JWT")

  if [[ $USAGE_RESPONSE == "null" ]];
  then
    printf '\n%s\n' "removing credentials with ID: ${ID_ARRAY[$id]} because of null usage"
    curl --request DELETE \
         --url "$TL_CONSOLE/api/v1/credentials/${ID_ARRAY[$id]}?project=Central+Console" \
         --header 'Accept: application/json, text/plain, */*' \
         --header "Authorization: Bearer $TL_JWT"
  else

    printf '%s' "$USAGE_RESPONSE" | jq --arg id "$(printf '%s' "${ID_ARRAY[$id]}" | sed 's/%20/ /g')" '.[] + {accountId: $id}' > "./temp/account_$(printf '%05d' "$id").json"

  fi

done

#cat ./temp/account_*.json | jq -r '. | select( .type == "Registry Scan" ) | .accountId' | sort | uniq > ./temp/registry_remove_list.txt

#REGISTRY_CRED_REMOVE_ARRAY=()
#  while IFS= read -r line; do
#    REGISTRY_CRED_REMOVE_ARRAY+=("$line")
#  done < "./temp/registry_remove_list.txt"

#cp ./temp/registry_settings_response.json ./temp/registry_settings_updated.json

#for cred in "${!REGISTRY_CRED_REMOVE_ARRAY[@]}"; do \
#  REGISTRY_ACCOUNTS=$(cat ./temp/registry_settings_updated.json)
#  printf '%s' "$REGISTRY_ACCOUNTS" | jq --arg credId "${REGISTRY_CRED_REMOVE_ARRAY[$cred]}" '. |del(.specifications[] | select( .credential._id == $credId ))' > ./temp/registry_settings_updated.json

#done


#printf '\n%s\n' "uploading the updated registry account list"

#curl --url "$TL_CONSOLE/api/v1/settings/registry?project=Central+Console" \
#     --request PUT \
#     --header 'Accept: application/json, text/plain, */*' \
#     --header "Authorization: Bearer $TL_JWT" \
#     --data-binary '@./temp/registry_settings_updated.json'

REPORT_DATE=$(date  +%m_%d_%y)

printf '%s\n' "type, description, credAccountId"
cat ./temp/account_*.json | jq -r '. | [.[]] | @csv' >> "./reports/credentials_in_use_$REPORT_DATE.csv"

{
  rm ./temp/*
}

printf '\n%s\n' "All credentials with null usage have been removed. If you uncommented the registry part of this script: credentials being used for registry scanning have been removed from registry scanning. Re-run the script to remove the credentials from the cloud account page. If the credentials were only being used for scanning registries then they'll be removed on the next run. Credentials being used for cloud account scanning, k8s auditing, etc. will not be removed but can be removed manually using the report"

exit
