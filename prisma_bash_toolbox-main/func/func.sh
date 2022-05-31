#!/bin/bash
# written by Kyle Butler
# use to validate the prisma variable assignements in ./secrets/secrets



PC_SECRETKEY_MATCH='^(\w|\d|\/|\+){27}\=$'
PC_ACCESSKEY_MATCH='^(\d|\w){8}\-(\d|\w){4}\-(\d|\w){4}\-(\d|\w){4}\-(\d|\w){12}$'
PC_APIURL_MATCH='^https\:\/\/api[2-9]?\.(anz|eu|gov|ca|sg|uk|ind)?(\.)?prismacloud\.(cn|io)$'
TL_CONSOLE_MATCH='^https\:\/\/(\w|\d|\.|\-|\_|\:)+$'

# function to check variables required to access the prisma cloud enterprise api endpoints for cspm
pce-var-check () {
if [[ ! $PC_SECRETKEY =~ $PC_SECRETKEY_MATCH ]]
  then
     echo "PC_SECRETKEY is not assigned to a valid value. Please recopy and reassign the variable in the ./secrets/secrets file and run again"
     exit 1
fi

if [[ ! $PC_ACCESSKEY =~ $PC_ACCESSKEY_MATCH ]]
  then
     echo "PC_ACCESSKEY is not assigned to a valid value. Please recopy and reassign the variable in the ./secrets/secrets file and run again"
     exit 1
fi


if [[ ! $PC_APIURL =~ $PC_APIURL_MATCH ]]
  then
    echo "$PC_APIURL is not a valid value for PC_APIURL. Please recopy and reassign the variable in the ./secrets/secrets file and run again"
    exit 1
fi
}

# function to check variables required to access the compute api endpoints
tl-var-check () {
if [[ ! $TL_CONSOLE =~ $TL_CONSOLE_MATCH ]]
  then
    echo "$TL_CONSOLE is not a valid value for TL_CONSOLE. Please recopy and reassign the variable in the ./secrets/secrets file and run again"
    exit 1
fi

if [ -z "$TL_USER" ]
  then
    echo "TL_USER variable is unassigned. Please ensure the the variable is assigned in the ./secrets/secrets file and run again"
    exit 1
fi

if [ -z "$TL_PASSWORD" ]
  then
    echo "TL_PASSWORD variable is unassigned. Please ensure the variable is assigned in the ./secrets/secrets file and run again"
    exit 1
fi
}

# function to check api request
quick_check () {
  res=$?
  if [ $res -eq 0 ]; then
    echo "$1 request succeeded"
  else
    echo "$1 request failed error code: $res" >&2
    exit 1
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

