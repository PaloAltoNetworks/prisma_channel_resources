#!/usr/bin/env pwsh
<#
Written by Kyle Butler

Tested with Powershell version 7.2.1

This script will add a user programmatically to the Prisma Cloud Enterprise edition of the console. 

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


$PC_USER_FIRSTNAME = "<USER_FIRST_NAME>"
$PC_USER_LASTNAME = "<USER_LAST_NAME>"
$PC_USER_ROLE = "<USER_ROLE_CASE_SENSITIVE>"
$PC_USER_EMAIL = "<USER_EMAIL>"
$PC_USER_TIMEZONE = "America/New_York"
$PC_USER_KEY_EXPIRATION_DATE = "0"
$PC_USER_ACCESSKEY_ALLOW = "true"

$PC_USER_KEY_EXPIRATION = "false"


# END OF USER CONFIG SECTION

# Allows for self signed certs
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $True }

# default powershell uses tls 1.0. This forces tls 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$PC_USERNAME = "$PC_USER_EMAIL"
$PC_USER_ACCESSKEY_NAME = "$PC_USER_FIRSTNAME accesskey"

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

$PC_USER_ROLES = Invoke-RestMethod `
    -Uri $("$PC_APIURL" + "/user/role") `
    -Headers $PC_AUTH_HEADERS

$PC_USER_ROLE_ID_AND_NAME = $PC_USER_ROLES | Select-Object id,name | Where-Object {$_.name -eq "$PC_USER_ROLE"}

$PC_USER_ROLE_ID = $PC_USER_ROLE_ID_AND_NAME.id

$PC_ROLE_PAYLOAD = @{
  "accessKeyExpiration" = "$PC_USER_KEY_EXPIRATION_DATE"
  "accessKeyName" = "$PC_USER_KEY_NAME"
  "accessKeysAllowed"= "$PC_USER_ACCESSKEY_ALLOW"
  "defaultRoleId" = "$PC_USER_ROLE_ID"
  "email" = "$PC_USER_EMAIL"
  "enableKeyExpiration" = "$PC_USER_KEY_EXPIRATION"
  "firstName" = "$PC_USER_FIRSTNAME"
  "lastName" = "$PC_USER_LASTNAME"
  "roleIds" = @(
    "$PC_USER_ROLE_ID"
  )
  "timeZone" = "$PC_USER_TIMEZONE"
  "type" = "USER_ACCOUNT"
  "username" = "$PC_USERNAME"
}

$PC_ROLE_PAYLOAD = $PC_ROLE_PAYLOAD | ConvertTo-Json -Depth 99

Invoke-RestMethod `
    -uri $("$PC_APIURL" + "/v2/user") `
    -Headers $PC_AUTH_HEADERS `
    -Body $PC_ROLE_PAYLOAD `
    -Method POST
                   
