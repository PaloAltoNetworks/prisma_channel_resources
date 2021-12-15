#!/bin/bash
# Requires jq to be installed
# Author Kyle Butler & Goran Bogojevic


source ./secrets/aporeto_admin_app_credentials
source ./secrets/secrets


printf %s $APORETO_CREDENTIALS | jq -r '.certificateKey'| base64 -d > ./secrets/aporeto.pem
printf %s $APORETO_CREDENTIALS | jq -r '.certificate'| base64 -d >> ./secrets/aporeto.pem


