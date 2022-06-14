# Prisma Cloud Code Security and Terraform Sentinel Set-up
Requirements:

* GitHub repository with terraform files in it something like [this](https://github.com/kyle9021/wbc-demo)
* An AWS Account with an IAM user that has permissions to deploy IaC files
* AWS Access Key and Secret key created for your IAM user
* A license for Prisma Cloud Enterprise with the Code Security Module. 
* A blank text doc that looks like [this](https://github.com/kyle9021/wbc-demo/blob/main/example_text_doc.txt)


## In Terraform Cloud

* Navigate to: https://cloud.hashicorp.com/products/terraform and click the Try Cloud for Free button in the top right corner. 
* Sign-up for a free trial for Terraform Cloud Enterprise.
* Create a new organization by filling in a value for the Organization Name and then providing your email address. 
* Click the button to create a new workspace
* Choose your workflow and select version control. 
* Select GitHub. You'll need to sign into your GitHub account and ensure the Oauth scope includes the repo where your IaC files are stored. 
* Provide a name and then hit the 'Create Workspace' button
* On the 'Overview tab' click the button 'configure variables'
* Create workspace variables (you are welcome to create a variable set if you have multiple repos/projects). The two variables you'll need to add are `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. 
* Click the button '+ Add Variable' and select 'Environment Variable'
* The Key for the first variable will be `AWS_ACCESS_KEY_ID` (It's particular on the formatting, naming, and capitialization) and the value will be the IAM users '<ACCESS_KEY_ID>'.
* Make sure you check the box next to sensitive, then click save. Repeat the same process for `AWS_SECRET_ACCESS_KEY`
* After you create your variables and have them saved. Copy the workspace name you created earlier and save it in a text file as `WORKSPACE_NAME` we'll come back to this in a bit. 
* Also underneath your workspace name there should be an ID and a copy icon (looks like two pages on top of one another). Hit the 'copy button' and save the ID in the same text file you saved your `WORKSPACE_NAME` in. We'll need this later too. Save the id as `WORKSPACE_ID`

### Create a Terraform api token for your user

* In the top right corner of the page there should be a user/profile icon. 
* Click that and select 'User Settings'
* In the lefthand menu select the 'Tokens' section. 
* Click the Button 'Create an API token' and provide a description. Click the button 'Create API token' once the description has been entered. Copy the token to the same file you saved your `WORKSPACE_NAME` and `WORKSPACE_ID` in, then hit the Done button. Save the token as `TF_USER_TOKEN`
* In the top left hand banner click the drop down that says 'Choose an organization'. Select your organization that you created earlier, then select the workspace you created. 
* Open a new tab in your browser to the Prisma Cloud Enterprise Edition Console. We'll come back to Terraform Cloud in a moment.
 

## In Prisma Cloud

### Terraform Cloud Run Task configuration

* Log into your console and go to Settings > Repositories
* Click the blue button in the top right corner of the page to 'Add Repository' 
* Under the 'CI/CD Systems' section click 'Terraform Cloud (Run Tasks)'
* Paste the value you have for `TF_USER_TOKEN` under the user token section. Then click 'Next'
* From here select the organization you created in Terraform Cloud. Then click 'Next'
* On the next screen, select the Workspace you created in Terraform Cloud. You can choose whether or not you'd like the run task to be mandatory. For now leave the box unchecked, select the workspace and then hit next. 
* Once the page shows that the 'New Integration sucessfully configured' you can hit the 'Done' button. 

### Terraform Cloud Sentinel


* Log into your console and go to Settings > Repositories
* Click the blue button in the top right corner of the page to 'Add Repository' 
* Under the 'CI/CD Systems' section click 'Terraform Cloud (Sentinel)'
* Paste in the values you have on your text doc for `WORKSPACE_ID`, `WORKSPACE_NAME`, and `TF_USER_TOKEN`. Write something in the description section and then click the 'Next button'. NOTE: the Workspace Name must be the same capitialization as it appears in terraform cloud and you must have something typed into the description section. 
* Copy the policy on the next screen and paste it in your text doc. Write a note to remind you this policy should be named `sentinel.hcl` in your VCS. The Policy should look the code block below: 

```hcl
policy "prismacloud" {
        source            = "{PATH_TO_FILE}"
        enforcement_level = "hard-mandatory"
}
```
* alter the policy by replacing the value `{PATH_TO_FILE}` with `./prismacloud.sentinel`. The policy in your text doc should now look like the code block below:

```hcl
policy "prismacloud" {
        source            = "./prismacloud.sentinel"
        enforcement_level = "hard-mandatory"
}
```
* Once that's been done in your text file hit the next button in Prisma Cloud. 
* This will bring up another policy. Copy and paste this below the above policy and write a note that this will be saved as `prismacloud.sentinel`. 
* We don't need to alter this at all policy at all. It should look similar to the below code block:

```hcl 
import "http"
import "json" 

param PRISMA_ACCESS_KEY
param PRISMA_SECRET_KEY

loginReq = http.request("https://api2.prismacloud.io/login").with_body(json.marshal({"username": PRISMA_ACCESS_KEY, "password": PRISMA_SECRET_KEY})).with_header("Content-Type", "application/json")
loginResp = json.unmarshal(http.post(loginReq).body)
req = http.request("https://api2.prismacloud.io/bridgecrew/api/v1/tfCloud/sentinel/ws-wjkHiazBi7asooiM").with_header("Authorization", loginResp.token)
resp = json.unmarshal(http.get(req).body)
if (length(resp.violations) > 0) {
    print("Violations:\n")
    for resp.violations as violation {
        print(violation.title)
        print("Resource: " + violation.resource_id)
        print("Violation ID: " + violation.violation_id)
        print("\n")
    }
}
print("More details: " + resp.details_url)  
main = rule { length(resp.violations) < 1 }
    
```

* Once the policy has been copied to your text doc, click the 'Next' button and then the 'Done' button. 

### Create Prisma Cloud access keys 

* Click settings > access control, and click the blue 'Add' button. From the drop-down select access key or service account. 
* Fill in the appropriate fields and then hit save. 
* Copy the Prisma Access Key and Secret key to your text doc and save the values as `PRISMA_ACCESS_KEY` and `PRISMA_SECRET_KEY` respectively. We'll need those later. 


### Start setting up Run Tasks

* Click the browser tab you have open for Terraform Cloud. 
* Click the 'Settings' tab next to the 'Variables' tab under your workspace name in Terraform Cloud. 
* Because we completed the Terraform Cloud Run Task integration. we can verify that the `prisma-cloud` run task is available. You can change the 'Enforcement Level' of the Run task by clicking the '...' button, but otherwise it's good to go. 
* Advisory = soft fail
* Mandatory = hard fail
* Once you've set it to your desired state, open another browser tab to your github repository url which contains your terraform files. 


Quick side note here: 

The typical set-up would be that all the sentinel policies and whatnot are stored in a single repo which would be seperate from your terraform file repository. That way when people change/alter policies, version control is enabled. For the purposes of speed and effiency we'll just create the policies in the same repo as our terraform files. 


* Click the button to add a new file to your terraform file repository. This will be at the root level of the project and we'll name the file `sentinel.hcl`. Copy and paste the policy into the new file and the commit the file back to the repo. The `sentinel.hcl` file should look like the below code block: 

```hcl 
policy "prismacloud" {
        source            = "./prismacloud.sentinel"
        enforcement_level = "hard-mandatory"
}
```

* Click to button to add another file to your repository. This file will also be at the root level of the repository and should be named `prismacloud.sentinel`. Copy and paste the policy into the new file and the commit the file back to the repo. The `prismacloud.sentinel` file should look similar to the below code block: 


```hcl
import "http"
import "json" 

param PRISMA_ACCESS_KEY
param PRISMA_SECRET_KEY

loginReq = http.request("https://api2.prismacloud.io/login").with_body(json.marshal({"username": PRISMA_ACCESS_KEY, "password": PRISMA_SECRET_KEY})).with_header("Content-Type", "application/json")
loginResp = json.unmarshal(http.post(loginReq).body)
req = http.request("https://api2.prismacloud.io/bridgecrew/api/v1/tfCloud/sentinel/ws-wjkHiazBi7asooiM").with_header("Authorization", loginResp.token)
resp = json.unmarshal(http.get(req).body)
if (length(resp.violations) > 0) {
    print("Violations:\n")
    for resp.violations as violation {
        print(violation.title)
        print("Resource: " + violation.resource_id)
        print("Violation ID: " + violation.violation_id)
        print("\n")
    }
}
print("More details: " + resp.details_url)  
main = rule { length(resp.violations) < 1 }
```

* Once everything has been set up in your GitHub repo you can click your browser tab back to the Terraform Cloud Console. 


## In Terraform Cloud

* In the purple banner menu across the top of your Terraform Cloud Console select the word 'Settings' (next to 'Registry').
* In the left-hand menu select policy sets. 
* Click the Purple button in the Top right corner 'Connect a new policy set' 
* Select 'GitHub' as your version control provider. Then select your terraform repository which contains both your terraform files and policies you created earlier. 
* For now we can keep things default and have the Scope of the policies enforced on all workspaces. 
* Click the 'Connect Policy Set' button 
* Once the Policy Set has been created. Click the policy set you just crated. 
* At the bottom of the page click the '+ Add Parameter' button. 
* You'll need to create two paramaters. `PRISMA_ACCESS_KEY` and `PRISMA_SECRET_KEY`. 
* For the First Paramater we'll use the access key we copied from the Prisma Cloud Console in our text doc as `PRISMA_ACCESS_KEY`. The key should be exactly `PRISMA_ACCESS_KEY` and the value should be the actual key. Click the box next to sensitive, then click 'Save parameter'. 
* Do the same thing again for `PRISMA_SECRET_KEY`.
* After you've done that, in the top banner of the Terraform Cloud Console click the 'Workspace' section (next to 'Registry') and select the workspace you created. 

* In the 'Runs' tab you can see the status of all the runs that have been going on from you adding files into your github repo. You can go ahead and cancel runs as needed and clear the pending ones. 
* If you'd like to see the status of a run click the Current run and you'll see the output from each task/policy_check/action. 
* To start a new run manually click the 'Action' button on the top right corner of the page and select 'Start New Run' from the dropdown. 

NOTE: The status from each run will show up both in Terraform Cloud and in the Prisma Cloud Code Security Module! So both the Prisma Cloud Admin and the Admin of the terraform cloud environment can see the same information. DevSecOps. 

If you get stuck take a look at [this repo](https://github.com/kyle9021/wbc-demo), as I can confirm everything is working as expected. Hope this is helpful. Good luck. 


PS. 

Now would be a good time to destroy that text doc you've been saving notes on, because it has some pretty sensitive information on it....but you may want to save it someplace safe so you can troubleshoot if something isn't working the right way. 
