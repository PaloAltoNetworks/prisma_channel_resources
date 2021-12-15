#!/bin/bash

source ./secrets/aporeto_admin_app_credentials
source ./0a_aporeto_config

APORETO_PARENT_NAMESPACE=$(printf %s $APORETO_CREDENTIALS | jq -r '.namespace')

cat <<EOF | apoctl api create namespace -n $APORETO_PARENT_NAMESPACE -f -
name: $APORETO_CHILD_NAMESPACE
type: Group
defaultPUIncomingTrafficAction: Allow
defaultPUOutgoingTrafficAction: Allow
EOF

cat <<EOF | apoctl api create namespace -n $APORETO_PARENT_NAMESPACE/$APORETO_CHILD_NAMESPACE -f -
name: $APORETO_GRANDCHILD_NAMESPACE
type: Group
defaultPUIncomingTrafficAction: Allow
defaultPUOutgoingTrafficAction: Allow
EOF

cat <<EOF | apoctl api create namespace -n $APORETO_PARENT_NAMESPACE/$APORETO_CHILD_NAMESPACE -f -
name: $APORETO_GRANDCHILD_NAMESPACE2
type: Group
defaultPUIncomingTrafficAction: Allow
defaultPUOutgoingTrafficAction: Allow
EOF
cat <<EOF | apoctl api create namespace -n $APORETO_PARENT_NAMESPACE/$APORETO_CHILD_NAMESPACE -f -
name: $APORETO_GRANDCHILD_NAMESPACE2
type: Group
defaultPUIncomingTrafficAction: Allow
defaultPUOutgoingTrafficAction: Allow
EOF


