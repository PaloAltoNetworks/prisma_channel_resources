# Compute Demo Lab Set-up Full

I wrote a tutorial on how to deploy prisma cloud compute on minikube when I first started at Palo Alto Networks. There was some things I wasn't in love with, but I needed something I could point to quickly. This tutorial solves a lot of the issues I had before such as: handling persistent states across reboots, simplifying the console deployment, and other things. I wrote this one June 21st 2021, and as it stands today, there's still a few things I'd like to improve on with further iterations, however this is in a state now where everything is working, so I'll post the instructions below for those who'd like to set up a better Prisma Compute Demo Environment along with the complimentary tools such as: Jenkins, DVWA, Sock-shop, and Gogs. 

## Assumptions

You understand that this is not a production ready server. It should not be able to be accessed remotely from outside your organization's internal network. This is meant to be run from a single server to showcase the capabilities of Prisma Cloud Compute. 

## Requirements

Ubuntu 20.04 LTS Desktop VM - to build out more I'd recommend increasing the specs. 

```bash
Ubuntu - Desktop
100 GB HD
8 GB RAM
6 processors
```
* User with root permissions

## Set-up Instructions

### Step 0: update and upgrade, set the account password, and root password

Set the root password
```bash
sudo passwd
```
Sets the account password
```bash
passwd
```

Update and upgrade
```bash
sudo apt-get update
sudo apt-get upgrade
```

### Step 1: Install docker, k3s, kubectl, and jenkins

```bash
# Installs Docker
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt-get update -y
sudo apt-cache policy docker-ce
sudo apt-get install -y docker-ce
sudo usermod -aG docker $USER

# Installs k3s - a lightweight version of kuberenetes
curl -sfL https://get.k3s.io | sh -s - --docker

# Installs and configures kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Configures k3s to work with kubectl
mkdir $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chmod +rwx $HOME/.kube/config
echo "export KUBE_CONFIG=~/.kube/config" >> .bashrc

# Install Jenkins NOTE: NOT PRODUCTION SAFE!
sudo apt-get update
sudo apt upgrade
sudo apt install default-jdk
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update
sudo apt install jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins
sudo usermod -aG docker jenkins
sudo chmod 777 /var/run/docker.sock #not good security practice - Would love the commmunity to edit this line - KB
```

### Step 2: Set-up Gogs (code repo), dvwa, and deploy sock-shop k8s microservices demo

```bash
docker pull vulnerables/web-dvwa:lastest
docker pull mysql:latest
docker pull gogs/gogs:latest

# deploy sock-shop

git clone https://github.com/microservices-demo/microservices-demo
kubectl apply -f $HOME/microservices-demo/deploy/kubernetes/complete-demo.yaml
```

### Step 3: Deploy Prisma Cloud Compute in Onebox mode

```bash
mkdir $HOME/prisma_compute_deploy/
wget https://cdn.twistlock.com/releases/v3cabvvk/prisma_cloud_compute_edition_21_04_421.tar.gz
tar xvzf prisma_cloud_compute_edition_21_04_421.tar.gz -C $HOME/prisma_compute_deploy/
sudo cp $HOME/prisma_compute_deploy/linux/twistcli /usr/bin/
sudo $HOME/prisma_compute_deploy/twistlock.sh -s onebox
```

### Step 4: Create Docker Networks

```bash
docker network create --driver bridge app-net
```

### Step 5: Deploy the DVWA

```bash
docker run -dit -p 4505:80 --network app-net --name dvwa vulnerables/web-dvwa:latest
```

### Step 6: Recommending that you take a snapshot here before we begin any configuration so you can roll it back if you make a mistake. 

* Edit the hosts file so your build lab appears a bit more legit:

```bash 
sudo nano /etc/hosts
```

Add a line and create an entry with a name of your choosing for the IP Address 127.0.1.1. Once you're happy hit ctrl + x then y on your keyboard. Example hosts file below:

```bash
127.0.0.1       localhost
127.0.1.1       <DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>
# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```

### Step 7: Configure Gogs, mysql, and deploy

Start up the mysql server container and ensure you've replaced <PASSWORD> with a password of your choosing we're going to name it gogs-mysql. Write the password you assigned to the the SQL Server Container down as SQL_SERVER_ROOT_PASSWORD, we'll refer to it later. The first command deploys the container and starts the configuration. We'll use the next commands to ensure everything is running and finally pull the IP Address assigned to the container.

```bash
docker run --name gogs-mysql  -e MYSQL_ROOT_PASSWORD=<PASSWORD> -d mysql:latest
docker logs gogs-mysql
docker inspect gogs-mysql | grep IPAddress
```

You should now have the IP Address assigned to the mysql container. Write that down somewhere as gogs-mysql-IPAddress; I'll refer to this again in a moment

Now we'll need to create the gogs mysql database within the container. To start a shell inside the container run:

```bash
docker run -it --link gogs-mysql:mysql --rm mysql sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p"$MYSQL_ENV_MYSQL_ROOT_PASSWORD"'
```

Once inside the container run the following commands:

```bash
create database gogs;
show databases;
exit
```

Now we'll deploy gogs, again we'll need to get the IPAddress of the gogs container on the overlay network.

```bash
docker run -d --name=gogs -p 1022:22 -p 1080:3000 -v $HOME/gogs_mount/var/gogs:/data gogs/gogs:latest
docker inspect gogs | grep IPAddress
```

Write the gogs container IP address down as GOGS_CONTAINER_IP. We'll use this information when we configure the application.
Now, you should be able to access the gogs repo application at

```bash
http://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:1080/install
```

Fill in the fields with the following configuration

```bash
Database type: MySQL
Host: <gogs-mysql-IPAddress> ---what you wrote down when you deployed and created the mysql container
User: root
Password: <SQL_SERVER_ROOT_PASSWORD> --- the password you created when you first deployed the SQL Server container
Database Name: gogs
Application Name: <Whatever_you_want>
Repository Root Path: LEAVE DEFAULT
Run User: git
Domain: <GOGS_CONTAINER_IP>
SSH Port: 1022
HTTP Port 3000
Application URL: http://<GOGS_CONTAINER_IP>
Log Path: Leave Default
```

Hit save and you should be able to access your configured Gogs Repo at

```bash
http://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:1080
```

Finish setting up the username and create a repo if you'd like. Full documentaiton for gogs can be found here:

```bash
https://gogs.io/
```

### Step 8: Configure Prisma Cloud Compute and deploy container defender

Go to: 

```bash
https://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:8083
```

and create your admin username and password. Write the username and password down as PRISMA_USER & PRISMA_PASSWORD; we'll use it later when we configure jenkins. After that it'll ask you to input your license. Input the license and click save. 

Now that you're logged in as the admin:

* Go to Manage > Defenders - there will be a notification that appears that you need to click to add the url to the SAN. Once you click add refresh the page. 
* Go to Defenders > Deploy and configure the following: 

```bash
Deployment Method: Single Defender
Name Defender will use to connect to the console: http://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>
Proxy: leave default
Comm Port: leave default
Defender Type: Container Defender Linux
Defender Listener Type: leave default
```

Copy the script in section 7 and paste it into your terminal session. Confirm that defender is checking in properly by going to Manage > Defenders > Manage Tab. 

* You should now also be able to see the containers from sock-shop on the Radars > Container screen. 


### Step 9: Configure Jenkins

To access your jenkins instance you'll first need to get the intitial password by entering in your terminal session:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Write this password/token down as JENKINS_TOKEN. We'll use that in a moment. 

Your jenkins page should be able to be accessed at:

```bash
http://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:8080
```

Copy the URL to your browser and input your <JENKINS_TOKEN> you wrote down a moment ago. 

Go with the default set-up and install the recommended plugins. 

Once that's complete you'll set-up the admin user and password. I'll leave that up to you. 

* In Jenkins go to Dashboard
* Click the gear icon "Manage Jenkins"
* Hit the puzzle piece icon and go to "Manage Plugins"
* Click the "Available" tab and in the filter search bar type: Docker
* Check the box for the following plugins:
- Docker API Plugin
- Docker Commons Plugin
- Docker Pipeline
- Docker Plugin
* Then at the bottom of the page click the button "Install without restart"
* Next, click the "Advanced tab"
* Scroll down to the second section, Upload Plugin, and click "Choose File"
* Browse to your Home Directory and open the prisma_deployment directory
* Select the prisma-cloud-jenkins-plugin.hpi file and upload it. 
* Check the box that says Restart Jenkins when installation is complete and no jobs are running. 
* Wait for a minute or so. Then reload the page and sign back in. 
* Click the gear icon in the left hand menu "Manage Jenkins" and then select the gear icon "Configure System"
* Scroll down the page until you see Prisma Cloud.
* Fill the following fields:

```bash
address: https://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:8083
user: <PRISMA_USER> ---you wrote this down earlier
password: <PRISMA_PASSWORD> ---you wrote this down earlier
```

* Click the botton "Test connection" and you should see an OK appear. Once it days click the "Apply" button (NOT THE SAVE BUTTON)
* Scroll to the bottom of the page and click the link that says "The cloud configuration has moved to a seperate configuration page"
* Click the drop down "Add a new cloud" and select docker
* Fill out the following fields:

```bash
Name: docker
Docker Host URI: unix:///var/run/docker.sock
```

* Click the "Test Connection" button and you should see the docker version and api version appear. 
* Now click save
* In the lefthand menu on the screen click the box icon "New Item"
* On the new item page give your pipeline a name and then select the pipe icon "pipeline"
* On this page click the "Pipeline" tab (or scroll to the bottom of the page). Paste in the code block below. (copy this code exactly)


```bash
node {
    stage('createImage') {
        sh 'echo "Creating Dockerfile..."'
        sh 'echo "FROM ubuntu:bionic" > Dockerfile'
        sh 'echo "ENV MYSQL_HOST=DB_Server" >> Dockerfile'
        sh 'echo "ENV MYSQL_PASSWORD=5TTnvuTDJJSq6" >> Dockerfile'
        sh 'echo "LABEL description=Test_Twistlock_Jenkins_Plugin" >> Dockerfile'
        sh 'docker build --no-cache -t dev/my-ubuntu:$BUILD_NUMBER .'
    }
    stage('twistlockScan') {
        prismaCloudScanImage ca: '', cert: '', dockerAddress: 'unix:///var/run/docker.sock', image: 'dev/my-ubuntu:$BUILD_NUMBER', key: '', logLevel: 'info', podmanPath: '', project: '', resultsFile: 'prisma-cloud-scan-results.json', ignoreImageBuildTime:true
    }
    stage('twistlockPublish') {
        prismaCloudPublish resultsFilePattern: 'prisma-cloud-scan-results.json'
    }
}
```

* Then click the "Save" button. 
* Finally click the clock icon in the left-hand menu "Build Now"
* A number #1 should appear on the left hand menu and you should be able to watch the build complete. 
* Click the #1 link under "Build History" after the build completes and you should be able to see the results from the scan. 
* click the link that says "View these results in the Prisma Cloud Console"'

### Step 10: Make the docker containers persist across reboots:

```bash
docker update --restart=always dvwa
docker update --restart=always gogs-mysql
docker update --restart=always gogs
```


### Step 11: Look at the other demo tutorials/documenation for more ideas. I'll update this tutorial after I've had a few people run through it. 

Summary: You have a working demo lab which has a persistent state across reboots. I'd recommend taking another snapshot if you have the space. 

You can access the following resources:

* http://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:8080 - Jenkins
* https://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:8083 - Prisma Cloud Compute Console
* https://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:8084 - Prisma Cloud Compute API
* http://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:1080 - Self Hosted Gogs Repository
* http://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:4505 - DVWA

Sock-shop can be accessed by going into your terminal and typing 

```bash
kubectl get services front-end -n sock-shop
```

look for the port mapping over port 80:<write_this_port_down>

in a browser go to:

```bash
http://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:<port_you_just_wrote_down>
```

### Step 12: Deploy Hashicorp Vault
Ensure you're on the HOME directory for your user:
`cd $HOME`

Install vault locally:
```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault
```

Pull the latest version of vault
`docker pull vault`

Start the vault container in Dev mode and assign the root token. (not for production)
`docker run -dit --cap-add=IPC_LOCK -p 7880:7880 -e 'VAULT_DEV_ROOT_TOKEN_ID=<YOUR_ROOT_TOKEN_VALUE_CUSTOMIZABLE>' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:7880' --name vault --network dev-net vault` 

Export the env vars to the bashrc profile
`echo "export VAULT_TOKEN='<YOUR_ROOT_TOKEN_VALUE_CUSTOMIZABLE>'" >> .bashrc`
`echo "export VAULT_ADDR='http://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:7880'" >> .bashrc`

Ensure you have exported them in your current session
`source .bashrc`

Check to ensure you can access the vault server
`vault status`

Update container so it restarts if there's any issues. 
`docker update --restart=always vault` - forgot to put this in the docker run command

link to vault documentation to get you started: [Vault Documentation](https://learn.hashicorp.com/vault)

### Step 13: Deploy Swagger Petstore Demo API

Run the Swagger Petstore container
`docker run -dit --name swagger_api -e SWAGGER_HOST=http://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:8082 -e SWAGGER_URL=http://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:8082  -e SWAGGER_BASE_PATH=/myapi -p 8082:8080 swaggerapi/petstore`

Update container so it restarts if there's any issues
`docker update --restart=always swagger_api` - forgot to put this in the docker run command


### Reference Links:

* [k3s hardening guidelines](https://rancher.com/docs/k3s/latest/en/security/hardening_guide/) - your deployment is insecure by design. If you'd like to look into how to secure things. 

