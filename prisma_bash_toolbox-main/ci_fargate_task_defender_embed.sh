#!/bin/bash

source ./secrets/secrets
source ./func/func.sh

# Directory path to fargate task
FARGATE_TASK_LOCATION="./unprotected.json"

# What you want the new task to be named and where you want it go. 
PROTECTED_DEFINITION_OUTPUT="./protected.json"

# Not user defined

tl-var-check

HOSTNAME_FOR_CONSOLE=$(printf %s $TL_CONSOLE | awk -F / '{print $3}' | sed  s/':\S*'//g)

# -k will need to be added for the self hosted vesion if using the default deploy method with a self-signed cert. 

curl --url "$TL_CONSOLE/api/v1/defenders/fargate.json?consoleaddr=$HOSTNAME_FOR_CONSOLE&defenderType=appEmbedded" \
  -u $TL_USER:$TL_PASSWORD \
  -H 'Content-Type: application/json' \
  -X POST \
  --data-binary "@$FARGATE_TASK_LOCATION" \
  --output $PROTECTED_DEFINITION_OUTPUT
  
quick_check "/api/v1/defenders/fargate.json?consoleaddr=$HOSTNAME_FOR_CONSOLE&defenderType=appEmbedded"
