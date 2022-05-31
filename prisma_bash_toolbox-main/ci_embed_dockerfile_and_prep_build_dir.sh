#!/bin/bash

#Written by Kyle Butler 
# 12.9.2021

source ./secrets/secrets
source ./func/func.sh


# App-id: Custom value to used for collections and scope in WAAS policies. See https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/install/install_defender/install_rasp_defender
APP_ID="my-app"

# Full directory path to Dockerfile
PATH_TO_DOCKERFILE="./Dockerfile"

# Name of the output file. Should end with .zip
OUTPUT_FILE_NAME="package.zip"





#########################################################################################
# Below vars will only need to be set if a conflict in naming of directories occurs     # 
# on host/container/ or would conflict with build commands. If unsure, consult          #
# Docker documentation.                                                                 #  
#########################################################################################


# Temp location where the app embedded package is unzipped to prior to copy commands.
UNZIP_DIR="./app_embedded_Dockerfile_dir/"

# Where to store the defender files on the container
DATA_FOLDER="/twistlock/"

tl-var-check

# Check to ensure unzip is installed and available
unzip -v

quick_check "unzip must be installed prior to running"


# Checks to ensure the Dockerfile ends with an entrypoint or CMD
tail -3 $PATH_TO_DOCKERFILE | grep -P "(ENTRYPOINT \[|CMD \[)"
    

# Dockerfile must include either a CMD or ENTRYPOINT see documentation: https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/install/install_defender/install_rasp_defender.html
quick_check "an entrypoint must be included in your docker file to do the embedding."

echo
echo
echo 
echo "This next warning is to allow for an api request to the self-hosted edition of the console deployed with the default self-signed cert. To remove this warning, disable the --no-check-certificate flag; see man wget."
echo
echo
echo

# Retrieves twistcli tool from the console using wget. Encodes the credentials using base64 encoding
wget --no-check-certificate --header "Authorization: Basic $(echo -n $TL_USER:$TL_PASSWORD | base64 | tr -d '\n')" "$TL_CONSOLE/api/v1/util/twistcli"


# Grants permissions to excute tool
chmod a+x ./twistcli




# Twistcli command to create app embedded package
./twistcli app-embedded embed --address $TL_CONSOLE \
	                      -u $TL_USER \
			      -p $TL_PASSWORD \
			      --app-id $APP_ID \
			      --data-folder $DATA_FOLDER \
			      --output-file $OUTPUT_FILE_NAME \
			      $(basename -a $PATH_TO_DOCKERFILE)


quick_check "App Embedded twistcli command failed."


# Unzips the package app embedded defender package along with the modified Dockerfile
unzip "./$OUTPUT_FILE_NAME" -d "$UNZIP_DIR"


# Renames the original Dockerfile
mv "$PATH_TO_DOCKERFILE" "$PATH_TO_DOCKERFILE.old"

# Moves the modified Dockerfile to the original Dockerfile directory
cp $( printf %s "${UNZIP_DIR}Dockerfile")  $( dirname $PATH_TO_DOCKERFILE/ )

# Moves the app embedded defender binaries into the original Dockerfile directory
cp $( printf %s "${UNZIP_DIR}twistlock_defender_app_embedded.tar.gz") $( dirname $PATH_TO_DOCKERFILE/ )




# Remove if annoying but this would be when the build begins
echo
echo 
echo
echo "Embedded Dockerfile is ready for build steps/stage"
echo "Old Dockerfile has been renamed to Dockerfile.old"
echo 
echo
exit
