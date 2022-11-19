#!/usr/bin/env bash


# REQUIRES Jq to be installed
# Written by Kyle Butler

# This onboard an AWS org into Prisma Cloud through the prisma cloud apis. It does not cover all the possible usecases. Example: excluding specific accounts within the org. 
# Full api documentaiton on this endpoint can be found here: https://prisma.pan.dev/api/cloud/cspm/cloud-accounts/#operation/add-cloud-account
source ./secrets/secrets
source ./func/func.sh


# ORG Level AWS account ID
AWS_ACCOUNT_ID=""

# id of account group you'd like to addd the onboarded account to.
PRISMA_ACCOUNT_GROUP_ID=

# external ID created to secure access between Prisma and AWS org level
AWS_EXTERNAL_ID=""

# external ID created to secure access between Prisma and AWS member/account level
AWS_MEMBER_EXTERNAL_ID=""

# name of the IAM role created when deploying the CFT stack default should be PrismaCloudReadOnlyRole or PrismaCloudOrgReadOnyRole. 
MEMBER_ROLE_NAME=""

# Name of the AWS account/in prisma cloud. Like HR AWS accounts...etc. 
NAME=""

# protection mode MONITOR or MONITOR_AND_PROTECT
PROTECTION_MODE=""

# Role arn assigned to the IAM role created
ROLE_ARN=""

# onboarding type ACCOUNT or ORG
ONBOARDING_TYPE=""



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


PAYLOAD=$(cat <<EOF
{
 "accountId": "$AWS_ACCOUNT_ID",
 "accountType": "organization",
 "enabled": true,
 "groupIds": ["$PRISMA_ACCOUNT_GROUP_ID"],
 "externalId": "$AWS_EXTERNAL_ID",
 "memberExternalId": "$AWS_MEMBER_EXTERNAL_ID",
 "memberRoleName": "$MEMBER_ROLE_NAME",
 "memberRoleStatus": true,
 "name": "$NAME",
 "protectionMode": "$PROTECTION_MODE",
 "roleArn": "$ROLE_ARN",
 "storageScanEnabled": false,
 "hierarchySelection": [
   {
    "displayName": "Root",
    "nodeType": "$ONBOARDING_TYPE",
    "resourceId": "root",
    "selectionType": "ALL"
   }
  ]
}
EOF
)


curl -v \
     --request POST \
     --url "$PC_APIURL/cloud/aws" \
     --header 'accept: application/json; charset=UTF-8' \
     --header 'content-type: application/json' \
     --header "x-redlock-auth: $PC_JWT"  \
     --data-raw "$PAYLOAD"
