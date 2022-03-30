#!/usr/bin/env pwsh
<#
Written by Kyle Butler
Tested with Powershell version 5.1.14393.1884
On Windows Server 2016 with docker installed: https://docs.microsoft.com/en-us/virtualization/windowscontainers/quick-start/set-up-environment

Ensure user has permissions to the docker engine or run with elevated "Admin: privileges

For usage in Azure DevOps see: https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/utility/powershell

This script will pull down the windows twistcli binary and run an image scan on windows containers which are locally available. 

In order to run you must first create a set of access keys in the Prisma Cloud Console.

You'll need to download them as a csv. In the third row of the sheet in the second column add the API url which corresponds to the app url for prisma cloud.

See this page for documentation https://prisma.pan.dev/api/cloud/api-urls
If you're using the compute functionality in the Enterprise Edition, copy the access key and paste it in cell B4 and the
secret key to cell B5 in the csv. You'll also need to copy the Compute API url from the console under: Compute > Manage > System > Utilities > Path to console and place the URL in cell B6

For documentation on where to find this URL see this page https://prisma.pan.dev/api/cloud/cwpp/how-to-eval-console

If you're using the self-hosted edition, create a user in the console and place the username in cell B4 and the password in B5. Copy and paste the URL to the selfhosted edition of the platform
along with the port and paste it in cell B6.
Last, assign the variables under the USER CONFIG section below.
#>


# USER CONFIG

# The location you want the twistcli binary to be downloaded to. Must end with twistcli.exe
$TWISTCLI_OUTFILE_LOCATION = "C:\Users\<USERNAME>\twistcli.exe"

# The location you want the scan report to be
$TL_SCAN_REPORT_LOCATION = "C:\Users\<USERNAME>\Desktop\report.txt"


# Only part you should change assuming the docker engine is running on localhost is the port number if using a non-standard docker port
$env:DOCKER_HOST = "tcp://localhost:2375"


# Image must be locally available: To verify run docker images before running the script
$CONTAINER_IMAGE = "mcr.microsoft.com/windows/servercore:1607-amd64"

# Directory path to the access_key/secret_key csv. 
$PATH_TO_ACCESSKEY_FILE = "C:\DIR\PATH\TO\example_access_key_file.csv"


### END OF REQUIRED USER USER CONFIGURATION

# allows for self-signed certs
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $True }

# default powershell Invoke-web request uses tls 1.0 this forces Tls12
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


# creates the request body and then converts to JSON format
$AUTH_PAYLOAD = @{
  "username" = "$TL_USER"
  "password" = "$TL_PASSWORD"
}

$AUTH_PAYLOAD = $AUTH_PAYLOAD | ConvertTo-Json

# Authenticates to the console and retrieves token
$TL_AUTH_RESPONSE = Invoke-RestMethod `
    -Uri $("$TL_CONSOLE" + "/api/v1/authenticate") `
    -body $AUTH_PAYLOAD `
    -Method POST `
    -Headers @{"Content-Type" = "application/json"}


# Isolates token from the response above
$TL_JWT = $TL_AUTH_RESPONSE.token

# Creates the request header for the next request
$TL_AUTH_HEADERS = @{ 
  "Authorization" = "Bearer $TL_JWT" 
}

# Calls the Compute API Endpoint to bring down the twistcli tool
Invoke-RestMethod `
  -Uri $("$TL_CONSOLE" + "/api/v1/util/windows/twistcli.exe") `
  -Headers $TL_AUTH_HEADERS `
  -Method Get `
  -Outfile "$TWISTCLI_OUTFILE_LOCATION"


# Runs the twistcli tool with the correct parameters. If you'd like to output a json report uncomment the below command and delete the last command. 

#Start-Process `
#  -FilePath "$TWISTCLI_OUTFILE_LOCATION" `
#  -ArgumentList "images ","scan ","--address $TL_CONSOLE ","-u $TL_USER ","-p $TL_PASSWORD ","--details ", "--output-file $TL_SCAN_REPORT_LOCATION ","$CONTAINER_IMAGE"

Start-Process `
  -FilePath "$TWISTCLI_OUTFILE_LOCATION" `
  -ArgumentList "images ","scan ","--address $TL_CONSOLE ","-u $TL_USER ","-p $TL_PASSWORD ","--details ","$CONTAINER_IMAGE" `
  -RedirectStandardOutput "$TL_SCAN_REPORT_LOCATION"
