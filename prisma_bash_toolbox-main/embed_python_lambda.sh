#!/usr/bin/env bash
# requires jq
# written by kyle butler
# demonstrates how to embed a defender in a python 3.6 - 3.9 aws lambda function:


source ./secrets/secrets

PATH_TO_PYTHON_FUNCTION=./lambda_function.py
FUNCTION_NAME="kb-test"
FUNCTION_HANDLER_NAME="<lambda_handler_name>"

######## end of user config ##################


# request body for /api/v1/authenticate endpoint
AUTH_PAYLOAD=$(cat <<EOF
{"username": "$TL_USER", "password": "$TL_PASSWORD"}
EOF
)

# request to /api/v1/authenticate endpoint to retrieve JWT
PRISMA_COMPUTE_API_AUTH_RESPONSE=$(curl --header "Content-Type: application/json" \
                                        --request POST \
                                        --data-raw "$AUTH_PAYLOAD" \
                                        --url $TL_CONSOLE/api/v1/authenticate )

# parses JWT to get the token
TL_JWT=$(printf '%s' "$PRISMA_COMPUTE_API_AUTH_RESPONSE" | jq -r '.token')

# creates a temp directory for the lambda embedding process
if [ ! -d "./serverless_temp" ]
then
    mkdir ./serverless_temp
fi


# extracts file name from the path
FUNCTION_FILE_NAME=$(basename $PATH_TO_PYTHON_FUNCTION)

# adds in the twistlock library import after the last occurance of import in the lambda.py file puts it into a temp file
awk 'FNR==NR{ if (/import/) p=NR; next} 1; FNR==p{ print "import twistlock.serverless\n" }' "$PATH_TO_PYTHON_FUNCTION" "$PATH_TO_PYTHON_FUNCTION" > "./serverless_temp/temp_$FUNCTION_FILE_NAME"

# places the annotation above the handler in a finished file
awk -v function_handler=$FUNCTION_HANDLER_NAME '!found && $0~function_handler { print "@twistlock.serverless.handler"; found=1 } 1' "./serverless_temp/temp_$FUNCTION_FILE_NAME" > "./serverless_temp/$FUNCTION_FILE_NAME"

# removes the temp file
rm "./serverless_temp/temp_$FUNCTION_FILE_NAME"

# request body for the defender serverless bundle
SERVERLESS_BUNDLE_REQUEST_BODY=$(cat <<EOF
{
"runtime": "python",
"provider": "aws"
}
EOF
)

# request for the serverless defender bundle
curl -sSL \
     --header "authorization: Bearer $TL_JWT" \
     --request POST \
     --url "$TL_CONSOLE/api/v1/defenders/serverless/bundle" \
     -o ./serverless_temp/twistlock_serverless_defender.zip \
     -d "$SERVERLESS_BUNDLE_REQUEST_BODY"

# unzips the serverless defender bundle.
unzip ./serverless_temp/twistlock_serverless_defender.zip -d ./serverless_temp
rm ./serverless_temp/twistlock_serverless_defender.zip
cd ./serverless_temp || exit
zip -r embedded_function.zip ./*
mv embedded_function.zip ../embedded_function.zip
cd .. || exit

# gets the domain from the url 
BASE_TL_URL=$(awk -F/ '{print $3}' <<< "$TL_CONSOLE")

# request body for the policy
SERVERLESS_POLICY_REQUEST_BODY=$(cat <<EOF
{
"consoleAddr":"$BASE_TL_URL",
"function":"$FUNCTION_NAME",
"provider":"aws"
}
EOF
)

# request to retrieve the TW_POLICY value
TW_POLICY_REQUEST=$(curl --url "$TL_CONSOLE/api/v1/policies/runtime/serverless/encode?project=Central+Console" \
                         --header 'Accept: application/json, text/plain, */*' \
                         --header 'Accept-Language: en-US,en;q=0.9' \
                         --header "Authorization: Bearer $TL_JWT" \
                         --header 'Content-Type: application/json' \
                         --data-raw "$SERVERLESS_POLICY_REQUEST_BODY" \
                         --compressed)


TW_POLICY_VALUE=$(printf '%s' "$TW_POLICY_REQUEST" | jq '.data')

printf '\n%s\n' "Your python lambda function has been embedded. You can upload the embedded_function.zip file to aws lambda. Please add in the enviornment variable TW_POLICY and set the value to: $TW_POLICY_VALUE"

printf '\n%s\n' "Should you have any issues with the expected behavior of the function you can add TW_DEBUG_ENABLED as an environment variable and set the value to true for more robust logging"

# cleanup task
{
rm -rf ./serverless_temp
}
