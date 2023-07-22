#!/usr/bin/env bash
# author Kyle Butler
# to run: `bash ./<script_name>.sh`
# requires jq to be installed

# This is an interesting usecase. In order to operationalize you'd need to leverage resource lists and user roles in Prisma Cloud.
# The problem this solves is getting vulnerability data and compliance/config data to the appropriate owners
# You must have defined namespaces (no "*") in a resource list and associate users to a role with the resource list in it.
# What this will do is create reports for each resource list in the reports directory.
# Each resource list report directory will have a sub directory which contains two reports (vuln & compliance/config) specific to each namespace.
# In each resource list report directory there will also be an email list to send the reports to.
# YOU MUST ENSURE YOUR RESOURCE LISTS DON'T CONTAIN ANY SPACES in their name.


source ./secrets/secrets


date=$(date +%Y%m%d-%H%M)

retrieve_token () {
AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)


PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")

PC_JWT=$(printf '%s' "$PC_JWT_RESPONSE" | jq -r '.token')



PRISMA_COMPUTE_API_AUTH_RESPONSE=$(curl --header "Content-Type: application/json" \
                                        --request POST \
                                        --data-raw "$AUTH_PAYLOAD" \
                                        --url "$TL_CONSOLE/api/v1/authenticate" )


TL_JWT=$(printf '%s' "$PRISMA_COMPUTE_API_AUTH_RESPONSE" | jq -r '.token')
}

retrieve_token

# brings down the resource lists from the console
curl --request GET \
     --url "$PC_APIURL/v1/resource_list" \
     --header 'Accept: application/json; charset=UTF-8' \
     --header "x-redlock-auth: $PC_JWT" \
     -o ./temp/resource_list.json

# only selects resource lists where the namespaces are defined and creates an array
RESOURCE_LIST_ARRAY=($(cat ./temp/resource_list.json | jq -r '.[] | select(.members[].namespaces[]? != "*") | .name' | sort | uniq))

# loops through each list with defined namespace(s)
for resource_list in "${!RESOURCE_LIST_ARRAY[@]}"; do \
  mkdir -p "./reports/${RESOURCE_LIST_ARRAY[$resource_list]}"

  RESOURCE_LIST_NAME="${RESOURCE_LIST_ARRAY[$resource_list]}"
  RESOURCE_LIST_ID=$(cat ./temp/resource_list.json| jq -r --arg resource_list_name "$RESOURCE_LIST_NAME" '.[] | select(.name == $resource_list_name ) | .id')
  RESOURCE_LIST_NAMESPACE_ARRAY=( $( cat ./temp/resource_list.json| jq -r --arg resource_list_name "$RESOURCE_LIST_NAME" '.[] | select(.name == $resource_list_name ) | .members[].namespaces[]') )


  curl --request GET \
       --url "$PC_APIURL/user/role" \
       --header 'Accept: application/json' \
       --header "x-redlock-auth: $PC_JWT" \
       -o "./reports/${RESOURCE_LIST_ARRAY[$resource_list]}/user_role.json"


  RESOURCE_LIST_USER_EMAIL_ARRAY=($(cat ./reports/${RESOURCE_LIST_ARRAY[$resource_list]}/user_role.json | jq --arg resource_list_id "$RESOURCE_LIST_ID" '.[] | select(.resourceLists[].id? == $resource_list_id ) | .associatedUsers[]'))

  # creates the email list
  printf '%s\n' "${RESOURCE_LIST_USER_EMAIL_ARRAY[*]}" > "./reports/${RESOURCE_LIST_ARRAY[$resource_list]}/email_list_$date.txt"

  for namespace in "${!RESOURCE_LIST_NAMESPACE_ARRAY[@]}"; do \

    mkdir -p "./reports/${RESOURCE_LIST_ARRAY[$resource_list]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}"
    # pulls down the total number of containers per the namespace
    CONTAINER_COUNT=$(curl --request GET \
                           --url "$TL_CONSOLE/api/v1/containers/count?namespaces=${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}" \
                           --header 'Accept: application/json' \
                           --header "authorization: Bearer $TL_JWT")

    # handles the 30 req per minute rate limit
    if [ $(expr $namespace % 30) -eq 0 ]; then \
      echo "sleeping for 60 seconds to avoid rate limit";
      sleep 60
      retrieve_token
    fi
    # determines whether or not the requests need to utilize offset and limit parameters
    if [ "$CONTAINER_COUNT" -gt "50" ]; then \
      # loop to pull all results from the console
      for container_offset in $(seq 0 50 "$CONTAINER_COUNT"); do \
        # handles the 30 req per minute rate limit
        if [ $(expr $container_offset % 1500) -eq 0 ]; then \
          echo "sleeping for 60 seconds to avoid rate limit";
          sleep 60
          retrieve_token
        fi
        # request for compliance/config workload data in csv format
        curl --request GET \
             --url "$TL_CONSOLE/api/v1/containers/download?limit=50&offset=$container_offset&namespaces=${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}" \
             --header 'Accept: application/json' \
             --header "authorization: Bearer $TL_JWT"  >> "./reports/${RESOURCE_LIST_ARRAY[$resource_list]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}_compliance_scan_results_$date.csv"
        # request for vulnerability workload data in csv format
        curl --request GET \
             --url "$TL_CONSOLE/api/v1/images/download?limit=50&offset=$container_offset&namespaces=${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}" \
             --header 'Accept: application/json' \
             --header "authorization: Bearer $TL_JWT"  >> "./reports/${RESOURCE_LIST_ARRAY[$resource_list]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}_vulnerability_scan_results_$date.csv"
      done
    else
      # request for compliance/config workload data in csv format
      curl --request GET \
           --url "$TL_CONSOLE/api/v1/containers/download?namespaces=${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}" \
           --header 'Accept: application/json' \
           --header "authorization: Bearer $TL_JWT" \
           -o "./reports/${RESOURCE_LIST_ARRAY[$resource_list]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}_compliance_scan_results_$date.csv"
      # request for vulnerability workload data in csv format
      curl --request GET \
           --url "$TL_CONSOLE/api/v1/images/download?namespaces=${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}" \
           --header 'Accept: application/json' \
           --header "authorization: Bearer $TL_JWT" \
           -o "./reports/${RESOURCE_LIST_ARRAY[$resource_list]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}_vulnerability_scan_results_$date.csv"
    fi
  printf '%s\n' 'Registry,Repository,Tag,Id,Distro,Hosts,Layer,CVE ID,Compliance ID,Type,Severity,Packages,Source Package,Package Version,Package License,CVSS,Fix Status,Fix Date,Grace Days,Risk Factors,Vulnerability Tags,Description,Cause,Containers,Custom Labels,Published,Discovered,Binaries,Clusters,Namespaces,Collections,Digest,Vulnerability Link,Apps,Package Path,Start Time,Defender Hosts,Agentless Hosts' > "./reports/${RESOURCE_LIST_ARRAY[$resource_list]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}_vulnerability_scan_results_filtered_$date.csv"
  cat "./reports/${RESOURCE_LIST_ARRAY[$resource_list]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}_vulnerability_scan_results_$date.csv" | grep "${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}" >> "./reports/${RESOURCE_LIST_ARRAY[$resource_list]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}_vulnerability_scan_results_filtered_$date.csv"
  rm "./reports/${RESOURCE_LIST_ARRAY[$resource_list]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}/${RESOURCE_LIST_NAMESPACE_ARRAY[$namespace]}_vulnerability_scan_results_$date.csv"
  done


done

{
rm ./temp/*
}

echo "each resource list has a directory with the reports and a file called email_list.txt with the list of emails to send the reports to"
