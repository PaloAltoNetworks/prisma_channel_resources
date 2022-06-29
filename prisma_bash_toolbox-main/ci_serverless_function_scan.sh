#!/usr/bin/env bash
# Written by Kyle Butler
# Use to surface the apis and permissions for serverless functions during CI. Recommending to use the CI_local_repo_scan.sh script along with this one to get vulnerability information about the workload. 
# ZIPS ALL THE FILES IN THE CURRENT WORKING DIRECTORY TO SCAN will output a temp zip file.

# Can use ENV VAR available to to the runner to populate this value
FUNCTION_NAME="CODE_REPO"

# Location and name for the temp.zip file that's created prior to the scan
TEMP_ZIP_NAME="./temp.zip"


source ./secrets/secrets
source ./func/func.sh


tl-var-check
# Checks to ensure zip is installed and available to the runner
if ! type "zip" > /dev/null; then
  echo "zip not installed or not in execution path, zip is required for this script; please add zip to the runner prior to executing this script in the workflow";
  exit 1;
fi


# Zips all files in the current working directory
zip -r $TEMP_ZIP_NAME .

# Scans the serverless function files and will return the vulnerabilities, config, and api's. see ./twistcli --help for more options. 
twistcli serverless scan --address $TL_CONSOLE -u $TL_USER -p $TL_PASSWORD --details --function $FUNCTION_NAME --output-used-apis $TEMP_ZIP_NAME
