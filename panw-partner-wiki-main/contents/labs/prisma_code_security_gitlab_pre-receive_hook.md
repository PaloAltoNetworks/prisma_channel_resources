
# Prisma Cloud Code Security: GitLab Pre-receive Hooks

Written by Teo De Las Heras

In this lab, you'll deploy a GitLab CE server and configure it with pre-receive hooks that scan for secrets.

Refs:
- [Gitlab Pre-receive Hooks](https://docs.gitlab.com/ee/administration/server_hooks.html)
- [Prisma Cloud Pre-receive Hooks](https://docs.prismacloud.io/en/enterprise-edition/content-collections/application-security/get-started/add-pre-receive-hooks)
    
## Provision and GitLab CE Instance
1. In AWS, deploy a [GitLab Community Edition](https://aws.amazon.com/marketplace/pp/prodview-w6ykryurkesjq?sr=0-3&ref_=beagle&applicationId=AWSMPContessa#pdp-pricing) instance from the marketplace
2. When prompted to Choose between Launch from Website and Launch through EC2, choose Launch through EC2
3. For the instance type, chose m3.medium
4. Increase the size of storage to 20 GB
5. Click Launch Instance
6. Once the instance is deployed, copy the public IP Address
7. SSH into the GitLab Instance
8. Update the commands below and then paste them into the GitLab shell session

```
$ENDPOINT={GitLab_EC2_PUBLIC_IP}
sudo sed -i \"s,external_url 'http://gitlab.example.com',external_url 'http://$ENDPOINT',g\" /etc/gitlab/gitlab.rb
sudo gitlab-ctl reconfigure
sudo cat /etc/gitlab/initial_root_password
```
9. Copy GitLabs root password

## Configure GitLab
1. Log into the GitLab sever by browsing to the Public IP and logging in as root using the password from the previous step
2. Click to create a new Repo
3. 


## Configure pre-receive Hooks
1. SSH into the GitLab CE Instance
2. Install python, pip, and checkov as root
```
sudo apt-get install pip
sudo pip install checkov
```
3. Create a directory for the pre-receive hook and copy the pre-receive hook
4. 

