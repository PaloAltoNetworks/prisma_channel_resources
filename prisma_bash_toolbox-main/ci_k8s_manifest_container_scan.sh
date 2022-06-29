#!/usr/bin/env bash
# Author Kyle Butler
# For CI pipeline
# Scan all the container images in a k8s manifest prior to deployment
# Add twistcli and bash to runner prior to executing script

source ./secrets/secrets
source ./func/func.sh

K8S_MANIFEST_LOCATION="./dir/path/to/manifest.yml"


tl-var-check
declare -a IMAGE_ARRAY=($(cat $K8S_MANIFEST_LOCATION | awk -F "image:" '/image/ {print $2}'))


for i in ${IMAGE_ARRAY[@]}; do
        # podman pull $i if using podman
        docker pull $i
        # ./twistcli images scan --podman or --podman-path PATH depending on install --address $TL_CONSOLE -u $TL_USER -p $TL_PASSWORD --details $i
        ./twistcli images scan --address $TL_CONSOLE -u $TL_USER -p $TL_PASSWORD --details $i
done    

exit
