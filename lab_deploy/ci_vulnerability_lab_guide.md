
# Create a CI twistlock container scanning pipeline

written by Kyle Butler Rev 0.3

# Purpose of this exercise: 

* To teach partners and internal PANW SA's how to utilize the twistcli tool in any continuous integration pipeline. 
* To showcase some real world vulnerabilities in popular container images.
* To showcase how a developer might use the information to quickly remediate vulnerabilities. 


Goals

 * We where we can check a docker file into a Source Code Management System (Gitea) and then want to automatically have the CI tool (Drone) build a container from the Dockerfile and run a vulnerability scan. Ideally we can use the results of that vulnerability scan to create an automated security test with simple pass/fail results. Additionally we'd like to the provider the developer feedback on the security of their container image, code, and respective dependencies in their VSCode IDE. Sounds like fun right? 

## Business value
---

* Faster time to value.
* Frictionless interaction between SecOps and DevOps. 
* Faster feedback loops.
* Prevent vulnerabilities from being introduced the furthest left you can go in the software development lifecycle (SDLC)


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


## Assumptions

* This assumes that you have a Prisma Cloud Compute user with the username `prisma-presenter` and the password `Swotr2021@!`. 

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
* *`curl -k` allows for an insecure request. The reason we're using `-k` is because by default the certificate deployed with prisma cloud compute console is a self-signed certificate.* 
* *`--header` allows us to put a request header in our `curl` call. The request header we're looking to send is `"authorization: basic username:password`.*
* *The next part is where things get fun. Remember in math the order of opearations or PEMDAS (Please Excuse My Dear Aunt Sally)? Same applies here with our script. The `$(command)` in the `$()` is evaluated before the curl command.* 
* *`echo` simply displays text. The `-n` flag tells it to not output a trailing newline.* 
* *In this case `prisma-presenter` is our username and `Swotr2021@!` is our password.*
* *The `|` pipe character pipes the output of the `echo` command into the next command which is `base64`.* 
* *`base64` encodes/decodes a string. So by echoing our username and password and piping it into the `base64` command we're adding a layer of security since we could be sending this command in a real environment over the network.*
* *`tr -d` allows us to delete a character in the encoded string from the first two commands.* 
* *`https://prisma-compute-lab:8083/api/v1/util/twistcli` defines the host `prisma-compute-lab:8083` and the api endpoint `/api/v1/util/twistcli`, while  `https://` defines the protocol.*
* *The `chmod a+x` command gives all users execution rights on the `twistcli` binary*

Explanation as to why we're sending the request this way when the request could be sent in a simpler format:

* Because we're going to use this syntax in our CI pipeline where in a real environment we'd want the added layer of security so as to not unnecessarily expose our credentials over the network. 
  
<br />

### Step 2: Work with twistcli and docker in your terminal. 
<br />

* First lets see what images we have available to us on this host machine by running `docker images -a` in our terminal window. This command will show you `all` the current images on the host machine. Your output should look similar to this code block below:

```bash
REPOSITORY                  TAG                  IMAGE ID       CREATED        SIZE
prom/prometheus             main                 13fd843a4e3c   3 hours ago    204MB
postgres                    alpine3.15           faa0ddfa0c0f   23 hours ago   371MB
registry                    2                    9c97225e83c8   7 days ago     24.2MB
grafana/grafana-oss         main                 d9bb86e31a92   8 days ago     276MB
gitea/gitea                 1.16.1               3fccf68da11d   9 days ago     240MB
vault                       1.9.3                c82c19c7b24e   2 weeks ago    195MB
drone/drone                 2.9.1                467742fe4bc7   2 weeks ago    59.1MB
twistlock/private           console_22_01_840    10885e2e768d   3 weeks ago    1.24GB
twistlock/private           defender_22_01_840   77136ffdfab7   3 weeks ago    332MB
splunk/splunk               latest               f7eab9d1acee   7 weeks ago    1.93GB
swaggerapi/petstore         latest               ac1fa2177457   2 months ago   325MB
drone/drone-runner-docker   1.8                  56dddb548a45   2 months ago   24.2MB
vulnerables/web-dvwa        latest               ab0d83586b6e   3 years ago    712MB
```
* In `docker` you can define an image by it's `REPOSITORY` and `TAG` separated by a `:`.
* We're going to scan the `postgres:13.6-bullseye` container image for vulnerabilities in this demo.
* The syntax we'll use in our CI pipeline is:

```bash
./twistcli images scan --address https://prisma-compute-lab:8083 --user prisma-presenter --password Swotr2021@! --details postgres:15.0-bullseye
```
* So why the `./` in front of our `twistcli` command? Because again the goal here is to use these commands in a CI tool where adding the binary to $USER path is an unnecessary step. Faster to type `./` then doing something like `cp twistcli /usr/local/bin`

```bash
Scan results for: image postgres:13.6-bullseye sha256:b8c450ae09036f6ee1af4c641f3df3199a7f8d80771056e42d8cf18ea4291018
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

Vulnerabilities found for image postgres:alpine3.15 total - 2, critical - 0, high - 1, medium - 1, low - 0
Vulnerability threshold check results: PASS

Compliance Issues
+----------+------------------------------------------------------------------------+
| SEVERITY |                              DESCRIPTION                               |
+----------+------------------------------------------------------------------------+
| high     | (CIS_Docker_v1.2.0 - 4.1) Image should be created with a non-root user |
+----------+------------------------------------------------------------------------+

Compliance found for image postgres:alpine3.15 total - 1, critical - 0, high - 1, medium - 0, low - 0
Compliance threshold check results: PASS
Link to the results in Console: https://prisma-compute-lab:8083/#!/monitor/vulnerabilities/images/ci?search=sha256%3Ab8c450ae09036f6ee1af4c641f3df3199a7f8d80771056e42d8cf18ea4291018

```
* Woo-hoo!! You're on your way to being a DevSecOps practitioner! 
* Now if you want to see your manual scan results in the prisma cloud compute console, open up firefox and go to https://prisma-compute-lab:8083. 
* In the console go to `Monitor > Vulnerabilities` click the `Images` tab and finally the `CI` sub-tab. You should see a *prettier* gui output there. 
* Okay, that was fun, but now we want automation during the `Continous Integration` process!

<br />

### Step 3: Build your Dockerfile
<br />

Quick technical break:
* So before we go any further let's pause for a moment and discuss what CI is. 
* CI or (continuous integration) can be broadly defined as an automated process in which an application is frequently built and unit tested. In this case, we're building a component of that application (a docker container) and doing a security test. (we won't be writing any unit tests for this demo)

 <br />
And done with that

 * Next step is to play the app developer. We're going to open VSCode from the left-hand menu bar in our Linux machine. Once the VSCode IDE is open select `File > Open Workspace...` I've created a few pre-built workspaces for you to get started. Open the `ci-image-vulnerability-scan-demo.code-workspace` file. Then click the `Explorer` icon on the top left corner of the VSCode IDE (Looks like two pages). 
 * Inside this workspace you should notice three files: `delete_this.drone.yml`, `Dockerfile`, and this `README.md` file. 
 * These files live in a local directory located on this VM in `/home/prisma-presenter/Project/ci-vuln-scan
`. If you'd like you can open up a terminal window and cd to that directory to check them out. As you might have noticed I've also initialized `git` for version control.
 * This directory is also configured with your source code management system `gitea`; which is a self-hosted code repository. This configuration allows you push code back to the SCM system. Let's start with the `Dockerfile`
 * You'll see a very basic Dockerfile that looks something like this:

```bash
FROM python:latest
```
* That's it?!!! Well...Yeah. This could be a base image. Another way to think about this container image is it would be exactly the same as if you ran `docker pull python:latest` from Dockerhub. That container alone won't do much, but let's add some code to our Dockerfile. 
* First, let's create a new file in this workspace by hovering over the explorer menu and clicking the icon that looks like a page with a `+` symbol. 
* Name this file `super_safe_code.sh`. In this file we'll write some "super safe safe code."
* Go ahead and copy the code block below into your `super_safe_code.sh` file. 


```bash
#!/bin/sh

echo "hello I'm super safe safe code"
exit
```
* Now go back to your `Dockerfile` and add two more lines. 
* The first line we'll replace `FROM python:latest` with `FROM python:latest`. The next line we'll add: `COPY ./super_safe_code.sh /var` which will copy our "super safe code" into the container in the /var while the container is being built. 
* The second line we'll add under our `COPY ./super_safe_code.sh /var` is the command which we want to execute when the container is run. In docker this is called the `ENTRYPOINT`. Our third line in the docker file will be `EXPOSE 8181`. This will allow for communication with the container over the container port `8181`. Our fourth line will be `ENTRYPOINT ["/bin/sh", "/var/super_safe_code.sh"]`. This is the equivalent of opening up terminal and running `sh ./super_safe_code.sh`, but in the container. Your Dockerfile should now look like the code block below:

```bash
FROM python:latest
COPY ./super_safe_code.sh /var/super_safe_code.sh
EXPOSE 8181
ENTRYPOINT ["/bin/sh", "/var/super_safe_code.sh"]
```

* Awesome, you're a great developer. You wrote some super safe code and put it in the latest image. What could be wrong with that? 

<br/>

### Step 4: Drone pipeline time! Automate away!

<br/>

* Okay, so the last step is to configure our `drone` pipeline. Open the file `delete_this.drone.yml`.
* It should look like the code block I copied from this address https://docs.drone.io/pipeline/docker/examples/services/docker_dind/ (Gotta respect great documentation). Example Below:


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
  - sleep 10 # give docker enough time to start
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
* `name: default` is one we will definitely customize. Let's change this to something more interesting like `name: my super secure CI pipeline`
* `steps:` will remain the same
* `- name: test` we'll definitely change to something more representative of what we're doing in this first step. Let's change it to `- name: build`
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
  - sleep 10 # give docker enough time to start
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
  - sleep 10 # give docker enough time to start
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
  - sleep 10 # give docker enough time to start
  - docker build -t my_questionable_container:1 .

- name: build
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 10 # give docker enough time to start
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
* In our container shell let's add curl `apk add curl` and then re-input our command:

```bash
curl -k --header "Authorization: Basic $(echo -n prisma-presenter:Swotr2021@! | base64 | tr -d '\n')" https://prisma-compute-lab:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
```

* Still doesn't work! How come? Because, of the `/etc/hosts` config. Try `ping prisma-compute-lab`. Doesn't work right? Okay, so how to solve this issue. Let's try this. `ping twistlock_console` that should get a response. To understand why, you need to understand docker networking, which is a little beyond the scope of this demo. Let's solve this issue:

* Sign into the prisma cloud compute console: https://prisma-cloud-compute-lab:8083 go to the SAN section under `manage > Defenders` and click the `SAN` (Subject alternative names) section and try pinging all the IP addresses listed there from our drone runner shell. The prisma cloud compute console makes itself available as a number of names and IP Addresses. We'll use the hostname that worked in our command from the drone runner shell. So that it looks like this:

```bash
curl -k --header "Authorization: Basic $(echo -n prisma-presenter:Swotr2021@! | base64 | tr -d '\n')" https://twistlock_console:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
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
  - sleep 10
  - docker build -t my_questionable_container:1 .

- name: vuln scan
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 10
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
    curl -k --header "Authorization: Basic $(echo -n prisma-presenter:Swotr2021@! | base64 | tr -d '\n')" https://twistlock_console:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
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
  - sleep 10
  - docker build -t my_questionable_container:1 .

- name: vuln scan
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 10
  - apk add curl
  - |
    curl -k --header "Authorization: Basic $(echo -n prisma-presenter:Swotr2021@! | base64 | tr -d '\n')" https://twistlock_console:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;


services
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
* As before let's replace the `prisma-compute-lab:8083` with `twistlock_console:8083`. The finished `.drone.yml` file should look like the code block below:

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
  - sleep 10
  - docker build -t my_questionable_container:1 .

- name: vuln scan
  image: docker:dind
  volumes:
  - name: dockersock
    path: /var/run
  commands:
  - sleep 10
  - apk add curl
  - |
    curl -k --header "Authorization: Basic $(echo -n prisma-presenter:Swotr2021@! | base64 | tr -d '\n')" https://twistlock_console:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
    |
    ./twistcli images scan --address https://twistlock_console:8083 --user prisma-presenter --password Swotr2021@! --details my_questionable_container:1


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
  - sleep 10 # give docker enough time to start
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
    curl -k --header "Authorization: Basic $(echo -n $PCC_USER:$PCC_PASSWORD | base64 | tr -d '\n')" https://twistlock_console:8083/api/v1/util/twistcli > twistcli; chmod a+x twistcli;
  - |
    ./twistcli images scan --address https://twistlock_console:8083 -u $PCC_USER -p $PCC_PASSWORD --details my_questionable_container:1 .

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
  * Click the source control icon on the VSCode editor or hold (ctrl + shift + G)
  * You'll then click the `+` icon next two the three files we worked on. `Dockerfile`, `super_safe_code.sh`, and `.drone.yml`
  * Finally click the `check mark` icon to commit your code. If you get a warning click save all and commit. 
  * This should open a box in the center of your screen for a message. Type `added pipeline, code, and Dockerfile` Then hit enter. 
  * Finally click the `...` to the right of the `check mark` icon and from the drop-down menu select push. Another window in the center of your editor should pop up asking for your username: `prisma-presenter` (hit enter) and the gitea password which in this case is `Swotr2021@!`.

Now you can sit back and wait. 


Click the `drone extension` on the editor to watch the build or go to http://drone:8000 or http://gitea:3000. And you should be able to watch the build!


You'll see a similar output to what you saw when your ran the `twistcli` command manually. Woohooo!

Note: The Drone plugin for VS Code kinda butchers the logs. So you can review it in https://drone:8000 for a better view. 

* Because there's no CI policy in place the security vulnerability scan should pass. We'll change that in our last step. 

### Step 5: DEVSECOPS!

Okay so here's the deal. We want to have security work within DevOps to have a frictionless experience. We'll accomplish this by having the Security practitioner put a high level policy in place that allows the test pass of fail based on the vulnerabilities in the container. 


* Sign-in to the prisma cloud compute console at https://prisma-compute-lab:8083. Go to `Defend > Vulnerabilities`, click the `Images` tab and then the `CI` sub-tab. 
* Hit the button `+ Add rule`. 
* We'll type a name for the rule: `CI policy`
* Last we'll change the block threshold to medium.
* Hit save. 


Back to your vscode IDE

* add a line to the `README.md` doc. Anything will do. Commit the changes as you did before and push back to the repo. You should now watch your build pass, but the vuln scan step fail! Which would alert the developer and create a faster feedback loop! 

Congrats! You've successfully completed the demo. Lots more to do and experiment with! But that's all for now!




