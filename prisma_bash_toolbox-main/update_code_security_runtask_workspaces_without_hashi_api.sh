#!/usr/bin/env bash
# written by Kyle Butler
# adds all the available workspaces to the terraform runtask integration.
# requires jq
# only uses the prisma cloud api endpoint
#
# suggested usage: https://developer.hashicorp.com/terraform/language/resources/provisioners/local-exec
#
# resource "null_resource" "update-prisma-integration" {
#
# provisioner "local-exec" {
#    
#    command = "/bin/bash <./path/to/this/script>"
#   }
# }
#
# would require removing lines 23 & 24 and assigning the vars on 20, 21,22

TFC_ORG_NAME="<TERRAFORM_CLOUD_ORG_NAME>"
# PC_ACCESSKEY=""
# PC_SECRETKEY=""
# PC_APIURL=""
source ./secrets/secrets
source ./func/func.sh
# auth request body for prisma /login endpoint
AUTH_PAYLOAD=$(cat <<EOF
{
 "username": "$PC_ACCESSKEY",
 "password": "$PC_SECRETKEY"
}
EOF
)


# submits request to /login endpoint and assigns response to var
PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")


# parses token from jwt
PC_JWT=$(printf %s "$PC_JWT_RESPONSE" | jq -r '.token' )


# brings down all the prisma cloud code security integrations to a file called ./prisma_code_security_integrations.json
curl --request GET \
     --url "$PC_APIURL/bridgecrew/api/v2/integrations?" \
     --header 'Accept: application/json; charset=UTF-8' \
     --header 'Content-Type: application/json; charset=UTF-8' \
     --header "x-redlock-auth: $PC_JWT" > ./prisma_code_security_integrations.json


# parses the integrations file for the tfc integration data
EXISTING_TFC_RUN_TASK_INTEGRATIONS=$(jq --arg org_name "$TFC_ORG_NAME" '[.data[] | select( .type == "tfcRunTasks") | select(.params.organization.name == $org_name)] | .[0] | {organization: .params.organization, workspaces: .params.workspaces, integrationId: .id}' < ./prisma_code_security_integrations.json)


# requests the selectable workspaces from the /bridgecrew/api/v1/tfRunTasks/cloud/<TFC_ORG_NAME>/workspaces endpoint
EXISTING_TFC_WORKSPACES=$(curl --url "$PC_APIURL/bridgecrew/api/v1/tfRunTasks/cloud/$TFC_ORG_NAME/workspaces" \
                               --header 'accept: application/json, text/plain, */*' \
                               --header "authorization: $PC_JWT" \
                               --compressed | jq -r '.data')

# parses the integrations data for for the eventHookid
TFC_TASK_ID=$(printf '%s' "$EXISTING_TFC_RUN_TASK_INTEGRATIONS" | jq -r '.organization.eventHook.id')

# parses the integrations data for the tfc integrationId
INTEGRATION_ID=$(printf '%s' "$EXISTING_TFC_RUN_TASK_INTEGRATIONS" | jq -r '.integrationId')


# assigns vars to the request body for the update
TFC_CLOUD_CREATE_REQUEST_BODY=$(cat <<EOF
{
  "organization": {
    "name": "$TFC_ORG_NAME",
    "eventHook": {
      "id": "$TFC_TASK_ID"
    },
    "id": "$TFC_ORG_NAME"
  },
  "workspaces": $EXISTING_TFC_WORKSPACES,
  "integrationId": "$INTEGRATION_ID"
}
EOF
)


# updates the workspaces associated with the org
curl --url "$PC_APIURL/bridgecrew/api/v1/tfRunTasks/cloud/create" \
     --request 'PUT' \
     --header "authorization: $PC_JWT" \
     --header 'content-type: application/json' \
     --data-raw "$TFC_CLOUD_CREATE_REQUEST_BODY"
