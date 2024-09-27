#!/usr/bin/env bash
# written by Kyle Butler
# use to validate the prisma variable assignements in ./secrets/secrets


OS_CHECK=$(uname -s)
PC_SECRETKEY_MATCH='^(\w|\d|\/|\+){27}\=$'
PC_ACCESSKEY_MATCH='^(\d|\w){8}\-(\d|\w){4}\-(\d|\w){4}\-(\d|\w){4}\-(\d|\w){12}$'
PC_APIURL_MATCH='^https\:\/\/api[0-9]?\.(anz|eu|gov|ca|sg|uk|ind)?(\.)?prismacloud\.(cn|io)$'
TL_CONSOLE_MATCH='^https\:\/\/(\w|\d|\.|\-|\_|\:|\/)+$'

# function to check variables required to access the prisma cloud enterprise api endpoints for cspm
pce-var-check () {
if [[ "$OS_CHECK" == "Darwin" ]]; then \
  ACCESSKEY_CHECK=$(printf '%s' "$PC_ACCESSKEY" |  grep -E "$PC_ACCESSKEY_MATCH")
  if [ -z "$ACCESSKEY_CHECK" ]; then \
    printf '\n%s' "PC_ACCESSKEY does not meet the regex validation check in the ./secrets/secrets file. Would you like to continue?"
    read -r CONTINUE
    if [ "$CONTINUE" != "${CONTINUE#[Yy]}" ]; then \
      printf '\n%s' "running script..."
    else
      printf '\n%s' "try running the setup.sh script"
      exit 1
    fi
  fi
else
  ACCESSKEY_CHECK=$(printf '%s' "$PC_ACCESSKEY" |  grep -P "$PC_ACCESSKEY_MATCH")
  if [ -z "$ACCESSKEY_CHECK" ]; then \
    printf '\n%s' "PC_ACCESSKEY does not meet the regex validation check in the ./secrets/secrets file. Would you like to continue?"
    read -r CONTINUE
    if [ "$CONTINUE" != "${CONTINUE#[Yy]}" ]; then \
      printf '\n%s' "running script..."
    else
      printf '\n%s' "try running the setup.sh script"
      exit 1
    fi
  fi
fi

if [[ "$OS_CHECK" == "Darwin" ]]; then \
  SECRETKEY_CHECK=$(printf '%s' "$PC_SECRETKEY" |  grep -E "$PC_SECRETKEY_MATCH")
  if [ -z "$ACCESSKEY_CHECK" ]; then \
    printf '\n%s' "PC_SECRETKEY does not meet the regex validation check in the ./secrets/secrets file. Would you like to continue?"
    read -r CONTINUE
    if [ "$CONTINUE" != "${CONTINUE#[Yy]}" ]; then \
      printf '\n%s' "running script..."
    else
      printf '\n%s' "try running the setup.sh script"
      exit 1
    fi
  fi
else
  SECRETKEY_CHECK=$(printf '%s' "$PC_SECRETKEY" |  grep -P "$PC_SECRETKEY_MATCH")
  if [ -z "$ACCESSKEY_CHECK" ]; then \
    printf '\n%s' "PC_SECRETKEY does not meet the regex validation check in the ./secrets/secrets file. Would you like to continue?"
    read -r CONTINUE
    if [ "$CONTINUE" != "${CONTINUE#[Yy]}" ]; then \
      printf '\n%s' "running script..."
    else
      printf '\n%s' "try running the setup.sh script"
      exit 1
    fi
  fi
fi

if [[ "$OS_CHECK" == "Darwin" ]]; then \
  PC_APIURL_CHECK=$(printf '%s' "$PC_APIURL" |  grep -E "$PC_APIURL_MATCH")
  if [ -z "$PC_APIURL_CHECK" ]; then \
    printf '\n%s' "PC_APIURL does not meet the regex validation check in the ./secrets/secrets file. Would you like to continue?"
    read -r CONTINUE
    if [ "$CONTINUE" != "${CONTINUE#[Yy]}" ]; then \
      printf '\n%s' "running script..."
    else
      printf '\n%s' "try running the setup.sh script"
      exit 1
    fi
  fi
else
  PC_APIURL_CHECK=$(printf '%s' "$PC_APIURL" |  grep -P "$PC_APIURL_MATCH")
  if [ -z "$PC_APIURL_CHECK" ]; then \
    printf '\n%s' "PC_APIURL does not meet the regex validation check in the ./secrets/secrets file. Would you like to continue?"
    read -r CONTINUE
    if [ "$CONTINUE" != "${CONTINUE#[Yy]}" ]; then \
      printf '\n%s' "running script..."
    else
      printf '\n%s' "try running the setup.sh script"
      exit 1
    fi
  fi
fi
}

# function to check variables required to access the compute api endpoints
tl-var-check () {
if [[ "$OS_CHECK" == "Darwin" ]]; then \
  TL_CONSOLE_CHECK=$(printf '%s' "$TL_CONSOLE" |  grep -E "$TL_CONSOLE_MATCH")
  if [ -z "$TL_CONSOLE_CHECK" ]; then \
    printf '\n%s' "TL_CONSOLE does not meet the regex validation check in the ./secrets/secrets file. Would you like to continue?"
    read -r CONTINUE
    if [ "$CONTINUE" != "${CONTINUE#[Yy]}" ]; then \
      printf '\n%s' "running script..."
    else
      printf '\n%s' "try running the setup.sh script"
      exit 1
    fi
  fi
else
  TL_CONSOLE_CHECK=$(printf '%s' "$TL_CONSOLE" |  grep -P "$TL_CONSOLE_MATCH")
  if [ -z "$ACCESSKEY_CHECK" ]; then \
    printf '\n%s' "TL_CONSOLE does not meet the regex validation check in the ./secrets/secrets file. Would you like to continue?"
    read -r CONTINUE
    if [ "$CONTINUE" != "${CONTINUE#[Yy]}" ]; then \
      printf '\n%s' "running script..."
    else
      printf '\n%s' "try running the setup.sh script"
      exit 1
    fi
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

# helps with rate limits on requests requires the $number_of_jobs var to be set in a script to use. 
function sub_control {
   while [ $(jobs | wc -l) -ge "$number_of_jobs" ]
   do
      sleep 5
   done
}

# error handling for array population from cat command
die-with-error(){
 printf '\n%s\n'  "$1" & exit 1
}

