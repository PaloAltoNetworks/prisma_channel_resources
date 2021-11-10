## Purpose:

To familiarize engineers with the Prisma Cloud CSPM API endpoints using bash and HashiCorp Vault. See why a secrets manager is awesome and learn how to leverage one to script and automate IT Tasks. In this tutorial you will ultimately create a script which pulls down all the alerts from the last 24hrs in the CSPM section of Prisma Cloud. My goals are to ensure you have an introduction to a popular secrets manager, to give you practice working with a RESTFUL api, and to show you some tricks in the bash shell. 

## Prerequisites: 

This assumes you have vault running in your lab.  
* Setup [Vault](https://learn.hashicorp.com/tutorials/vault/getting-started-install?in=vault/getting-started)

   
If you don't want to run vault in dev mode or set it up properly, you can replace the variables with the secrets. Just ensure you take the necessary steps to protect the secrets you'll be hardcoding into your script. I'm assuming you're using a UNIX based system. This will work on RHEL, MacOS, and other flavors of linux. I wrote the package manager/install instructions for Ubuntu, but if using a different distro replace `apt` with `brew` or `yum`.


PANW Engineers --- take yourself off of Global Protect when doing this tutorial

## Step 1: Add Prisma Cloud Access Keys and Secret Keys to vault.
Go to the [Prisma PAN API Documentation Page](https://prisma.pan.dev/api/cloud/api-urls) to find your api url. Your Prisma Cloud API URL will correspond with your Prisma Cloud tenent. Write this down as `$pcee_api_url`. 

Log into the enterprise edition of Prisma Cloud and go to Settings > Access Keys

Create a set of access keys for your user. Be mindful of the expiration date. We'll use these in a later step. 

In your terminal:

```bash
vault kv put secret/prisma_enterprise_env \
             pcee_api_url='https://<API_URL_FROM_LINK_ABOVE>' \
             pcee_accesskey='<YOUR_ACCESS_KEY>' \
             pcee_secretkey='<YOUR_SECRET_KEY>'
```

The above command will put your secrets into your dev vault server. To retrieve your keys you'll need one more tool on your system. JQ! 

To install JQ:

Ubuntu:
```bash 
sudo apt-get install jq
```
RHEL:
```bash
yum install jq
```
MacOS:
```bash
brew install jq
```

After installing jq, you'll want to test retrieving your secrets in a secure format. To do that, enter this in terminal:

```bash
vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_api_url
vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_accesskey
vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_secretkey
```

## Step 2: Create your api script to return the JWT needed for authentication
 
First, create a new project directory and cd into it:
```
mkdir prisma_api_dir
cd prisma_api_dir/
```

Next, create a new file `nano prisma_api_test.sh`

The first line we'll type in our script is a she-bang. This ensures our script is interpreted correctly.

```bash
#!/bin/bash
```

Next we'll define our variables. 

```bash
#!/bin/bash

pcee_api_url=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_api_url)
pcee_accesskey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_accesskey)
pcee_secretkey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_secretkey)
```

The last variable we need to define for now is the payload variable.

There's multiple ways to do this and pros and cons to each. 

For simplicity's sake, I'm going to create this variable in the script so you only have one file to worry about. The downsides to this method are: 

1. the script is less readable and
2. you have to be more sensitive to the formatting

Here's our json payload we'll need to send with our first api call:
```json
{
  "password": "string",
  "username": "string"
}
```

The problem is, bash won't interpret that correctly if we assigned the raw json to a variable. To get around this we'll need to reformat the raw json so it's it's interpreted correctly. 

_TIP: I use vim as my editor of choice. A simple shortcut is to leverage the stream editor capabilities of vim to do this quickly. If you're just learning how to work with the bash shell...stick with nano for now_

Here's how we'll define the last variable for our script. 

```bash 
#!/bin/bash

pcee_api_url=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_api_url)
pcee_accesskey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_accesskey)
pcee_secretkey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_secretkey)

pcee_auth_payload="{\"password\": \"$pcee_secretkey\", \"username\": \"$pcee_accesskey\"}"
```

Now we're ready to make our first api call using curl. 

Let's go to the [Prisma Pan API Documentation Page](https://prisma.pan.dev/api/cloud/cspm/login#operation/app-login) to retrieve the api endpoint we'll need. In this case, the api endpoint we want is `/login`.

We'll copy out the request sample from the `Shell + Curl` tab on the right-hand of the documentation page and paste it into our script. 

_Note: the `#` comments out the line in bash. I'll use that indicate what I'm doing_

```bash
#!/bin/bash

pcee_api_url=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_api_url)
pcee_accesskey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_accesskey)
pcee_secretkey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_secretkey)

pcee_auth_payload="{\"password\": \"${pcee_secretkey}\", \"username\": \"${pcee_accesskey}\"}"

# HERE'S WHAT WE COPIED FROM THE DOCUMENTATION PAGE:

curl --request POST \
  --url https://api.prismacloud.io/login \
  --header 'content-type: application/json; charset=UTF-8'
```

We'll need to change the request sample so it works with our script. First, we'll clean up the formatting and then replace the url with our `$pcee_api_url` variable + the api endpoint `/login`. 


_Note: the `\` is used to break the line for readability...but ultimately isn't necessary. When using a `\` it's important to be mindful of extra spaces after the `\`_

Many people who are first learning bash have issues with the spacing and formatting because they're not thinking about how the code is interpreted. Example:

```bash
curl --request POST \
  --url https://api.prismacloud.io/login \
  --header 'content-type: application/json; charset=UTF-8'
```

Is the same as:
```bash
curl --request POST --url https://api.prismacloud.io/login --header 'content-type: application/json; charset=UTF-8'
```

_TIP: Sometimes it's easier to make it all one line and then add the `\` in as needed. This ensure's you don't have weird spacing issues when scripting._

The last modification we'll need to add is the request body or data from our json payload. `--data ${pcee_auth_payload}`

Here's what your script should look like after we add the variables in and clean up the formatting:

```bash
#!/bin/bash

pcee_api_url=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_api_url)
pcee_accesskey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_accesskey)
pcee_secretkey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_secretkey)

pcee_auth_payload="{\"password\": \"$pcee_secretkey\", \"username\": \"$pcee_accesskey\"}"

# HERE'S WHAT WE COPIED FROM THE DOCUMENTATION PAGE:

curl --request POST \
     --url "${pcee_api_url}/login" \
     --header 'content-type: application/json; charset=UTF-8' \
     --data "${pcee_auth_payload}"
```

## Step 3: Save your script and execute it!

In our scripts current form we should be able to invoke it and retrieve the JWT (JSON Web Token; pronouced: JOT). 

Let's test it out! Hit `ctrl + x` and then `y` to save your script. 

Execute it from the terminal by entering: `bash prisma_api_test.sh`. You should get a response that looks like this:

```json
{"token":"<SUPER_LONG_STRING>","message":"login_successful","customerNames":[{"customerName":"partnerdemo","tosAccepted":true}]}
```

Uh-oh...well that's pretty ugly and also unusable to pass downstream for more api calls. Let's start leveraging jq. Enter the same command you entered before but add `| jq` to the end of it. This will "pretty print" the response so we can understand how to filter it for later use. 

```bash
bash prisma_api_test.sh | jq
```

Now our response will look like this:

```json
{
  "token": "<SUPER_LONG_STRING>",
  "message": "login_successful",
  "customerNames": [
    {
      "customerName": "partnerdemo",
      "tosAccepted": true
    }
  ]
}
```

## Step 4: Using JQ to filter and parse the JSON response

Okay...so now it's easier to look at. Let use jq to filter out the token which is what we'll need for our next api call. To do that, we will first need to break down what we want. Ideally, we want the `"value"` of the `"token"` key. To isolate the `"value (or <SUPER_LONG_STRING>)"` of the token key we'll modify our command to: 

```bash
bash prisma_api_test.sh | jq -r '.token'
```

_Note: the `-r` removes the quotes._

Now you have the TOKEN isolated! Perfect. Copy out the `| jq -r '.token'` from your terminal and edit your script again. We'll modify the script so it saves our first api call to another variable `$pcee_auth_token` which we'll then use in another api call.

So we can observe what's happening let's go ahead and `echo` the variable `$pcee_auth_token` at the end of our script.

Let's re-open our script in nano: `nano prisma_api_test.sh`. 

Our goal here is to assign the response to a variable named `$pcee_auth_token`. To do that we'll wrap our `curl` command in `$()` and then adjust the formatting for maintainability.

Finally, we'll add the `echo "${pcee_auth_token}"` to the end of our script so we can see that we've captured the JWT. 

```bash
#!/bin/bash

pcee_api_url=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_api_url)
pcee_accesskey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_accesskey)
pcee_secretkey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_secretkey)

pcee_auth_payload="{\"password\": \"$pcee_secretkey\", \"username\": \"$pcee_accesskey\"}"

# HERE'S WHAT WE COPIED FROM THE DOCUMENTATION PAGE:

pcee_auth_token=$(curl --request POST \
                       --url "${pcee_api_url}/login" \
                       --header 'content-type: application/json; charset=UTF-8' \
                       --data "${pcee_auth_payload}" | jq -r '.token')

# Check the output

echo "${pcee_auth_token}"
```

After your script looks like the code block above, hit `ctrl + x` then `y` on your keyboard to close and save the changes. 

Now it's time to invoke your script again. 

```bash
bash prisma_api_test.sh
```

You should see the curl progress and your JWT print out in the response. That's perfect. Now we can access all the other Prisma Cloud CSPM API's (It's a similar process with some minor tweaks when accessing the CWPP API). 

## Step 5: Modifying the /v2/alerts API endpoint and working with URL filters

For this tutorial I'll choose a more complex api endpoint: `/v2/alert`. For smart engineers, I think you'll understand why I'm going to call this one. 

First, let's go to the [Prisma Pan API Documentation](https://prisma.pan.dev/api/cloud/cspm/alerts#operation/get-alerts-v2). 

Copy out the "Request sample" as we did before from the `Shell+Curl` tab. It should look something like this:

```bash
curl --request GET \
  --url 'https://api.prismacloud.io/v2/alert?timeType=SOME_STRING_VALUE&timeAmount=SOME_STRING_VALUE&timeUnit=SOME_STRING_VALUE\
  &detailed=SOME_BOOLEAN_VALUE&fields=SOME_STRING_VALUE&sortBy=SOME_STRING_VALUE&offset=SOME_NUMBER_VALUE\
  &limit=SOME_NUMBER_VALUE&pageToken=SOME_STRING_VALUE&alert.id=SOME_STRING_VALUE&alert.status=SOME_STRING_VALUE\
  &cloud.account=SOME_STRING_VALUE&cloud.accountId=SOME_STRING_VALUE&account.group=SOME_STRING_VALUE&\
  cloud.type=SOME_STRING_VALUE&cloud.region=SOME_STRING_VALUE&cloud.service=SOME_STRING_VALUE&policy.id=SOME_STRING_VALUE&\
  policy.name=SOME_STRING_VALUE&policy.severity=SOME_STRING_VALUE&policy.label=SOME_STRING_VALUE&\
  policy.type=SOME_STRING_VALUE&policy.complianceStandard=SOME_STRING_VALUE&\
  policy.complianceRequirement=SOME_STRING_VALUE&policy.complianceSection=SOME_STRING_VALUE&\
  policy.remediable=SOME_STRING_VALUE&alertRule.name=SOME_STRING_VALUE&resource.id=SOME_STRING_VALUE&\
  resource.name=SOME_STRING_VALUE&resource.type=SOME_STRING_VALUE&risk.grade=SOME_STRING_VALUE' \
  --header 'x-redlock-auth: REPLACE_KEY_VALUE'
```

Kind of ugly right? To understand why let's look at the documentation and see what the `Query Parameters` are. We want to see which filters are `required` vs the ones we can skip. In this case, the required fields are:


* `timeType`
* `timeAmount`
* `timeUnit` 
* `detailed`


Let's simplify our `/v2/alert` api endpoint and take out all the filters we don't need. Our request without the unecessary filters will look like this:

```bash
curl --request GET \
  --url 'https://api.prismacloud.io/v2/alert?timeType=SOME_STRING_VALUE&timeAmount=SOME_STRING_VALUE&timeUnit=SOME_STRING_VALUE&detailed=SOME_BOOLEAN_VALUE
  --header 'x-redlock-auth: REPLACE_KEY_VALUE'
```

Better! But still not in a format we can use for our script. We'll need to replace the url with our `$pcee_api_url`, then assign the filters to acceptable values, and finally pass our `pcee_auth_token` in the `--header 'x-redlock-auth: REPLACE_KEY_VALUE'`

_Tip: For some reason our documentation has everything with `'` quotes rather than `"` quotes. This will cause issues with variable expansion so keep an eye out for those pitfalls._

For our filters, we can see from the documentation page, what the acceptable values are for the filters we need to assign: 

* For `typeType` we have the option of choosing `"relative"` (the normal filter one would use) or `"absolute"`. 
* For `timeAmount` it's looking for an integer value. (1,2,3, etc.)
* For `timeUnit` we can choose either `"minute"`, `"hour"`, `"day"`, `"week"`, `"month"`, or `"year"`
* For `detailed` we can either choose `"true"` or `"false"`

Let's assume we want to show our customer that with our api script we're able to pull all the alerts from the last day and then feed them into a different system. For that to work, we'll assign the filter values in the api endpoint and finally paste it back into our script with the  `$pcee_api_url` and `$pcee_auth_token` variables. 

We'll also need to add a `--header` to define how we want the data returned. In this case, we'll add `--header 'Accept: application/json'`

```bash
curl --request GET \
     --url "${pcee_api_url}/v2/alert?timeType=relative&timeAmount=1&timeUnit=day&detailed=true" \
     --header "x-redlock-auth: ${pcee_auth_token}" \
     --header 'Accept: application/json'
```

## Step 6: Calling your script to retrieve the alerts and more advanced JQ filters

There! Much better! Let's copy that code block into our clipboard and paste it back into our script. `nano prisma_api_test.sh`

When editing our script we'll want to quiet the output of our `/login` api call and our `/v2/alerts` call by adding a `-s` after the `curl commands`. (You'll see why I'm doing this in a moment)

After pasting the modified request back into the script and adding the `-s` to our `curl` commands, our script should now look like the code block below:

```bash
#!/bin/bash

pcee_api_url=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_api_url)
pcee_accesskey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_accesskey)
pcee_secretkey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_secretkey)

pcee_auth_payload="{\"password\": \"$pcee_secretkey\", \"username\": \"$pcee_accesskey\"}"

# NOTICE THE -s I've added to this call. This quiets the command

pcee_auth_token=$(curl -s --request POST \
                          --url "${pcee_api_url}/login" \
                          --header 'content-type: application/json; charset=UTF-8' \
                          --data "${pcee_auth_payload}" | jq -r '.token')

# HERE'S OUR MODIFIED REQUEST with an added -s 

curl -s --request GET \
        --url "${pcee_api_url}/v2/alert?timeType=relative&timeAmount=1&timeUnit=day&detailed=true" \
        --header "x-redlock-auth: ${pcee_auth_token}"
```

Okay, time to call our script again. Hit `ctrl + x` then `y` to save and exit. 

In terminal we'll invoke our script again with bash, but this time we'll add `| jq` so it "pretty prints" the output. 

```bash
bash prisma_api_test.sh | jq
```

The reason why we added the `-s` to our curl command is so the output can be filtered correctly with jq. 

_TIP: instead of `-s` you might try `-v` to your curl command if you don't get the expected response. `-v` enables verbose mode which will allow you to see the HTTP code that is returned. This can greatly help when debugging_

Okay so now you have the data pretty printed, but the output is probably long and ugly. Let's send the output to a `temp.json` file so we can understand what we want to look at. `bash prisma_api_test.sh | jq > temp.json`


Let's open the temp.json file: `nano temp.json` we're now able to get an idea of what we want. In this case we want the items array with the name of the policy that triggered the alert. 

_NOTE: Teaching the full ins and outs of jq is outside the scope of this tutorial. Many good resources online. Google jq documentation_

By inspecting our `temp.json` file we should be able to find the necessary filters we'll need to provide the policy name of the alert along with some more useful information.

The jq filters we'll need are: `.items[].policy.name`. Then we'll need a few more filters to make the data meaningful. Let's pull out the resource api name located at: `.items[].resource.resourceApiName` and any resource tags applied to the cloud resource: `.items[].resource.resourceTags`. 

_NOTE: Of course there needs to be tags applied in order for this last filter to work. The partner demo system in app2 doesn't have a lot of tags applied to resources currently_

We now have everything we need to parse the output. Ultimately, we'll use jq to create a new object. Our next script invocation will be:

```bash 
bash prisma_api_test.sh | jq '.items[] | {policyName: .policy.name, resourceApiName: .resource.resourceApiName, resourceTags: .resource.resourceTags}'
```

_TIP: If you want to experiment with jq. Try: `cat temp.json | jq \<YOUR\_CUSTOM\_FILTERS\_HERE\>`._

As a final step, we'll add the filter we made back into our script. Let's copy our filter:

```
| jq '.items[] | {policyName: .policy.name, resourceApiName: .resource.resourceApiName, resourceTags: .resource.resourceTags}'
```

We'll use `nano` again.

`nano prisma_api_test.sh`

After you copy and paste your filter to the end of the `curl` command, it should look like the code block below:

```bash
#!/bin/bash

pcee_api_url=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_api_url)
pcee_accesskey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_accesskey)
pcee_secretkey=$(vault kv get -format=json secret/prisma_enterprise_env | jq -r .data.data.pcee_secretkey)

pcee_auth_payload="{\"password\": \"$pcee_secretkey\", \"username\": \"$pcee_accesskey\"}"

# NOTICE THE -s I've added to this call. This quiets the command

pcee_auth_token=$(curl -s --request POST \
                          --url "${pcee_api_url}/login" \
                          --header 'content-type: application/json; charset=UTF-8' \
                          --data "${pcee_auth_payload}" | jq -r '.token')

# Check the filter! We copied in. Here's our api alert. 

curl -s --request GET \
        --url "${pcee_api_url}/v2/alert?timeType=relative&timeAmount=1&timeUnit=day&detailed=true" \
        --header "x-redlock-auth: ${pcee_auth_token}" \
        | jq '.items[] | {policyName: .policy.name, resourceApiName: .resource.resourceApiName, resourceTags: resource.resourceTags}'
```

We can now call our script and it will return all the alerts from the last 24 hrs. With the name of the policy that triggered the alert, the resource api name, and any resource tags applied. 

Restful API 101 complete. You are now armed with some confidence when working with the Prisma Cloud Enterprise API. Some more suggestions below

Call your script:
`bash prisma_api_test.sh`

Make your script executable:
`chmod u+x prisma_api_test.sh`

Now you can call it by just entering the name of the script:
`./prisma_api_test.sh`

Lots more fun things to do and learn. More to come!

## REFERENCE LINKS:

* [Offical JQ Documentation](https://stedolan.github.io/jq/manual/)
* [Curl Manual --if you're not comfortable working with man curl in Terminal](https://man7.org/linux/man-pages/man1/curl.1.html)
* [Why REST API Execution Through the Bash Shell Makes Sense](https://apiacademy.co/2019/10/devops-rest-api-execution-through-bash-shell-scripting/)
* [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
