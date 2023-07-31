# Docker Compose Prisma Cloud Compute Ecosystem Deployment
Written by Kyle Butler in collaboration with Sean Sullivan

After imperetively deploying everything in the earlier tutorials I wrote. It's only natural to want to automate a lot of the configuration steps. Below you'll find an easy way to replicate the necessary apps to complete a prisma cloud compute demo lab. I'd encourage you to do it the imperative way first so you understand how things are put together, but if you're in a rush to stand-up a local Prisma Cloud Compute lab then this may be the best tutorial for you.  

Keep in mind, deploying things declaratively has it's disadvantages, primarily from the learning/understanding angle. 

## Assumptions

You understand that this is not a production ready deployment of Prisma Cloud Compute or any other tool in the lab. This is meant to be a local deployment on a virtualization platform like VirtualBox or VMWare Fusion/Workstation for testing and learning purposes.  

### Security Suggestions

* check the container images referenced in the docker-compose.yml prior to deployment using twistcli. See the [bash toolbox for some scripts](https://github.com/PaloAltoNetworks/prisma_channel_resources/tree/main/prisma_bash_toolbox-main)
* enable the ufw on the vm after deployment. Instructions [here](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-with-ufw-on-ubuntu-20-04)

## Requirements

Ubuntu 22.04 LTS Desktop VM

Suggested hardware specs
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
Sets the proper permissions on the $USER . files
```bash
chmod 700 $HOME/.*
```
Sets the proper permissions on the $USER $HOME directory
```bash
chmod 750 $HOME
```
Ensure permissions on bootloader config are configured
```bash
sudo chown root:root /boot/grub/grub.cfg
sudo chmod og-rwx /boot/grub/grub.cfg
```
Disable CUPS ---unlesss for some reason you need to print to local and/or network printers from this vm. 
```bash
sudo systemctl stop cups
sudo systemctl stop cups-browsed
sudo systemctl disable cups
sudo systemctl disable cups-browsed
```

Update and upgrade
```bash
sudo apt-get update
sudo apt-get upgrade
```
<br />

### Step 1: Install Git, Docker, and Docker Compose

Install [Docker](https://docs.docker.com/engine/install/ubuntu/)

```bash
sudo apt-get update
sudo apt install ca-certificates curl git jq gnupg vim zsh tmux shellcheck htop
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
su $USER
```


### Step 2: Download and deploy Prisma Cloud Compute Console and a container defender

```bash
cd $HOME
mkdir prisma_compute_deploy
wget https://cdn.twistlock.com/releases/RfwoeSCG/prisma_cloud_compute_edition_30_03_122.tar.gz
tar -xvzf prisma_cloud_compute_edition_30_03_122.tar.gz -C $HOME/prisma_compute_deploy/
sudo cp $HOME/prisma_compute_deploy/linux/twistcli /usr/local/bin/
sudo $HOME/prisma_compute_deploy/twistlock.sh -s onebox
```

We'll configure the console later
<br />

### Step 3: Download the lab deployment files

```bash
cd $HOME
git clone https://github.com/PaloAltoNetworks/prisma_channel_resources
cd prisma_channel_resources/lab_deploy/compose_deploy/
```
<br />

### Step 4: Configure the deployment

```bash 
nano .secrets
```

At this stage you'll need to assign values to the following variables, I've written comments in the `.secrets` file to act as documentation. The only variables you'll need to assign for this lab are in the code block below. NOTE: The last two variables are assigned at a later stage. Leave them empty for now. 

* You'll need to generate two different api tokens to authenticate the `/metrics api` endpoint to prometheus.
* Use the command `openssl rand -hex 16` and assign the value it outputs to DRONE_METRICS_API_TOKEN
* Run the command again `openssl rand -hex 16` and assign the value it outputs to the GITEA_METRICS_API_TOKEN

```bash
# Shared secret between drone runner and drone server - should be a password with reasonable complexity
DRONE_RPC_SECRET=""

# Your choice for this part
DRONE_UI_USERNAME=""
DRONE_UI_PASSWORD=""

# Generate using the command: openssl rand -hex 16
# Copy the value into this file and the prometheus.yml file 
DRONE_METRICS_API_TOKEN=""

# Generate using the command: openssl rand -hex 16
# Copy the value into this file and the prometheus.yml file
GITEA_METRICS_API_TOKEN=""

# Vault root token - should be a password with reasonable complexity
VAULT_ROOT_TOKEN=""

# Splunk Password
SPLUNK_PASSWORD=""


# DON'T ASSIGN THESE VARIABLES UNTIL AFTER DEPLOYING GITEA and GITEA-DB
DRONE_GITEA_CLIENT_ID=""
DRONE_GITEA_CLIENT_SECRET=""
```

Once you finished assigning values to the variables (if using nano as your editor) hit `ctl + x`, `y`, then `enter` 
<br />

* Huge shoutout to Sean Sullivan for his assistance on the Prometheus Grafana Deployment. See his repo [PaloAltoNetworks/pcs-metrics-monitoring](https://github.com/PaloAltoNetworks/pcs-metrics-monitoring)

Then edit the file in `./volumes/prometheus/` called `prometheus.yml`. First, `cd ./volumes/prometheus/`


```bash
nano ./prometheus.yml
```
In this file you'll need to replace the values in the `<>` angle brackets.
* For `<PRISMA_USER>` replace this with the username you want to use to sign into the console. (In a real deployment this would be user with the Auditor permissions)
* For `<PRISMA_PASSWORD>` replace this with the password you'll use to sign into the console. (In a real deployment you might use an auth token associated with the User mentioned above)
* For `<DRONE_METRICS_API_TOKEN>` use the same value you assigned to the `DRONE_METRICS_API_TOKEN` in your `.secrets` file.
* For `<GITEA_METRICS_API_TOKEN>` use the same value you assigned to the `GITEA_METRICS_API_TOKEN` in your `.secrets` file. 

The below code block shows what the file looks like:

```bash
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.

# Prisma Cloud scrape configuration.
scrape_configs:

  - job_name: 'twistlock'
    static_configs:
    - targets: ['twistlock_console:8083']
    metrics_path: /api/v1/metrics
    basic_auth:
      username: '<USERNAME_OR_ACCESSKEY>'
      password: '<PASSWORD_OR_SECRETKEY>'
    scheme: https
    tls_config:
      insecure_skip_verify: true

  - job_name: 'drone'
    bearer_token: <DRONE_METRICS_API_TOKEN>
    static_configs:
    - targets: ['drone:8000']
    
  - job_name: 'gitea'
    bearer_token: <GITEA_METRICS_API_TOKEN>
    static_configs:
    - targets: ['gitea:3000']

# NO need to edit below this line 

# Grafana monitoring
- job_name: grafana
  metrics_path: /metrics
  scheme: http
  static_configs:
  - targets:
    - grafana:3001

# Prometheus self-monitoring
- job_name: prometheus
  honor_timestamps: true
  metrics_path: /metrics
  scheme: http
  follow_redirects: true
  enable_http2: true
  static_configs:
  - targets:
    - localhost:9090
 ```

Once you finished assigning values to the variables (if using nano as your editor) hit `ctl + x`, `y`, then `enter` 
<br />

### Step 5: Modify your hosts file

```bash
sudo nano /etc/hosts
```

* Add `gitea drone swagger prometheus grafana vault dvwa` next to your local IP address `127.0.0.1`
* Add `prisma-compute-lab` next to your other local IP address `127.0.1.1`

* Your hosts file should look like the below code block once you've finished

```bash
127.0.0.1       localhost gitea drone swagger prometheus grafana vault dvwa
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

* You should still be in the lab deployment folder. `$HOME/prisma_channel_resources/lab_deploy/compose_deploy/` if you're not `cd $HOME/prisma_channel_resources/lab_deploy/compose_deploy/`

* Once you're in the deployment folder, we'll temporarily deploy gitea and it's database to generate an Oauth token. After running the below command keep terminal open and allow everything to run. 

```bash
docker compose --env-file .secrets -p gitea-drone up gitea gitea-db
```
After running the above command open firefox and navigate to `http://gitea:3000` to finish the installation and register a user. 
* go ahead and click install at the bottom of the gitea page. All the settings have been preconfigured for you. 
* after it is initialized refresh the page a few times until you get to the gitea page. 
* Click the `register` button and create a new user (a fake email is fine) and a password. 
* Create an OAuth application as described here: `https://docs.drone.io/installation/providers/gitea/`
* In Gitea, give the application a name: `drone` and set the redirect to `http://drone:8000/login`
* Click save once you've finished. 

Now you'll deploy the rest of the services. In your terminal session stop docker compose by hitting `ctrl + c` on your keyboard. 
Wait for the services to stop, then:
* edit the `.secrets` file again using the command `nano ./secrets` and fill in the last two variables under the basic configuration options: `DRONE_GITEA_CLIENT_ID` and `DRONE_GITEA_CLIENT_SECRET`. You'll use the Client ID & Client Secret you generated in Gitea. 
* `docker compose --env-file .secrets -p gitea-drone up -d`
* This above command will start everything in detached mode so you won't see any logging. 
* set the permissions on the container storage volumes by entering the commands below:

```bash
sudo chown -R 1000:1000 ./volumes/prometheus/
sudo chmod -R u+rwx ./volumes/prometheus/
sudo chown -R 1000:1000 ./volumes/prometheus-storage/
sudo chmod -R u+rwx ./volumes/prometheus-storage/
sudo chown -R 1000:1000 ./volumes/grafana/
sudo chmod -R u+rwx ./volumes/grafana/
sudo chown -R 1000:1000 ./volumes/grafana-storage/
sudo chmod -R u+rwx ./volumes/grafana-storage/
```
* Navigate to gitea in your firefox browser and create a new repository named `ci-vuln-scan`. Select a license and check add a READ_ME.md file. 
* Then navigate to `http://drone:8000` to finish the connection. 
* It'll have you authorize the OAuth app you created in Gitea
* After authorizing the OAuth app, activate the `ci-vuln-scan` repository in drone. Set the pipeline to trusted. 
* Then hit save. We'll come back after the next step to finish the configuration
<br />

### Step 7: Wrap up the Prisma Cloud Compute edition deployment

* In firefox navigate to `https://prisma-compute-lab:8083` and create the admin user and password.
* Sign in and input your license information. 
* Open terminal and run `docker network connect gitea-drone_default twistlock_console`
* In prisma cloud compute.
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
* The third secret we'll create will be named `pcc_console`; for the value we'll use the name `twistlock_console` 
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
    PCC_CONSOLE:
      from_secret: pcc_console
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 10 # give docker enough time to start
  - docker build -t my_questionable_container:1 .

- name: vuln scan
  image: docker:dind
  environment:
    PCC_USER:
      from_secret: pcc_user
    PCC_PASSWORD:
      from_secret: pcc_password
    PCC_CONSOLE:
      from_secret: pcc_console
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - apk add curl
  - |
    curl -k --header "Authorization: Basic $(echo -n $PCC_USER:$PCC_PASSWORD | base64 | tr -d '\n')" https://$PCC_CONSOLE:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
  - |
    ./twistcli images scan --address https://$PCC_CONSOLE:8083 -u $PCC_USER -p $PCC_PASSWORD --details my_questionable_container:1 .

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

Once you commit the file to the repo you'll it'll start a build of the container on the drone runner. The full tutorial on how to create a CI pipeline for container scanning using Drone go is located -> [here](https://github.com/PaloAltoNetworks/prisma_channel_resources/blob/main/lab_deploy/ci_vulnerability_lab_guide.md). 

If you'd like to work on creating a ci pipeline to scan IAC templates, k8s manifests, helm charts, and/or Dockerfiles; see the tutorial for that lab -> [here](https://github.com/PaloAltoNetworks/prisma_channel_resources/blob/main/panw-partner-wiki-main/contents/labs/prisma_code_security_on_prem_vcs_ci_pipeline.md).

And if your organization happens to have a self-hosted production deployment of GitLab, and want to get into some more advanced stuff. You might check out this page (FYI, this will require a real deployment of GitLab) [Prisma Cloud Compute Container Scanning using Kaniko and GitLab](https://github.com/PaloAltoNetworks/prisma_channel_resources/blob/main/panw-partner-wiki-main/contents/labs/prisma_cloud_compute_gitlab_self_hosted_kaniko_rootless_container_building.md)

### Step 9: Add configure git, ssh, and ssh config files

* Create a ssh-key `ssh-keygen -t ed25519 -C "your_email@example.com"` 
* Create the ssh config file `nano $HOME/.ssh/config`
* Copy and paste the below into the file:

```
Host gitea
  port 4070
```

* Configure git user name: `git config --global user.name $(whoami)`
* Configure git user email: `git config --global user.email "<YOUR_USER_EMAIL>"`
* Now you can add your ssh key to gitea by opening your web browser and navigating to `gitea:3000` 
* Log-in and then click the top right profile and settings button in gitea. 
* From the drop-down click settings 
* Then click the SSH/GPG keys tab. 
* cat your PUBLIC ssh file in your terminal `cat $HOME/.ssh/id_ed25519.pub` 
* copy and paste the output into the ssh key section and hit save!


### Step 10: Integrate prometheus with Prisma Cloud Compute, Drone, and Gitea. 

Now it's time to start getting metrics from the Prometheus Integration for Prisma Cloud Compute and begin to combine those metrics with metrics from other systems and servers!
WIP -  https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/audit/prometheus.html - official documentation as a placeholder
