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

Once you commit the file to the repo you'll it'll start a build of the container on the drone runner. The full tutorial on how to create a CI pipeline for container scanning can be found below: 

Enjoy!

<br />
<br />
<br />

# Create a CI twistlock container scanning pipeline

written by Kyle Butler Rev 0.2

# Purpose of this excercise: 

* To teach partners and internal PANW SA's how to utilize the twistcli tool in any continous integration pipeline. 
* To showcase some real world vulnerabilities in popular container images.
* To showcase how a developer might use the information to quickly remediate vulnerabilities. 


Goals

 * We where we can check a docker file into a Source Code Management System (Gitea) and then want to automatically have the CI tool (Drone) build a container from the dockerfile and run a vulnerability scan. Ideally we can use the results of that vulnerability scan to create an automated security test with simple pass/fail results. Additionally we'd like to the provider the developer feedback on the security of their container image, code, and respective dependencies in their VSCode IDE. Sounds like fun right? 

## Business value
---

* Faster time to value.
* Frictionless interaction between secops and devops. 
* Faster feedback loops.
* Prevent vulneabilities from being introduced the furthest left you can go in the software development lifecycle (SDLC)


## Tools we'll be using:

* [Drone CI](https://drone.io)
* VSCode
* [Gitea](https://gitea.io)
* [Prisma Cloud Compute](https://docs.twistlock.io)
* [Twistcli](https://docs.twistlock.com/docs/compute_edition/tools/twistcli.html)
* [Docker](https://Docker.io)
<br />
## What you will learn:

* How to work with the twistcli tool to scan images.
* How to configure a basic drone CI pipeline
* How to create a basic CI security test in Prisma Cloud Compute
* How to work with a Dockerfile
* How to work with Git and SCM
* Basic unix commands 
<br />

## Instructions
---

### Step 1: Obtain your twistcli tool through the Prisma Cloud Compute REST API using basic authentication.  
<br />

* Open terminal (located in the left-hand side bar)
* The `curl` command we'll use in the `zsh` terminal window will be:

```bash
curl -k --header "Authorization: Basic $(echo -n prisma-presenter:Swotr2021@! | base64 | tr -d '\n')" https://prisma-compute-lab:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
```

* *(OPTIONAL REVIEW FOR THOSE NEW TO UNIX/Linux tools) `curl` is simply a tool to transfer data using different protocols; for our use it'll be using the `http` protocol.* 
* *`curl -k` allows for an insecure request. The reason we're using `-k` is beause by default the certificate deployed with prisma cloud compute console is a self-signed certificate.* 
* *`--header` allows us to put a request header in our `curl` call. The request header we're looking to send is `"authorization: basic username:password`.*
* *The next part is where things get fun. Remember in math the order of opearations or PEMDAS (Please Excuse My Dear Aunt Sally)? Same applies here with our script. The `$(command)` in the `$()` is evaluated before the curl command.* 
* *`echo` simply displays text. The `-n` flag tells it to not output a trailing newline.* 
* *In this case `prisma-presenter` is our username and `Swotr2021@!` is our password.*
* *The `|` pipe character pipes the output of the the `echo` command into the next command which is `base64`.* 
* *`base64` encodes/decodes a string. So by echoing our username and password and piping it into the `base64` command we're adding a layer of security since we could be sending this command in a real environment over the network.*
* *`tr -d` allows us to delete a character in the encoded string from the first two commands.* 
* *`https://prisma-compute-lab:8083/api/v1/util/twistcli` defines the host `prisma-compute-lab:8083` and the api endpoint `/api/v1/util/twistcli`, while  `https://` defines the protocol.*
* *The `chmod a+x` command gives all users execution rights on the `twistcli` binary*

Explanation as to why we're sending the request this way when the request could be sent in a simplier format:

* Because we're going to use this syntax in our CI pipeline where in a real environment we'd want the added layer of security so as to not unecessarily expose our credentials over the network. 
  
<br />

### Step 2: Work with twistcli and docker in your terminal. 
<br />

* First lets see what images we have available to us on this host machine by running `docker images -a` in our terminal window. This command will show you `all` the current images on the host machine. Your output should look similar to this code block below:

```bash
REPOSITORY                       TAG                  IMAGE ID       CREATED         SIZE
bridgecrew/checkov               2.0.436              e2a9b8b7b76d   9 hours ago     245MB
bridgecrew/checkov               latest               e2a9b8b7b76d   9 hours ago     245MB
bridgecrew/checkov               <none>               af4c8ca7750d   2 days ago      245MB
drone/drone                      2.3.1                4338bae655e1   13 days ago     57.1MB
httpd                            2                    f34528d8e714   2 weeks ago     138MB
registry                         2                    b2cb11db9d3d   3 weeks ago     26.2MB
postgres                         alpine               b8c450ae0903   3 weeks ago     192MB
twistlock/private                console_21_08_514    58c779558b27   4 weeks ago     852MB
twistlock/private                defender_21_08_514   aaf13f247f08   4 weeks ago     228MB
drone/drone-runner-docker        latest               f9a37127972e   2 months ago    26.3MB
vault                            latest               97ff3bfe78c3   3 months ago    208MB
rancher/coredns-coredns          1.8.3                3885a5b7f138   7 months ago    43.5MB
rancher/local-path-provisioner   v0.0.19              148c19256271   9 months ago    42.4MB
swaggerapi/petstore              latest               652c30857172   18 months ago   307MB
gitea/gitea                      1.10.0               8f2e2a3d90a8   22 months ago   103MB
rancher/metrics-server           v0.3.6               9dd718864ce6   23 months ago   39.9MB
vulnerables/web-dvwa             latest               ab0d83586b6e   2 years ago     712MB
rancher/pause                    3.1                  da86e6ba6ca1   3 years ago     742kB

```
* In `docker` you can define an image by it's `REPOSITORY` and `TAG` seperated by a `:`.
* We're going to scan the `postgres:alpine` container image for vulnearabilities in this demo.
* The syntax we'll use in our CI pipeline is:

```bash
./twistcli images scan --address https://prisma-compute-lab:8083 --user prisma-presenter --password Swotr2021@! --details postgres:alpine
```
* So why the `./` in front of our `twistcli` command? Because again the goal here is to use these commands in a CI tool where adding the binary to $USER path is an uncessary step. Faster to type `./` then doing something like `cp twistcli /usr/local/bin`

* :

```bash
Scan results for: image postgres:alpine sha256:b8c450ae09036f6ee1af4c641f3df3199a7f8d80771056e42d8cf18ea4291018
Vulnerabilities
+----------------+----------+------+-----------+----------+-------------------+------------+------------+----------------------------------------------------+
|      CVE       | SEVERITY | CVSS |  PACKAGE  | VERSION  |      STATUS       | PUBLISHED  | DISCOVERED |                    DESCRIPTION                     |
+----------------+----------+------+-----------+----------+-------------------+------------+------------+----------------------------------------------------+
| CVE-2021-33560 | high     | 7.50 | libgcrypt | 1.9.3-r0 | fixed in 1.9.4-r0 | > 3 months | < 1 hour   | Libgcrypt before 1.8.8 and 1.9.x before 1.9.3      |
|                |          |      |           |          | > 3 months ago    |            |            | mishandles ElGamal encryption because it lacks     |
|                |          |      |           |          |                   |            |            | exponent blinding to address a side-channel attack |
|                |          |      |           |          |                   |            |            | agains...                                          |
+----------------+----------+------+-----------+----------+-------------------+------------+------------+----------------------------------------------------+
| CVE-2021-40528 | medium   | 5.90 | libgcrypt | 1.9.3-r0 |                   | 22 days    | < 1 hour   | The ElGamal implementation in Libgcrypt before     |
|                |          |      |           |          |                   |            |            | 1.9.4 allows plaintext recovery because, during    |
|                |          |      |           |          |                   |            |            | interaction between two cryptographic libraries, a |
|                |          |      |           |          |                   |            |            | cert...                                            |
+----------------+----------+------+-----------+----------+-------------------+------------+------------+----------------------------------------------------+

Vulnerabilities found for image postgres:alpine: total - 2, critical - 0, high - 1, medium - 1, low - 0
Vulnerability threshold check results: PASS

Compliance Issues
+----------+------------------------------------------------------------------------+
| SEVERITY |                              DESCRIPTION                               |
+----------+------------------------------------------------------------------------+
| high     | (CIS_Docker_v1.2.0 - 4.1) Image should be created with a non-root user |
+----------+------------------------------------------------------------------------+

Compliance found for image postgres:alpine: total - 1, critical - 0, high - 1, medium - 0, low - 0
Compliance threshold check results: PASS
Link to the results in Console: https://prisma-compute-lab:8083/#!/monitor/vulnerabilities/images/ci?search=sha256%3Ab8c450ae09036f6ee1af4c641f3df3199a7f8d80771056e42d8cf18ea4291018

```
* Woo-hoo!! You're on your way to being a devsecops practitioner! 
* Now if you want to see your manual scan results in the prisma cloud compute console, open up firefox and go to https://prisma-compute-lab:8083. 
* In the console go to `Monitor > Vulnerabilities` click the `Images` tab and finally the `CI` subtab. You should see a *prettier* gui output there. 
* Okay, that was fun, but now we want automation during the `Continous Integration` process!

<br />

### Step 3: Build your Dockerfile
<br />

Quick technical break:
* So before we go any further let's pause for a moment and discuss what CI is. 
* CI or (continous integration) can be broadly defined as an automated process in which an application is frequently built and unit tested. In this case, we're building a component of that application (a docker container) and doing a security test. (we won't be writing any unit tests for this demo)

 <br />
And done with that

 * Next step is to play the app developer. We're going to open VSCode from the left-hand menu bar in our Linux machine. Once the VSCode IDE is open select `File > Open Workspace...` I've created a few pre-built workspaces for you to get started. Open the `ci-image-vulnerability-scan-demo.code-workspace` file. Then click the `Explorer` icon on the top left corner of the VSCode IDE (Looks like two pages). 
 * Inside this workspace you should notice three files: `delete_this.drone.yml`, `Dockerfile`, and this `README.md` file. 
 * These files live in a local directory located on this VM in `/home/prisma-presenter/Project/ci-vuln-scan
`. If you'd like you can open up a terminal window and cd to that directory to check them out. As you might have noticed I've also intialized `git` for version control.
 * This directory is also configured with your source code managment system `gitea`; which is a self-hosted code repository. This configuration allows you push code back to the SCM system. Let's start with the `Dockerfile`
 * You'll see a very basic Dockerfile that looks something like this:

```bash
FROM python:latest
```
* That's it?!!! Well...Yeah. This could be a base image. Another way to think about this container image is it would be exactly the same as if you ran `docker pull centos:latest` from dockerhub. That container alone won't do much, but let's add some code to our Dockerfile. 
* First, let's create a new file in this workspace by hovering over the explorer menu and clicking the icon that looks like a page with a `+` symbol. 
* Name this file `super_safe_code.sh`. In this file we'll write some "super safe safe code."
* Go ahead and copy the codeblock below into your `super_safe_code.sh` file. 


```bash
#!/bin/sh

echo "hello I'm super safe safe code"
exit
```
* Now go back to your `Dockerfile` and add two more lines. 
* The first line we'll replace `FROM python:latest` with `FROM centos:latest`. The next line we'll add: `COPY ./super_safe_code.sh /var` which will copy our "super safe code" into the container in the /var while the container is being built. 
* The second line we'll add under our `COPY ./super_safe_code.sh /var` is the command which we want to execute when the container is run. In docker this is called the `ENTRYPOINT`. Our third line in the docker file will be `EXPOSE 8181`. This will allow for communication with the container over the container port `8181`. Our fourth line will be `ENTRYPOINT ["/bin/sh", "/var/super_safe_code.sh"]`. This is the equilvent of opening up terminal and running `sh ./super_safe_code.sh`, but in the container. Your dockerfile should now look like the code block below:

```bash
FROM centos:latest
COPY ./super_safe_code.sh /var/super_safe_code.sh
EXPOSE 8181
ENTRYPOINT ["/bin/sh", "/var/super_safe_code.sh"]
```

* Awesome, you're a great developer. You wrote some super safe code and put it in the latest image. What coud be wrong with that? 

<br/>

### Step 4: Drone pipeline time! Automate away!

<br/>

* Okay, so the last step is to configure our `drone` pipeline. Open the file `delete_this.drone.yml`.
* It should look like the code block I copied from this address https://docs.drone.io/pipeline/docker/examples/services/docker_dind/ (Gotta respect great documenation). Example Below:


```yaml
---
kind: pipeline
name: default

steps:
- name: test
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 5 # give docker enough time to start
  - docker ps -a

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

* We're going to rename this file to .drone.yml and then configure it line by line to make it do what we want. 
* `---` needs to be on line 1 for this demo. We'll leave that as is for now. 
* `kind: pipeline` will also be a line we don't mess with. 
* `name: default` is one we will definitly customize. Let's change this to something more interesting like `name: my super secure CI pipeline`
* `steps:` will remain the same
* `- name: test` we'll definitely change to something more representitive of what we're doing in this first step. Let's change it to `- name: build`
* `  image: docker:dind` specifies the image we're using and in this case we won't change it. `dind` = docker in docker. 
* `  volumes:` will remain the same
* `-name: dockersock` will remain the same
* `path: /var/run` will remain
* `commands:` will remain the same but is important to understand. Under this line is where we'll be putting the commands we worked on earlier in the demo. 
* ` - sleep 5` will need to stay so that it gives some time for docker-in-docker to start. 
* ` - docker ps -a` is where we'll start customizing. Let's change this line to `- docker build -t my_questionable_container:1 .`

At this point your `.drone.yml` file should look like the code block below:

<br />

```yaml
---
kind: pipeline
name: my super secure CI pipeline

steps:
- name: build
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 5 # give docker enough time to start
  - docker build -t my_questionable_container:1 . 

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


* The great thing about drone is that it will automatically check out all the files in the repository by default. That's why the docker `build -t my_questionable_container:1 .` line works. 
* The next thing we need to do is create another step. To do this let's copy everything from `- name: build` to `build -t my_questionable_container:1 .` 

what you copied should look like this:

```yaml
- name: build
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 5 # give docker enough time to start
  - docker build -t my_questionable_container:1 . 
```

* Paste what's on your clipboard right under the line: `build -t my_questionable_container:1 .`

Now your `.drone.yml` file will look like this code block below:

<br />

```yaml
---
kind: pipeline
name: my secure CI pipeline

steps:
- name: build
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 5 # give docker enough time to start
  - docker build -t my_questionable_container:1 .

- name: build
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 5 # give docker enough time to start
  - docker build -t my_questionable_container:1 . 

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

Let's start configuring the second step in our pipeline. 

* As before, we're really only going to change the `- name: build` line to something like `- name: vuln scan`
* Then we can skip lines until we get to the `commands:` section. 
* Let's leave the `- sleep 5` line to give the docker engine enough time to spin up. 
* We're going to delete the second instance of `build -t my_questionable_container:1 .` command and replace it with `apk add curl`
* This will add `curl` to our container runner, which will be needed for our next step. 
* Now we're going to use a command from earlier in this demo: 


<br />

```bash
curl -k --header "Authorization: Basic $(echo -n prisma-presenter:Swotr2021@! | base64 | tr -d '\n')" https://prisma-compute-lab:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
```

Unfortunately this won't work in it's current form. This is because we're running docker-in-docker and because of the way I've configured the `/etc/hosts` file in this environment. There's easier ways to solve this issue, but it's important to understand how to solve this in a real environment so I'm going to provide you with the troubleshooting fix. 


* To test out how this doesn't work, let's get inside the drone runner container. We can do this by opening terminal and running `docker exec -it drone-runner /bin/sh`
* This command will allow us to open a `sh` session on the `drone-runner` container. 
* Let's try and run the command inside our container sh session:

NOTE: THESE NEXT FEW COMMANDS ARE EXPECTED TO FAIL. KEEP READING AFTER RUNNING THE COMMANDS

```bash
curl -k --header "Authorization: Basic $(echo -n prisma-presenter:Swotr2021@! | base64 | tr -d '\n')" https://prisma-compute-lab:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
```

* You should see that it fails. Why? Because curl isn't available. (Hence the reason we're running `apk add curl` in our CI pipeline)
* In our container shell let's add curl `apk add curl` and then reinput our command:

```bash
curl -k --header "Authorization: Basic $(echo -n prisma-presenter:Swotr2021@! | base64 | tr -d '\n')" https://prisma-compute-lab:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
```

* Still doesn't work! How come? Because, of the `/etc/hosts` config. Try `ping prisma-compute-lab`. Doesn't work right? Okay, so how to solve this issue. Let's try this. `ping 172.29.0.9` that should get a response. To understand why, you need to understand docker networking, which is a little beyond the scope of this demo. Let's solve this issue:

* Sign into the prisma cloud compute console: https://prisma-cloud-compute-lab:8083 go to the SAN section under `manage > Defenders` and click the `SAN` (Subject alternative names) section and try pinging all the IP addresses listed there from our drone runner shell. The prisma cloud compute console makes itself available on a number of IPs. We could then use the IP address that worked in our command from the drone runner shell. So that it something like this:

```bash
curl -k --header "Authorization: Basic $(echo -n prisma-presenter:Swotr2021@! | base64 | tr -d '\n')" https://172.29.0.9:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
```

* That should work

* Important notes: 

To ensure that the console was able to communicate with drone I added the `twistlock_console` container to the `compose_deploy_default` docker network. The commands I used to find the IP addresses to add to the SAN in the Prisma Cloud Compute console are:

THIS DOESN'T NEED TO BE DONE - BECAUSE WE DID it earlier!

* `docker network ls` - list the networks
* `docker inspect twistlock_console` - see what IP addresses are assigned to the container
* `docker network connect compose_deploy_default twistlock_console` - connects the `twistlock_console` container to the `compose_deploy_default` network. 
* `docker inspect twistlock_console` - to see the new IP addresses. 


Back to editing our `.drone.yml` file; it should look like the code block below:

```yaml
---
kind: pipeline
name: my secure CI pipeline

steps:
- name: build
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 5
  - docker build -t my_questionable_container:1 .

- name: vuln scan
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 5
  - apk add curl # <---where we left off, we'll add some lines below this. 

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
Okay, here goes:

* We're going to add another command below our `apk add curl` command
* This is where we'll copy our curl command from earlier. We'll paste the below line in after the `apk add curl` command line:

```bash
  - |
    curl -k --header "Authorization: Basic $(echo -n prisma-presenter:Swotr2021@! | base64 | tr -d '\n')" https://172.29.0.9:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
```

* Our `.drone.yml` file should now look like this:
  
```yaml
---
kind: pipeline
name: my secure CI pipeline

steps:
- name: build
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 5
  - docker build -t my_questionable_container:1 .

- name: vuln scan
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 5
  - apk add curl
  - |
    curl -k --header "Authorization: Basic $(echo -n prisma-presenter:Swotr2021@! | base64 | tr -d '\n')" https://172.29.0.9:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;


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

* Cool! Last command we're going to add in below your `curl` command is also from earlier:

```bash
  - | 
    ./twistcli images scan --address https://prisma-compute-lab:8083 --user prisma-presenter --password Swotr2021@! --details my_questionable_container:1
```

* Of course we'll need to replace `httpd:2` with our container we've built `my_questionable_container:`
* As before let's replace the `prisma-compute-lab:8083` with `172.29.0.9:8083`. The finished `.drone.yml` file should look like the code block below:

```yaml
---
kind: pipeline
name: my secure CI pipeline

steps:
- name: build
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 5
  - docker build -t my_questionable_container:1 .

- name: vuln scan
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 5
  - apk add curl
  - |
    curl -k --header "Authorization: Basic $(echo -n prisma-presenter:Swotr2021@! | base64 | tr -d '\n')" https://172.29.0.9:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
    |
    ./twistcli images scan --address https://prisma-compute-lab:8083 --user prisma-presenter --password Swotr2021@! --details my_questionable_container:1


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

  IMPORTANT NOTE:

  If working with a yaml file, you need to be mindful of a few things:

  * yaml is sensitive to spaces at the end of each line. Double check your file to ensure there are no spaces at the ends of your lines. 
  * The other thing is that formatting needs to be uniform. So the indents of each line matter. 
  * If you copy and paste the above code block into your `.drone.yml` file you shouldn't have any issues. 


But wait! Don't check your code into your `SCM Gitea repository yet`! There's sensitive information in our pipeline! We need to replace the sensitive strings with secrets in drone. 

* Let's navigate to our drone server at http://drone:8000.
* On the dashboard page select the repo `ci-image-vulnerability-scan-demo`.
* Go to `settings` then `secrets` and review the two secrets I've put into the drone server.
* The first secret is `pcc_user` and with the value of `prisma-presenter`
* The second secret is`pcc_password` with the value of `Swotr2021@!`

One last round of edits to our `.drone.yml` file in VSCode. We'll need to add the secret to the pipeline.

* drone makes the secrets available to the pipeline as `env vars` (environment variables). 
* we'll need those secrets for the second step of our pipeline.

We'll insert the below code block in our first and second step; then replace the sensitive information with `vars`:

```yaml
  environment:
    PCC_USER:
      from_secret: pcc_user
    PCC_PASSWORD:
      from_secret: pcc_password
```

Your completely finished `.drone.yml` will now look like the code block below:

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
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 5 # give docker enough time to start
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
    curl -k --header "Authorization: Basic $(echo -n $PCC_USER:$PCC_PASSWORD | base64 | tr -d '\n')" https://172.29.0.9:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
  - |
    ./twistcli images scan --address https://172.29.0.9:8083 -u $PCC_USER -p $PCC_PASSWORD --details my_questionable_container:1 .

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

  Finally done! Pat yourself on the back. You've done a ton of work to secure this. Now it's time to reap the security automation benefits. 

  * Now it's time to check your code in through VSCode
  * Click the source code icon on the VSCode editor or hold (ctrl + shift + G)
  * You'll then click the `+` icon next two the three files we worked on. `Dockerfile`, `safe_safe.sh`, and `.drone.yml`
  * Finally click the `check mark` icon to commit your code. If you get a warning click save all and commit. 
  * This should open a box in the center of your screen for a message. Type `added pipeline, code, and Dockerfile` Then hit enter. 
  * Finally click the `...` to the right of the `check mark` icon and from the drop-down menu select push. Another window in the center of your editor should pop up asking for your username: `prisma-presenter` (hit enter) and the gitea password which in this case is `qgJKfz5eKwNNWB6`.

Now you can sit back and wait. 


Click the `drone extension` on the editor to watch the build or go to http://drone:8000 or http://gitea:3000. And you should be able to watch the build!


You'll see a similar output to what you saw when your ran the `twistcli` command manually. Woohooo!

Note: The Drone plugin for VS Code kinda butchers the logs. So you can review it in https://drone:8000 for a better view. 

* Because there's no CI policy in place the security vulnerability scan should pass. We'll change that in our last step. 

### Step 5: DEVSECOPS!

Okay so here's the deal. We want to have security work within devops to have a frictionless experience. We'll accomplish this by having the Security practioner put a high level policy in place that allows the test pass of fail based on the vulnerabilities in the container. 


* Sign-in to the prisma cloud compute console at https://prisma-compute-lab:8083. Go to `Defend > Vulnerabilities`, click the `Images` tab and then the `CI` sub-tab. 
* Hit the button `+ Add rule`. 
* We'll type a name for the rule: `CI policy`
* Last we'll change the block threshold to medium.
* Hit save. 


Back to your vscode ide

* add a line to the `README.md` doc. Anything will do. Commit the changes as you did before and push back to the repo. You should now watch your build pass, but the vuln scan step fail! Which would alert the develoepr and create a faster feedback loop! 

Congrats! You've successfully completed the demo. Lots more to do and experiment with! But that's all for now!




