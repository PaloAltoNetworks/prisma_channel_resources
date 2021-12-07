# Docker Compose Prisma Cloud Compute Ecosystem Deployment

After manually deploying everything in the last tutorial. It's only natural to want to automate a lot of the configuration steps. Below you'll find an easy way to replicate the necessary apps to complete a prisma cloud compute demo lab. I'd encourage you to do it the imperative way first so you understand how things are put together, but if you're in a rush to stand-up a local Prisma Cloud Compute lab then this may be the best tutorial for you.  

Keep in mind, deploying things declaratively has it's disadvantages, primarily from the learning/understanding angle. 

## Assumptions

You understand that this is not a production ready deployment of Prisma Cloud Compute or any other tool in the lab. This is meant to be a local deployment on a virtualization platform like VirtualBox or VMWare Fustion/Workstation for testing and learning purposes.  

## Requirements

Ubuntu 20.04 LTS Desktop VM

```bash
100 GB HD
8 GB RAM
6 processors
```
User with root permissions

## Set-up Instructions

### Step 0: update and upgrade, set the account password, and root password

Set the root password
```bash
sudo passwd root
```
Sets the account password
```bash
sudo passwd $USER
```

Update and upgrade
```bash
sudo apt-get update
sudo apt-get upgrade
```
<br />

### Step 1: Install Git, Docker, and Docker Compose

Install [Docker](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04)

```bash
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common git jq
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt update
apt-cache policy docker-ce
sudo apt install docker-ce
sudo usermod -aG docker ${USER}
su - ${USER}
```

Install [Docker-Compose](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-20-04)

```bash
sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```
<br />

### Step 2: Download and deploy Prisma Cloud Compute Console and a container defender

```bash
cd $HOME
mkdir prisma_compute_deploy
wget https://cdn.twistlock.com/releases/TK751Bfc/prisma_cloud_compute_edition_21_08_525.tar.gz
tar -xvzf prisma_cloud_compute_edition_21_08_525.tar.gz -C $HOME/prisma_compute_deploy/
sudo cp $HOME/prisma_compute_deploy/linux/twistcli /usr/local/bin/
sudo $HOME/prisma_compute_deploy/twistlock.sh -s onebox
```

We'll configure the console later
<br />

### Step 3: Download the lab deployment files

```bash
cd $HOME
git clone https://github.com/paloaltonetworks/prisma_partner_resources
cd prisma_partner_resources/lab_deploy/compose_deploy/
```
<br />

### Step 4: Configure the deployment

```bash 
nano .secrets
```

At this stage you'll need to assign values to the following variables, I've written comments in the `.secrets` file to act as documentation. The only variables you'll need to assign for this lab are the following. NOTE: The last two variables are assigned at a later stage. Leave them empty for now. 

```bash
# Shared secret between drone runner and drone server - should be a password with reasonable complexity
DRONE_RPC_SECRET=""

# Your choice for this part
DRONE_UI_USERNAME=""
DRONE_UI_PASSWORD=""

# Vault root token - should be a password with reasonable complexity
VAULT_ROOT_TOKEN=""

# DON'T ASSIGN THESE VARIABLES TO ANYTHING YET.....
DRONE_GITEA_CLIENT_ID=""
DRONE_GITEA_CLIENT_SECRET=""
```

Once you finished assigning values to the variables (if using nano as your editor) hit `ctl + x`, `y`, then `enter` 
<br />

### Step 5: Modify your hosts file

```bash
sudo nano /etc/hosts/
```

* Add `gitea drone swagger` next to your local IP address `127.0.0.1`
* Add `prisma-compute-lab` next to your other local IP address `127.0.1.1`

* Your hosts file should look like the below code block once you've finished

```bash
127.0.0.1       localhost gitea drone swagger
127.0.1.1       prisma-compute-lab

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```

* Once you finished modifying your hosts file (if using nano as your editor) hit `ctl + x`, `y`, then `enter`
<br />

### Step 6: Deploy the ecosystem lab

* You should still be in the lab deployment folder. `$HOME/prisma_partner_resources/lab_deploy/compose_deploy/` if you're not `cd $HOME/prisma_partner_resources/lab_deploy/compose_deploy/`

* Once you're in the deployment folder, we'll temporarily deploy gitea and it's database to generate an Oauth token. After running the below command keep terminal open and allow everything to run. 

```bash
docker-compose --env-file .secrets -p gitea-drone up gitea gitea-db
```
After running the above command open firefox and navigate to `http://gitea:3000` to finish the installation and register a user. 
* go ahead and click install at the bottom of the gitea page. All the settings have been preconfigured for you. 
* after it is initialized refresh the page a few times until you get to the gitea page. 
* Click the `register` button and create a new user (a fake email is fine) and a password. 
* Create an OAuth application as described here: `https://docs.drone.io/installation/providers/gitea/`
* In Gitea, give the application a name: `drone` and set the redirect to `http://drone:8000/login`
* Click save once you've finished. 

Now you'll deploy the rest of the services. In your terminal session stop docker compose by hitting `ctrl + c` on your keyboard. 
Wait for the services to stop, then run:
* `docker-compose --env-file .secrets -p gitea-drone up -d`
* This above command will start everything in detached mode so you won't see any logging. 
* Navigate to gitea in your firefox browser and create a new repository named `ci-vuln-scan`. Select a license and check add a READ_ME.md file. 
* Then navigate to `http://drone:8000` to finish the connection. 
* It'll have you authorize the OAuth app you created in Gitea
* After authorizing the OAuth app, activate the `ci-vuln-scan` repository in drone. Set the pipeline to trusted. 
* Then hit save. We'll come back after the next step to finish the configuration
<br />

### Step 7: Wrap up the Prisma Cloud Compute edition deployment

* In firefox navigate to `https://prisma-compute-lab:8083` and create the admin user and password.
* Sign in and input your license information. 
* Open terminal and run `docker network connect compose_deploy_default twistlock`
* Then run `docker network inspect compose_deploy_default | grep -A 3 "twistlock_console"`
* Copy the IP Address without the CIDR range that is assigned to the Prisma Cloud Console. 
* Sign in to the Prisma Cloud Console and go to `Manage > Defenders` 
* On the defenders page click the `Names` tab in the top middle of the page and add the IP address you copied down to the SAN list. 
* Click accept the risk and continue (by default Prisma Cloud Compute deploys with a self-signed cert)
* Go to the `Defend` tab in the side bar under the `Radar` tab in the left hand side menu
* In the middle top of the screen click the `Images` tab. Click the `+Add rule` button and create a rule called `Default`, don't change any of the default settings and click the `Save Button`
* Then go to the middle top of the page and click the `Hosts` tab and repeat the same process of creating a default host rule. In the middle top of the screen click the `Images` tab. Click the `+Add rule` button and create a rule called `Default`, don't change any of the default settings and click the `Save Button`
<br />

### Step 8: Finish setting up your drone sever and gitea repo

Navigate back to drone in firefox at http://drone:8000
* Click the `ci-vuln-scan` repository in drone and then click the `settings` tab. 
* Ensure the pipeline is set to trusted under Project settings, then click the `Secrets` tab on the left hand side menu. 
* On the secrets page click the `+ New Secret` button and we'll create three secrets. 
* The first secret you create should be named `pcc_password`; for the value we'll use the password you created in your Prisma Cloud Console. 
* The second secret you will create should be named `pcc_user`; for the value use the username you created in the Prisma Cloud Console.
* The third secret we'll create will be named `pcc_console_ip`; for the value we'll use the IP address we added to the SAN list in the Prisma Cloud Console
* Once the secrets have been added to the repo, navigate to Gitea at `http://gitea:3000`. 
* Sign in and go to your `ci-vuln-scan repo`
* Add two more files to your repo. 
* The first file will be a file named `Dockerfile` (note the capital D in Dockerfile). 
* In the `Dockerfile` you only need to type one line: `FROM python:latest`. After that's typed in go ahead and commit the file. 
* The second file you'll add to this repo we'll name `.drone.yml`. 
* In the `.drone.yml` file copy and paste the below code block:

```yaml
---
kind: pipeline
name: my secure CI pipeline

steps:
- name: build
  image: docker:dind
  environment:
    PCC_USER:
      from_secret: pcc_user
    PCC_PASSWORD:
      from_secret: pcc_password
    PCC_CONSOLE_IP:
      from_secret: pcc_console_ip
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 7 # give docker enough time to start
  - docker build -t my_questionable_container:1 .

- name: vuln scan
  image: docker:dind
  environment:
    PCC_USER:
      from_secret: pcc_user
    PCC_PASSWORD:
      from_secret: pcc_password
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - apk add curl
  - |
    curl -k --header "Authorization: Basic $(echo -n $PCC_USER:$PCC_PASSWORD | base64 | tr -d '\n')" https://$PCC_CONSOLE_IP:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
  - |
    ./twistcli images scan --address https://$PCC_CONSOLE_IP:8083 -u $PCC_USER -p $PCC_PASSWORD --details my_questionable_container:1 .

services:
- name: docker
  image: docker:dind
  privileged: true
  volumes:
  - name: dockersock
    path: /var/run
volumes:
- name: dockersock
  temp: {}
```

Once you commit the file to the repo you'll it'll start a build of the container on the drone runner. The full tutorial on how to create a CI pipeline for container scanning can be found [here](https://github.com/PaloAltoNetworks/prisma_channel_resources/blob/main/lab_deploy/ci_vulnerability_lab_guide.md)

Enjoy!

