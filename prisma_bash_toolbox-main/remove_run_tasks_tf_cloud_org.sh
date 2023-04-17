#!/usr/bin/env bash

# written by Kyle Butler
# removes all associated TF Run Tasks across all workspaces in a Terraform Cloud Org

#Terraform user api token
TF_TOKEN=""

#Terraform cloud organization name
ORGANIZATION=""

# no user input required below

TF_WORKSPACES_REQUEST=$(curl \
                            --header "Authorization: Bearer $TF_TOKEN" \
                            --header "Content-Type: application/vnd.api+json" \
                            --url "https://app.terraform.io/api/v2/organizations/$ORGANIZATION/workspaces?page%5Bnumber=$TF_WORKSPACES&page%5Bsize=100")

HUNDRED_WORKSPACES_IN_TF=$(printf '%s' "$TF_WORKSPACES_REQUEST" | jq -r '.meta.pagination."total-pages"')

# handles the api page limits and numbers in the request
for TF_WORKSPACES in $(seq 1 "$HUNDRED_WORKSPACES_IN_TF"); do\
  curl \
    --header "Authorization: Bearer $TF_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --url "https://app.terraform.io/api/v2/organizations/$ORGANIZATION/workspaces?page%5Bnumber=$TF_WORKSPACES&page%5Bsize=100" > ./temp_tf_workspace_$TF_WORKSPACES.json
done

# creates array of workspace ID's
WS_ID_ARRAY=( $(cat ./temp_tf_workspace_*.json| jq -r '.data[].id')) 

# for each workspace ID get the associated run task ID and turn that into an array. Finally make another request to delete the ws run task using the run task and workspace ID.
for WSID in "${!WS_ID_ARRAY[@]}"; do\

TASK_ID_ARRAY=($(curl \
                   --header "Authorization: Bearer $TF_TOKEN" \
                   --url "https://app.terraform.io/api/v2/workspaces/${WS_ID_ARRAY[WSID]}/tasks" | jq -r '.data[].id'))

  for TASK_ID in "${TASK_ID_ARRAY[@]}"; do\
    curl \
      --header "Authorization: Bearer $TF_TOKEN" \
      --header "Content-Type: application/vnd.api+json" \
      --request DELETE \
      --url "https://app.terraform.io/api/v2/workspaces/${WS_ID_ARRAY[WSID]}/tasks/$TASK_ID"
  done

done

exit
