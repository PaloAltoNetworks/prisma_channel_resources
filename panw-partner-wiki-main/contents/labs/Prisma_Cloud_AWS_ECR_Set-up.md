Amazon Elastic Container Registry (Amazon ECR) is a managed container image registry service. Customers can use the familiar Docker CLI, or their preferred client, to push, pull, and manage images. Amazon ECR provides a secure, scalable, and reliable registry for your Docker or Open Container Initiative (OCI) images. Amazon ECR supports private repositories with resource-based permissions using IAM so that specific users or Amazon EC2 instances can access repositories and images.


_Revision 1.1_
## Purpose:

To provide entry level hands on experience working with AWS CLI and demonstrate the ability to quickly locate information using Prisma Cloud Enterprise Edition. 

## Assumptions

This isn’t being deployed to a production environment. For secure production environments please be sure to refer to: [AWS Access Key Best Practices](https://docs.aws.amazon.com/general/latest/gr/aws-access-keys-best-practices.html)  

## Prerequisites:

* AWS Account onboarded to Prisma Cloud Enterprise Edition [Instructions here](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin/connect-your-cloud-platform-to-prisma-cloud/onboard-your-aws-account/add-aws-cloud-account-to-prisma-cloud.html#id8cd84221-0914-4a29-a7db-cc4d64312e56)
* IAM Role for user: Administrator
* T2.micro - Ubuntu
* Private key file to ssh to VM
* Local Linux machine with internet connection
* API Access
    * AWS Access Key ID
    * AWS Secret Access Key
    * Instance region

## Step 1: SSH to VM you created in your AWS console (commands below steps)

* Place the private key file in a directory and cd to directory
* Run `chmod 400` on the key file! - important step:
* `chmod 400 <PRIVATE_KEY_FILE>.pem` - This ensures that the key isn't overriden accidently, but doesn't ensure no one else can read or execute it. `chmod 700 <PRIVATE_KEY_FILE>.pem` does that. 

**COMMANDS:**
```
cd <DIR_WHERE_KEY_FILE.pem EXISTS>
chmod 400 <PRIVATE_KEY_FILE>.pem
ssh -i "<PRIVATE_KEY_FILE>.pem" ubuntu@<RESOURCE>.<REGION>.compute.amazonaws.com
```
## Step 2: Configure Instance, User, and Install Docker pt. 1
* Set root password
`sudo passwd`
    * _Set this to something complex_
* Set password for default account
* Run `sudo passwd ubuntu`
    * _Set password to something strong but memorable_

* Install docker

```    
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt update
apt-cache policy docker-ce
sudo apt install docker-ce
sudo usermod -aG docker ${USER}
su - ${USER}
```

* Install, configure AWS CLI v2, and create repository

```	
sudo apt install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install -i /usr/local/aws-cli -b /usr/local/bin
aws configure
```

* You'll need to enter the AWS Access Key ID
* The AWS Secret Access Key
* And the default region of your instance
    
`aws ecr create-repository --repository-name <NAME/CONTAINER>`

* Exit Terminal Session 
	
Type `exit`

**COMMANDS:**
```
sudo passwd 
sudo passwd ubuntu
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt update
apt-cache policy docker-ce
sudo apt install docker-ce
sudo usermod -aG docker ${USER}
su - ${USER}
sudo apt install awscli
aws configure
aws ecr create-repository --repository-name <NAME/CONTAINER>
```
exit terminal session

## Step 3: Copy local dockerfiles from local machine to the AWS VM

* Type in terminal: `scp -r <PATH/TO/PROJECT/DIR/*> ubuntu@<RESOURCE>.<REGION>.compute.amazonaws.com:/home/ubuntu/`
	
    * It'll ask you for the password you created. Enter it

* SSH back into the AWS VM `ssh -i "<PRIVATE_KEY_FILE>.pem" ubuntu@<RESOURCE>.<REGION>.compute.amazonaws.com`

**COMMANDS:**

```
scp -r <PATH/TO/PROJECT/DIR/*> ubuntu@<RESOURCE>.<REGION>.compute.amazonaws.com:/home/ubuntu/
ssh -i "<PRIVATE_KEY_FILE>.pem" ubuntu@<RESOURCE>.<REGION>.compute.amazonaws.com
```

## Step 4: Build Docker Images and push them to the AWS ECR

* Cd to directory with dockerfile `cd </DIR/WITH/DOCKERFILES>`
* Build image `docker build -t <IMAGE_NAME>:<VERSION #> .`
* Tag image with AWS ECR Tag `docker tag <IMAGE_NAME>:<VERSION #> <AWS ACCOUNT #>.dkr.ecr.<REGION>.amazonaws.com<ROOT DIR/IMAGE>:<VERSION #>`
* Authenticate to AWS Repo `aws ecr get-login-password --region <REGION> | docker login --username AWS --password-stdin <AWS ACCOUNT #>.dkr.ecr.<REGION>.amazonaws.com`
* Push image to repo - `docker push <IMAGE_NAME>:<VERSION #> <AWS ACCOUNT #>.dkr.ecr.<REGION>.amazonaws.com<ROOT DIR/IMAGE>:<VERSION #>`

**COMMANDS:**

```
cd </DIR/WITH/DOCKERFILES>
docker build -t <IMAGE_NAME>:<VERSION #> .
docker tag <IMAGE_NAME>:<VERSION #> <AWS ACCOUNT #>.dkr.ecr.<REGION>.amazonaws.com<ROOT DIR/IMAGE>:<VERSION #>
aws ecr get-login-password --region <REGION> | docker login --username AWS --password-stdin <AWS ACCOUNT #>.dkr.ecr.<REGION>.amazonaws.com
docker push <AWS ACCOUNT #>.dkr.ecr.<REGION>.amazonaws.com<ROOT DIR/IMAGE>:<VERSION #>
```

## Step 5 - Find your container images stored in the AWS ECR using Prisma Cloud Enterprise Edition

* Login to the Prisma Cloud Enterprise edition console
* Go to the Investigate tab located on the right hand side. 
* Enter `config from cloud.resource where api.name = 'aws-ecr-get-repository-policy'` as your RQL query
