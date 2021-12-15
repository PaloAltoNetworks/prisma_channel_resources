#!/bin/bash
# Requires jq to be installed
# Author Kyle Butler & Goran Bogojevic

source ./secrets/aporeto_admin_app_credentials

APORETO_PARENT_NAMESPACE=$(printf %s $APORETO_CREDENTIALS | jq -r '.namespace')
APORETO_APIURL=$(printf %s $APORETO_CREDENTIALS | jq -r '.APIURL')

APORETO_TOKEN=$(curl --url $APORETO_APIURL/issue \
                     --request POST \
                     -E "./secrets/aporeto.pem" \
                     --header 'Content-Type: application/json' \
                     --data '{"realm": "Certificate"}' | jq -r '.token')

apoctl configure -A "$APORETO_APIURL" -n "$APORETO_PARENT_NAMESPACE" -t "$APORETO_TOKEN" --force

