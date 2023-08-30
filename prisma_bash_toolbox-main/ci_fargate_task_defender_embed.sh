#!/usr/bin/env bash
# written by Kyle Butler
# a couple of notes: if the task doesn't have an entrypoint this won't work. You can add a universal entrypoint to to the task: linux = ["sh","-c"] or for windows containers ["powershell", "-command"]. This won't change the behavior of the container. 
# additionally (Thank you Lindsay Smith), if you pull the fargate task from using AWS cli AWS adds keys to the task def then complains when they're present if you work directly with the JSON in a new revision. To get around this, save the JSON in original.son and run this jq command:
# jq 'del(.requiresAttributes, .compatibilities, .taskDefinitionArn, .revision, .status)' original.json > unprotected.json

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
