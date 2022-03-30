#!/usr/bin/env pwsh
<#
Written by Kyle Butler

Tested with Powershell version 7.2.1

This script will pull all the compliance sections from the framework assigned to the $COMPLIANCE_NAME variable and report back how many resources are passing and failing under each
underlying sections of the compliance/security framework.

In order to run you must first create a set of access keys in the Prisma Cloud Console.

You'll need to download them as a csv. In the third row of the sheet in the second column add the API url which corresponds to the app url for prisma cloud.
See this page for documentation https://prisma.pan.dev/api/cloud/api-urls

If you're using the compute functionality in the Enterprise addition, copy the access key and paste it in cell B4 and the
secret key to cell B5 in the csv. You'll also need to copy the Compute API url from the console under: Compute > Manage > System > Utilities > Path to console and place the URL in cell B6
For documentation on where to find this URL see this page https://prisma.pan.dev/api/cloud/cwpp/how-to-eval-console

If you're using the self-hosted edition, create a user in the console and place the username in cell B4 and the password in B5. Copy and paste the URL to the selfhosted edition of the platform
along with the port and paste it in cell B6.

Last, assign the variables under the USER CONFIG section below.
#>

# USER CONFIG SECTION

# directory path to the access_key/secret_key csv. 
$PATH_TO_ACCESSKEY_FILE = "C:\DIR\PATH\TO\example_access_key_file.csv"
$COMPLIANCE_NAME = "PCI DSS v3.2.1"
$TIME_TYPE = "relative"
$TIME_AMOUNT = "1"
$TIME_UNIT = "month"


# END OF USER CONFIG SECTION

# allows for self-signed certs
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $True }

# default powershell uses tls version 1.0 this forces tls 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


# Reads the access_key/secret_key csv file and pulls the values from the second column of the table/sheet
$KEY_ARRAY = foreach($line in [System.IO.File]::ReadLines("$PATH_TO_ACCESSKEY_FILE")){
        $line.Split(",")[1]
}

$PC_ACCESSKEY = $KEY_ARRAY[0]
$PC_SECRETKEY = $KEY_ARRAY[1]
$PC_APIURL = $KEY_ARRAY[2]
$TL_USER = $KEY_ARRAY[3]
$TL_PASSWORD = $KEY_ARRAY[4]
$TL_CONSOLE = $KEY_ARRAY[5]


$AUTH_PAYLOAD = @{
  "username" = "$PC_ACCESSKEY"
  "password" = "$PC_SECRETKEY"
}

$AUTH_PAYLOAD = $AUTH_PAYLOAD | ConvertTo-Json

$PC_AUTH_RESPONSE = Invoke-RestMethod `
    -Uri $("$PC_APIURL" + "/login") `
    -body $AUTH_PAYLOAD `
    -Method POST `
    -Headers @{"Content-Type" = "application/json"}

$PC_JWT = $PC_AUTH_RESPONSE.token

$PC_AUTH_HEADERS = @{
    "x-redlock-auth" = "$PC_JWT"
    "Content-Type" = "application/json"
}

$COMPLIANCE_IDS = Invoke-RestMethod `
    -Uri $("$PC_APIURL" + "/compliance") `
    -Headers $PC_AUTH_HEADERS `
    -Method GET

$FILTERED_COMPLIANCE_ID_AND_NAME = $COMPLIANCE_IDS | select-object id,name | where-object {$_.name -eq "$COMPLIANCE_NAME"}

$FILTERED_COMPLIANCE_ID = $FILTERED_COMPLIANCE_ID_AND_NAME.id

$REQUIREMENT_IDS = Invoke-RestMethod `
    -Uri $("$PC_APIURL" + "/compliance/" + "$FILTERED_COMPLIANCE_ID" + "/requirement") `
    -Headers $PC_AUTH_HEADERS `
    -Method GET


$REQUIREMENT_ID_ARRAY = $REQUIREMENT_IDS.id

foreach($REQUIREMENT_ID in $REQUIREMENT_ID_ARRAY){
  Invoke-RestMethod `
    -Uri $("$PC_APIURL" + "/compliance/posture/" + "$FILTERED_COMPLIANCE_ID" + "/" + "$REQUIREMENT_ID" + "?timeType=" + "$TIME_TYPE" + "&timeAmount=" + "$TIME_AMOUNT" + "&timeUnit=" + "$TIME_UNIT") `
    -Headers $PC_AUTH_HEADERS `
    -Method GET
}

