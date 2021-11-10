# Docker Compose Prisma Cloud Compute Ecosystem Deployment

After manually deploying everything in the last tutorial. It's only natural to want to automate a lot of the configuration steps. Below you'll find an easy way to replicate the necessary apps to complete a prisma cloud compute demo lab. I'd encourage you to do it the manual way first so you understand how things are put together, but if you're in a pinch feel free to utilize this method as well. 

Keep in mind: Automation makes things look simple, but in order to become good at the automation, you need to first understand how to build with the underlying technologies. The next iteration of this I will be working on a way to take the manual configuration out. (Most likely using ansible). In a later build I'll be transitioning all of this to a kubernetes manifest. So stay tuned!

A few notes: There are some subtle differences with this env vs the one in the other tutorials. One is the change from MySQL to Postgres for the backend database. Also I've mapped the ports differently. At some point I'll go through both tutorials and ensure the end results are consistent. 

## Assumptions

You understand that this is not a production ready server. It should not be able to be accessed remotely from outside your organization's internal network. This is meant to be run from a single server to showcase the capabilities of Prisma Cloud Compute. 

## Requirements

Ubuntu 20.04 LTS Desktop VM - to build out more I'd recommend increasing the specs. 

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

### Step 1: Install Docker and Docker Compose

Install [Docker](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04)

```bash
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

Install [Docker-Compose](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-20-04)

```bash
sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Step 2: Make your compose files

Create a project directory

```bash
mkdir ~/prisma-lab-compose
cd ~/prisma-lab-compose
```

Create docker compose file

```bash
nano docker-compose.yml
```

Copy and paste the text from the code block below into the nano text editor. (NOTE: There can be no spaces at the ends of each line due to yaml formatting)

```bash
version: '3'
services:
    jenkins:
      image: jenkins/jenkins:lts
      restart: always
      hostname: jenkins
      container_name: jenkins
      privileged: true
      networks:
       - app-net
      user: root
      ports:
       - "8081:8080"
       - "50003:50000"
      volumes:
       - "~/jenkins-data:/var/jenkins_home"
       - "/var/run/docker.sock:/var/run/docker.sock"

    swagger:
      image: swaggerapi/petstore:latest
      restart: always
      hostname: swagger
      container_name: swagger 
      environment:
       - "SWAGGER_HOST=${SWAGGER_URL}"
       - "SWAGGER_URL=${SWAGGER_URL}"
       - "SWAGGER_BASE_PATH=/myapi"
      ports: 
       - "8082:8080"
      networks:
       - app-net

    vault:
      image: vault:latest
      restart: always
      hostname: vault
      container_name: vault
      cap_add:
       - IPC_LOCK
      ports:
       - "7880:7880"
      environment:
       - "VAULT_DEV_ROOT_TOKEN_ID=${VAULT_ROOT_TOKEN}"
       - "VAULT_DEV_LISTEN_ADDRESS=${VAULT_URL}"

    dvwa:
      image: vulnerables/web-dvwa:latest
      restart: always
      hostname: dvwa
      container_name: dvwa
      networks:
       - app-net
      ports:
       - "9090:80"
    
    postgres-gogs:
      image: postgres:9.5
      restart: always
      hostname: postgres-gogs
      container_name: postgres-gogs
      environment:
       - "POSTGRES_USER=${POSTGRES_USER}"
       - "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}"
       - "POSTGRES_DB=gogs"
      volumes:
       - "db-data:/var/lib/postgresql/data"
      networks:
       - app-net
    
    gogs:
      image: gogs/gogs:latest
      restart: always
      hostname: gogs
      container_name: gogs
      ports:
       - "1022:22"
       - "3000:3000"
      links:
       - postgres-gogs
      environment:
       - "RUN_CROND=true"
      networks:
       - app-net
      volumes:
       - "gogs-data:/data"
      depends_on:
       - postgres-gogs

networks:
    app-net:
      driver: bridge

volumes:
    db-data: {}
    gogs-data: {}
    jenkins-data: {}
```

After the code has been copied in hit `ctrl + X` and then `y` to save your file and exit
Create an .env file

```bash
nano .env
```

Copy and paste the code block below into your editor. Assign the values within the '<>' (angle brackets)...ensure you don't have '<>' brackets after your done editing. 

```bash
POSTGRES_USER="gogs"
POSTGRES_PASSWORD="<YOUR_GOGS_AND_POSTGRES_PASSSWORD_HERE>"
VAULT_ROOT_TOKEN="<YOUR_VAULT_ROOT_TOKEN_VALUE>"
VAULT_URL="0.0.0.0:7880"
SWAGGER_URL="http://localhost:8082"
```

Write down your password for the POSTGRES\_PASSWORD and the VAULT\_ROOT\_TOKEN. Then hit `ctrl + X` and then `y` to save and quit.

We'll use this information once we deploy

Deploy your app stack

```bash
docker-compose --env-file .env up -d
```

### Step 3: Configure Jenkins


Your apps will be accessible on the following addresses, but we'll need to get the jenkins password before we begin configuration. 

```bash
http://localhost:8081 --jenkins
http://localhost:8082 --swagger api app
http://localhost:7880 --vault
http://localhost:9090 --dvwa
http://localhost:3000 --gogs a self-hosted git repo
```

To retrieve the jenkins password in terminal:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```
Save the string as JENKINS\_INITIAL\_PASSWORD and I'll reference it in a later step.

You should now open a web browser on your vm (if using Ubuntu Desktop open firefox)

Go to your jenkins instance in your web browser `http://localhost:8081`


Paste in the JENKINS\_INITIAL\_PASSWORD and then configure away. I'll expand on this part of the configuration later. 

### Step 4: Configure gogs

Gogs will be accessible at this url `http://localhost:3000` navigate there in your web browser
You will keep everything the same except you'll modify the `host` entry to `postgres-gogs:5432`

```bash
Database type: <LEAVE_DEFAULT>
Host: postgres-gogs:5432
User: gogs
Password: <POSTGRES_PASSWORD> --you wrote this down earlier
Database Name: gogs
Application Name: <Whatever_you_want>
Repository Root Path: <LEAVE_DEFAULT>
Run User: git
Domain: <LEAVE_DEFAULT>
SSH Port: <LEAVE_DEFAULT>
HTTP Port <LEAVE_DEFAULT>
Application URL: <LEAVE_DEFAULT>
Log Path: <LEAVE_DEFAULT>
```

Register a user after hitting the save button at the bottom of the screen


### Step 5: Configure vault

Vault will be accessible at this url `http://localhost:7880` navigate there in your web browser
Enter your VAULT\_ROOT\_TOKEN to sign in
In terminal:

Install vault locally:
```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault
```

Export the env vars to your bashrc profile. 
```bash
cd $HOME
echo "export VAULT_TOKEN='<VAULT_ROOT_TOKEN>'" >> .bashrc
echo "export VAULT_ADDR='http://<DOMAIN/HOST_NAME_OF_YOUR_CHOOSING>:7880'" >> .bashrc
```

Export them for your current session.
```bash
source .bashrc
```

Check status
```bash
vault status
```

