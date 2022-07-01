#!/usr/bin/env bash
# written by Kyle Butler


source ./func/func.sh

printf '\n%s\n%s\n%s\n'  "This script will set up your secrets file in the ./secrets directory and modify the permissions so the user running it will be the only one who can modify the file." \
                          "It will also verify you have the proper dependencies and ensure an api token can be retrieved." \
                          "It will override any existing file you have in the .secrets/secrets directory"

printf '\n%s\n' "Would you like to continue?"
read -r ANSWER

if [ "$ANSWER" != "${ANSWER#[Yy]}" ]
  then
    printf '\n%s\n\n' "checking dependencies..."
  else
    exit
fi

if ! command -v jq > /dev/null 2>&1; then
    printf '\n%s\n%s\n' "ERROR: Jq is not available." \
                        "These scripts require jq, please install and try again."
    exit 1
fi

if ! command -v curl -V > /dev/null 2>&1; then
      printf '\n%s\n%s\n' "ERROR: curl is not available." \
                          "These scripts require jq, please install and try again."
      exit 1
fi

if ! command -v wget > /dev/null 2>&1; then
        printf '\n%s\n%s\n' "ERROR: wget is not available." \
                            "These scripts require wget, please install and try again."
        exit 1
fi


printf '\n%s\n\n' "dependency check passed...checking secret file"




PATH_TO_SECRETS_FILE="./secrets/secrets"

if [ ! -f "$PATH_TO_SECRETS_FILE" ]
  then
      printf '\n%s\n' "creating secrets file"
      touch $PATH_TO_SECRETS_FILE
fi


if [ -z "$PC_SECRETKEY" ] || [ -z "$PC_ACCESSKEY" ] || [ -z "$PC_APIURL" ] || [ -z "$TL_CONSOLE" ] || [ -z "$TL_USER" ] || [ -z "$TL_PASSWORD" ];
  then
      printf '\n%s\n' "Are you wanting to request data from the self-hosted version of prisma cloud compute? (y/n)"
      read -r VERSION_QUESTION
      if [ "$VERSION_QUESTION" != "${VERSION_QUESTION#[Yy]}" ]
        then
          COMPUTE_SELF_HOSTED="TRUE"
        else
          COMPUTE_SELF_HOSTED="FALSE"
      fi
  else
        printf '\n%s/n' "Is it okay to reconfigure the ./secrets/secrets file?"
        read -r VERIFY
        if [ "$VERIFY" != "${VERIFY#[Yy]}" ]
          then
            printf '\n%s\n\n' "checking variable assignement..."
          else
            exit
        fi
fi

if [[ $COMPUTE_SELF_HOSTED == "TRUE" ]]
  then
    printf '\n%s\n' "enter your prisma compute username:"
    read -r  TL_USER
    printf '\n%s\n' "enter your prisma compute username password:"
    read -r -s  TL_PASSWORD
    printf '\n%s\n' "Enter your prisma cloud compute console FQDN with https:// and port if different than 443. Example: https://example.prisma-compute-lab.com:8083"
    read -r TL_CONSOLE
    tl-var-check
    printf '\n%s\n' "enter your prisma cloud access key id:"
    read -r PC_ACCESSKEY
    printf '\n%s\n' "enter your prisma cloud secret key id:"
    read -r -s PC_SECRETKEY
    printf '\n%s\n' "enter your prisma cloud api url (found here https://prisma.pan.dev/api/cloud/api-urls):"
    read -r PC_APIURL
    pce-var-check
  else
    printf '\n%s\n' "enter your prisma cloud access key id:"
    read -r PC_ACCESSKEY
    printf '\n%s\n' "enter your prisma cloud secret key id:"
    read -r -s PC_SECRETKEY
    printf '\n%s\n' "enter your prisma cloud api url (found here https://prisma.pan.dev/api/cloud/api-urls):"
    read -r PC_APIURL
    pce-var-check
    printf '\n%s\n' "enter your prisma cloud compute api url (found under compute > settings > system > utilities):"
    read -r TL_CONSOLE
    TL_USER=$PC_ACCESSKEY
    TL_PASSWORD=$PC_SECRETKEY
    tl-var-check
fi


AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)


PC_JWT_RESPONSE=$(curl -s --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")


PC_JWT=$(printf %s "$PC_JWT_RESPONSE" | jq -r '.token' )


if [ -z "$PC_JWT" ]
  then
      printf '\n%s\n' "Prisma Cloud Enterprise CSPM api token not retrieved, have you verified the expiration date of the access key and secret key? Have you verified connectivity to the url provided? Troubleshoot and then you'll need to run this script again"
      exit 1
  else
     printf '\n%s\n' "Token retrieved, access key, secret key, and prisma cloud enterprise edition api url are valid"
fi


AUTH_PAYLOAD=$(cat <<EOF
{"username": "$TL_USER", "password": "$TL_PASSWORD"}
EOF
)



# add -k to curl if using self-hosted version with a self-signed cert
TL_JWT_RESPONSE=$(curl -s -k --request POST \
                       --url "$TL_CONSOLE/api/v1/authenticate" \
                       --header 'Content-Type: application/json' \
                       --data "$AUTH_PAYLOAD")


TL_JWT=$(printf %s "$TL_JWT_RESPONSE" | jq -r '.token' )

if [ -z "$TL_JWT" ]
    then
        printf '\n%s\n' "Prisma compute api token not retrieved, have you verified the expiration date of the access key and secret key? Have you verified connectivity to the url provided? Troubleshoot and then you'll need to run this script again"
        exit 1
    else
       printf '\n%s\n' "Token retrieved, access key, secret key, and compute api url are valid" 
fi


printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n' "#!/usr/bin/env bash" \
                                      "PC_APIURL=\"$PC_APIURL\"" \
                                      "PC_ACCESSKEY=\"$PC_ACCESSKEY\"" \
                                      "PC_SECRETKEY=\"$PC_SECRETKEY\"" \
                                      "TL_CONSOLE=\"$TL_CONSOLE\"" "TL_USER=\"$TL_USER\"" \
                                      "TL_PASSWORD=\"$TL_PASSWORD\"" > $PATH_TO_SECRETS_FILE



chmod 700 ./secrets/secrets

printf '%s\n%s\n%s\n%s\n\n\n' "All scripts in the toolbox are able to be executed!" \
                              "Many have variables that need to be assigned to fit the use case." \
                              "Please edit the script to verify the variables and then execute by running:" \
                              "bash ./<script_name>.sh"
exit
