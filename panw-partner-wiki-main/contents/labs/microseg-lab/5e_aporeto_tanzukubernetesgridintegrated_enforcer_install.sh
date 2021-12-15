#!/bin/bash

source ./0a_aporeto_config
source ./secrets/aporeto_admin_app_credentials
source ./secrets/secrets

APORETO_CHILD_NAMESPACE=$APP_CHILD_NS
APORETO_GRANDCHILD_NAMESPACE=$APP_GRANDCHILD_NS


APORETO_PARENT_NAMESPACE=$(printf %s $APORETO_CREDENTIALS | jq -r '.namespace')
APORETO_APIURL=$(printf %s $APORETO_CREDENTIALS | jq -r '.APIURL')

APORETO_TOKEN=$(curl --url $APORETO_APIURL/issue \
                     --request POST \
                     -E "./secrets/aporeto.pem" \
                     --header 'Content-Type: application/json' \
                     --data '{"realm": "Certificate"}' | jq -r '.token')

CLUSTER_NS="$APORETO_PARENT_NAMESPACE/$APORETO_CHILD_NAMESPACE/$APORETO_GRANDCHILD_NAMESPACE"

apoctl enforcer install tkgi \
 --cluster-type tkgi \
 --api "$APORETO_APIURL" \
 --namespace $CLUSTER_NS \
 --token $APORETO_TOKEN 


