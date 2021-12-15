#!/bin/bash

source ./0a_aporeto_config
source ./secrets/aporeto_admin_app_credentials


APORETO_PARENT_NAMESPACE=$(printf %s $APORETO_CREDENTIALS | jq -r '.namespace')
APORETO_APIURL=$(printf %s $APORETO_CREDENTIALS | jq -r '.APIURL')

APORETO_TOKEN=$(curl --url $APORETO_APIURL/issue \
                     --request POST \
                     -E "./secrets/aporeto.pem" \
                     --header 'Content-Type: application/json' \
                     --data '{"realm": "Certificate"}' | jq -r '.token')

CLUSTER_NS="$APORETO_PARENT_NAMESPACE/$APORETO_CHILD_NAMESPACE/$APORETO_GRANDCHILD_NAMESPACE2"

apoctl enforcer install k8s \
 --cluster-type custom \
 --installation-mode helm \
 --output-dir . \
 --custom-cni-bin-dir /opt/cni/bin \
 --custom-cni-conf-dir /etc/cni/net.d \
 --custom-cni-chained \
 --api "$APORETO_APIURL" \
 --namespace $CLUSTER_NS \
 --token $APORETO_TOKEN 


