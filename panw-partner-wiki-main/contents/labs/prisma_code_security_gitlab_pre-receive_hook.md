
# Prisma Cloud Code Security: GitLab Pre-receive Hooks

Written by Teo De Las Heras

In this lab, you'll deploy a GitLab CE server and configure it with pre-receive hooks that scan for secrets.

Refs:
- [Gitlab Pre-receive Hooks](https://docs.gitlab.com/ee/administration/server_hooks.html)
- [Prisma Cloud Pre-receive Hooks](https://docs.prismacloud.io/en/enterprise-edition/content-collections/application-security/get-started/add-pre-receive-hooks)
    
## Provision and GitLab CE Instance
1. In AWS, deploy a [GitLab Community Edition](https://aws.amazon.com/marketplace/pp/prodview-w6ykryurkesjq?sr=0-3&ref_=beagle&applicationId=AWSMPContessa#pdp-pricing) instance from the marketplace
2. When prompted to Choose between Launch from Website and Launch through EC2, choose Launch through EC2
3. For the instance type, chose m4.large
4. Increase the size of storage to 20 GB
5. Click Launch Instance
6. Once the instance is deployed, browse to the public IP Address

## Configure GitLab
1. Log into the GitLab sever by browsing to the Public IP and logging in as root and using the instance-id as the password
2. Click on Create Project and Create Blank Project
3. Create a project named secret-repo
4. On the left sidebar, at the bottom, select Admin Area.
5. Select Overview > Projects and select the secret-repo project.
6. Locate the Relative path field. The value is similar to:
```
"@hashed/b1/7e/b17ef6d19c7a5b1ee83b907c595526dcb1eb06db8227d650d5dda0a9f4ce8cd9.git"
```
7. Copy this for use later

## Configure pre-receive Hooks
1. SSH into the GitLab CE Instance
2. Install python, pip, and checkov as root
```
sudo apt-get update
sudo apt-get install pip
sudo pip install checkov
```
3. Create a directory for the pre-receive hook, a file for the pre-receive hook, and copy the pre-receive hook code sample
```
mkdir custom_hooks
touch ./custom_hooks/pre-receive
chmod +x ./custom_hooks/pre-receive
```
5. Copy the code from the [Prisma Cloud pre-receive sample](https://docs.prismacloud.io/en/enterprise-edition/content-collections/application-security/get-started/add-pre-receive-hooks#pre-receive-hook-script)
6. Edit the script and provide your API Keys and Prisma Cloud URL. Update the lines in the sample code with the lines below
```
REPO_ID=$GL_PROJECT_PATH

CHECKOV_COMMAND='/usr/local/bin/checkov -d'

# cleanup
echo "GL-HOOK-ERR: Your code contains secrets. Exit code: ${exit_code}" >&2
```
8. Update the commands below with the GitLab project relative path and run the commands to register a pre-receive hook
```
tar -cf custom_hooks.tar custom_hooks
cat custom_hooks.tar | sudo /opt/gitlab/embedded/bin/gitaly hooks set --storage default --repository {gitlab-repo-relative-path} --config /var/opt/gitlab/gitaly/config.toml
```

## Test the pre-receive hook
1. In your secret-repo create a file called keys
2. Paste the code below and click on commit
```
    "AWS-AAKI": {
      "positive": {
        "aaki1": "AKIAYPDIK3OCOFEZAOQQ AWS Key",
        "aaki2": "Access Key ID 022QF06E7MXBSH9DHM02",
        "aaki3": "022QF06E7MXBSH9DHM02 Key ID",
        "aaki4": "Amazon Web Services 022QF06E7MXBSH9DHM02"
      }  
} 
```
3. You should get the error message: Your code contains secrets Exit code:1.
Note: An exit code of 127 means checkov was not found / not installed correctly.
