#!/usr/bin/env bash
# written by Kyle Butler
# use to validate the prisma variable assignements in ./secrets/secrets



PC_SECRETKEY_MATCH='^(\w|\d|\/|\+){27}\=$'
PC_ACCESSKEY_MATCH='^(\d|\w){8}\-(\d|\w){4}\-(\d|\w){4}\-(\d|\w){4}\-(\d|\w){12}$'
PC_APIURL_MATCH='^https\:\/\/api[2-9]?\.(anz|eu|gov|ca|sg|uk|ind)?(\.)?prismacloud\.(cn|io)$'
TL_CONSOLE_MATCH='^https\:\/\/(\w|\d|\.|\-|\_|\:|\/)+$'

# function to check variables required to access the prisma cloud enterprise api endpoints for cspm
pce-var-check () {
if [[ ! $PC_SECRETKEY =~ $PC_SECRETKEY_MATCH ]]
  then
     printf '\n%s' "PC_SECRETKEY does not meet the regex validation check in the ./secrets/secrets file. Would you like to continue?"
     read -r CONTINUE
     if [ "$CONTINUE" != "${CONTINUE#[Yy]}" ]
       then
         printf '\n%s' "running script..."
     else
        printf '\n%s' "try running the setup.sh script"
        exit 1
     fi
fi

if [[ ! $PC_ACCESSKEY =~ $PC_ACCESSKEY_MATCH ]]
  then
     printf '\n%s' "PC_ACCESSKEY does not meet the regex validation check in the ./secrets/secrets file. Would you like to continue?"
     read -r CONTINUE
     if [ "$CONTINUE" != "${CONTINUE#[Yy]}" ]
       then
         printf '\n%s' "running script..."
     else
        printf '\n%s' "try running the setup.sh script"
        exit 1
     fi
fi


if [[ ! $PC_APIURL =~ $PC_APIURL_MATCH ]]
  then
     printf '\n%s' "The Prisma Cloud api url does not meet the regex validation check in the ./secrets/secrets file. Would you like to continue?"
     read -r CONTINUE
     if [ "$CONTINUE" != "${CONTINUE#[Yy]}" ]
       then
         printf '\n%s' "running script..."
     else
        printf '\n%s' "try running the setup.sh script"
        exit 1
     fi
fi
}

# function to check variables required to access the compute api endpoints
tl-var-check () {
if [[ ! $TL_CONSOLE =~ $TL_CONSOLE_MATCH ]]
  then
     printf '\n%s' "Prisma Compute api url does not meet the regex validation check in the ./secrets/secrets file. Would you like to continue?"
     read -r CONTINUE
     if [ "$CONTINUE" != "${CONTINUE#[Yy]}" ]
       then
         printf '\n%s' "running script..."
     else
        printf '\n%s' "try running the setup.sh script"
        exit 1
     fi
fi

if [ -z "$TL_USER" ]
  then
    echo "TL_USER variable is unassigned. Run the setup.sh script or fix the variable assignment in the secrets directory"
    exit 1
fi

if [ -z "$TL_PASSWORD" ]
  then
    echo "TL_PASSWORD variable is unassigned. Run the setup.sh script or fix the variable assignment in the secrets directory"
    exit 1
fi
}

# function to check api request
quick_check () {
  res=$?
  if [ $res -eq 0 ]; then
    echo "$1 request succeeded"
  else
    echo "ERROR: $1 request failed error code: $res" >&2
    exit 1
  fi
}

var_response_check () {
  if [[ $(printf '%s' "$1" | jq -r '. | keys | @sh') == "'err'" ]]; then
    echo "ERROR: request response is assigned to an err value: $(printf '%s' "$1" | jq -r '.err')" >&2
    exit 1
  elif [ -z "$1" ]; then
    echo "INFO: null response body"
  fi
}

# function to check api request in for loop
loop_response_check () {
  res=$?
  if [ $res -eq 0 ]; then
    echo "$1 request succeeded"
  else
    echo "$1 request failed error code: $res" >&2
  fi
}

