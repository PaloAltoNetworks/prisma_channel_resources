# Prisma Cloud, GitLab On-Prem, and Kaniko

Written by Kyle Butler from PANW and Chase Christensen from Insight


## Why we think this is cool

* Kaniko runs rootless and never actually runs the container being built. This ensures that nothing changes on the runner doing the build. In fact, with Kaniko it builds and pushes to a container registry (presumably a secure private one, connected and scanned on regular interval by the prisma defender of course) all in the same command.
* Before I go too much further, I want to take a moment to blow up Chase Christensen from Insight. I can count on two hands the number of engineers who have the type of stamina and energy as Chase possess. Maybe it's all those times at Blizzard living the QA life, or his current passion for being a master SRE. How many people have their CKA, CKS, and CKAD? How many of those people still like to stay up until the late hours of the night not because they have to, but because they enjoy solving problems and ensuring the security of the people they work with? Not as many as the market needs. Thank you Chase for leading this and letting me contribute. Lots of fun. 
* Because we had to build inside the kaniko container, it meant there was never a time where we had a plain text secret exists in a file on the runner host itself.  
## Requires

* Self-hosted instance of GitLab set up with TLS/SSL certs signed by a trusted CA.
* A user account in GitLab with permissions which allow you to set-up ci/cd pipeline jobs, create new repositories, and grant access to those repositories. 

## What we learned putting this together

Building containers inside the kaniko container is spartan to say the least. The primary challenges we faced were:

* Bringing down the twistcli binary from the Prisma Cloud Compute API url (`$TL_CONSOLE`) while inside kaniko (no curl, no package managers, good thing wget was still installed)
* Retrieving a copy of a text file from another private remote repository so we could `cat` it's contents into the cloned Dockerfile during the first Scan Only build stage. 
* Getting the variables into the inejected layers before the kaniko "build-push" command to do the twistcli scan isn't as easy as it first seeemed. 
* If you're looking for a very secure build way to build containers on your runners then this may be the most secure way you can go about doing it. 
* Podman might have been easier, but would not have been as secure. Docker even easier...but lots of issues there that have the potential to change your runners behaviors in subsequent build pipelines...a big no-no. 

### Steps to do before executing:

* Ensure you have a way to get the cert package down to the runner as a .crt file which is required for Kaniko to work, recommending you either put the cert package in the repo you're working on or clone it using wget from a different repo. 

* Create a plain text file called `prisma-containerized-scan.txt`, then paste in the contents from the code block directly below:

```
#Add Twistcli
RUN mkdir /app
COPY /twistcli /app/twistcli
RUN chmod a+x /app/twistcli

#Execute image scan
RUN /app/twistcli images scan --containerized --details --address TL_CONSOLE --user PC_ACCESSKEY --password PC_SECRETKEY CI_REGISTRY # < NOT A TYPO
```


* Create another repo and put the `prisma-containerized-scan.txt` file in it. 
* Retrieve the `<GITLAB_PROJECT_NUMBER>` for the repo you put the `prisma-containerized-scan.txt` file in. 
* Create an access key and a secret key in the prisma console under settings > access keys
* Retrieve the Compute API URL under Compute > system > utilities under the path to console field

### In the repo you're creating the pipeline

* Save the access key in Gitlab secrets manager as $PC_ACCESSKEY
* Save the secret key in Gitlab secrets manager as $PC_SECRETKEY
* Save the Compute API URL in Gitlab's repo secrets manager as $TL_CONSOLE
* Copy the below codeblock into the gitlab CICD pipeline script and ensure you edit the pipeline and replace any values in `<>` specifically `<CERT_FILE_FOR_GITLAB_RUNNER_NECESSARY_FOR_GITLAB_CONSOLE>`, `<GITLAB_PROJECT_NUMBER>`, and `<FQDN_OF_GITLAB>`
* Every other variable in this pipeline is native to GITLAB

### See the documentation where we created this pipeline from 

Recommend looking them over so you're able to see what we were working with. 

* https://docs.gitlab.com/ee/ci/docker/using_kaniko.html 
* https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/tools/twistcli_scan_images.html


### The one issue we could think of that we left outstanding

Because our brains were fried after troubleshooting issue after issue after issue on this; we let our second `wget` command get a little, sloppy. When we clone the file from the other repository it comes down as `raw?ref=main` which we then rename back to it's original name `prisma-containerized-scan.txt`. I can confirm in all of our testing there were zero issues with this, but it is a noteable unnecessary step that is due to us not diving too far into wget. 

```yaml
image:
  name: gcr.io/kaniko-project/executor:debug
  entrypoint: [""]
stages:
  - scan-build
  - push-build

scan-build:
  stage: scan-build
  before_script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$CI_REGISTRY\":{\"auth\":\"$(echo -n ${CI_REGISTRY_USER}:${CI_REGISTRY_PASSWORD} | base64 | tr -d '\n')\"}}}" > /kaniko/.docker/config.json
    - cat ./<CERT_FILE_FOR_GITLAB_RUNNER_NECESSARY_FOR_GITLAB_CONSOLE>  >> /kaniko/ssl/certs/additional-ca-cert-bundle.crt
  script:
    - |
      wget --header "Authorization: Basic $(echo -n $PC_ACCESSKEY:$PC_SECRETKEY | base64 | tr -d '\n')" "$TL_CONSOLE/api/v1/util/twistcli"; chmod a+x twistcli; # brings down the twistcli tool
      wget --header "PRIVATE-TOKEN: ${GITLAB_PASSWORD}" "https://<FQDN_OF_GITLAB>/api/v4/projects/<GITLAB_PROJECT_NUMBER>/repository/files/prisma-containerized-scan.txt/raw?ref=main" # GITLAB_PASSWORD/TOKEN needs global permissions or at least permissions to pull from other repos. Only applies to private repos
    - IMAGE_NAME="${CI_DEFAULT_BRANCH}--${CI_COMMIT_SHA}"
    - mv raw?ref=main prisma-containerized-scan.txt # rename the file that comes down ----needs to be updated and fixed. Probably issue with the wget command.
    - cat prisma-containerized-scan.txt >> ./Dockerfile #adds the twistcli container scanning file to the Dockerfile prior to the build
    - sed -i "s/PC_ACCESSKEY/$PC_ACCESSKEY/g" ./Dockerfile # Securely ensures that the env variables are injected only when the build happens. 
    - sed -i "s/PC_SECRETKEY/$PC_ACCESSKEY/g" ./Dockerfile # No need to store anything sensitive in the other repo that contains the prisma-containerized-scan.txt file
    - sed -i "s/TL_CONSOLE/$TL_CONSOLE/g" ./Dockerfile
    - sed -i "s/CI_REGISTRY/$CI_REGISTRY/g" ./Dockerfile
    - |-
       KANIKOPROXYBUILDARGS=""
       KANIKOCFG="{\"auths\":{\"$CI_REGISTRY\":{\"auth\":\"$(echo -n ${CI_REGISTRY_USER}:${CI_REGISTRY_PASSWORD} | base64 | tr -d '\n')\"}}}"
       if [ "x${http_proxy}" != "x" -o "x${https_proxy}" != "x" ]; then
         KANIKOCFG="${KANIKOCFG}, \"proxies\": { \"default\": { \"httpProxy\": \"${http_proxy}\", \"httpsProxy\": \"${https_proxy}\", \"noProxy\": \"${no_proxy}\"}}"
         KANIKOPROXYBUILDARGS="--build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} --build-arg no_proxy=${no_proxy}"
       fi
       KANIKOCFG="${KANIKOCFG} }"
       echo "${KANIKOCFG}" > /kaniko/.docker/config.json
    - /kaniko/executor --context $CI_PROJECT_DIR --dockerfile $CI_PROJECT_DIR/Dockerfile $KANIKOPROXYBUILDARGS --no-push #builds the container without pushing to container repo

push-build:
  stage: push-build
  needs:
    - scan-build # makes this stage dependent upon the stage before
  before_script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$CI_REGISTRY\":{\"auth\":\"$(echo -n ${CI_REGISTRY_USER}:${CI_REGISTRY_PASSWORD} | base64 | tr -d '\n')\"}}}" > /kaniko/.docker/config.json
    - cat ./<CERT_FILE_FOR_GITLAB_RUNNER_NECESSARY_FOR_GITLAB_CONSOLE> >> /kaniko/ssl/certs/additional-ca-cert-bundle.crt
  script:
    - IMAGE_NAME="${CI_DEFAULT_BRANCH}--${CI_COMMIT_SHA}"
    - |-
       KANIKOPROXYBUILDARGS=""
       KANIKOCFG="{\"auths\":{\"$CI_REGISTRY\":{\"auth\":\"$(echo -n ${CI_REGISTRY_USER}:${CI_REGISTRY_PASSWORD} | base64 | tr -d '\n')\"}}}"
       if [ "x${http_proxy}" != "x" -o "x${https_proxy}" != "x" ]; then
         KANIKOCFG="${KANIKOCFG}, \"proxies\": { \"default\": { \"httpProxy\": \"${http_proxy}\", \"httpsProxy\": \"${https_proxy}\", \"noProxy\": \"${no_proxy}\"}}"
         KANIKOPROXYBUILDARGS="--build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} --build-arg no_proxy=${no_proxy}"
       fi
       KANIKOCFG="${KANIKOCFG} }"
       echo "${KANIKOCFG}" > /kaniko/.docker/config.json
    - /kaniko/executor --context $CI_PROJECT_DIR --dockerfile $CI_PROJECT_DIR/Dockerfile $KANIKOPROXYBUILDARGS --destination $CI_REGISTRY_IMAGE:$IMAGE_NAME # Pushes the scanned container to controlled artifact repo/container reg
```
### Where and Why Kaniko Though?
Addition by Chase Christensen from Insight

Running a distributed system at scale is all about embedding the requirements into your development culture. Bryan Finster (Defense Unicorns https://bdfinst.medium.com/ for more knowledge bombs) describes a platform as something that "cannot enforce creativity, only repeatability" in his section "Hardening the Value Stream" in the book "Modern Cybersecurity: Tales from the Near-Distant Future". 

OK, but what does that mean for our platforms and how does that apply to a distributed system as a whole? Good question! The answer is that we want security to be massaged into the developer process and part of the organizational cultural artifact depicted as our platform. A platform can be described as the "optimal path from development to production" but it is so much more. The platform itself is a set of values and risks the orgs has willingly defined and presented to their clients (clients as in customers and clients as in the development team who should be intimately involved in the platform's constitution). Kaniko right now is a business decision to not trust any container until it has been rootleslly built and ruthlessly thrown through our security gauntlet. A prime use case is pulling in a 3rd party application into your DMZ registry, using Kaniko to build, Twistlock to scan, and some pipeline tool (we use Gitlab) to bring in other tools to validate artifact before Kaniko gets the go ahead to push the container to a whitelisted registry. You can use an Open Policy Agent (a feature included in Prisma!) to enforce only allowing Kubernetes to pull from the secured registry. 

It is also worth noting that the artifact (even in the “secure” registry) is still a risk. New CVEs come in every day, and CVE whack a mole requires human readable metrics, and business decisions. Some CVEs may remain in play longer than the business is willing to accept them (something Prisma can also help you do), and then the “pivot vs. patch” philosophy that tools like BuildPacks or a properly executed pipeline kick in to help the organization make their move. The registry must be scanned, and the artifact must be monitored in it’s deployed form in any environment (this is where you defenders come in).  

So…why did I go through all that? Well, I just gave you a giant laundry list of things to worry about, and Kaniko (seen above) is kind of gross. How can we enforce scanning and promoting of our code within our environment as a cultural norm? Something like putting your pants on before going outside. You know why you do it and you do it effortlessly cause its part of the culture you consume daily.  We also have the issue that we do not want duplicate code or snowflakes in an already config heavy system. Configuration errors are failure in “repeatability”. Secure and hermetic builds are a foundation to artifact creation, so we want this to be less of a giant script you bring to your CI file and more of something you bring in as a service when you need it. Let’s walk through how we did this. 

### Insight Research and Innovation Hubs Kaniko Test Kitchen Experiment

For those unfamiliar, the Research and Innovation Hubs (at Insight) can be best described as a test kitchen for new solutions and methodologies. 70% of IT professionals learn through doing( See Sushila Nair's section Reinventing the Cybersecurity Workforce in Modern Cybersecurity Tales from the Near-Distant Future for more details on that! (seriously good book) ), and Insight believes that you need to be in the arena with your partners (Palo Alto Networks being a major one) and develop the client journey yourself before you bring platform teams along. Hence our Kaniko build. The Data Center as Code environment is the environment we use to build out cloud native solutions. 

We leverage Flux and Gitlab as our core CI/CD components.  We have 2 repositories for each “tenant”. One repository for the manifests (shared by the developers and SREs), and one for pre-artifact code (the guts of the container that he API is serving up).  We are going to push code to the developer repository, the developer repository will trigger our CI file, and begin our gauntlet. Once finished, Kaniko will tag the artifact (based on our commit message) and push that artifact to our container registry. Then Flux takes over by looking for new artifacts and using a regex and some automation magic (for another collaboration post 😉) to find the “latest” release and update the shared (dev and ops) Kubernetes manifests.  Flux sees the updated manifest change and SHAZAM we have a new deployed artifact being monitored by our cluster defenders! 

So we have 3 phases:

1. Kaniko-scan
2. Semantic Update 	
3. Kaniko-push

Kaniko scan looks like this 
```yaml
mkdir -p /kaniko/.docker
echo "{\"auths\":{\"$CI_REGISTRY\":{\"auth\":\"$(echo -n ${CI_REGISTRY_USER}:${CI_REGISTRY_PASSWORD} | base64 | tr -d '\n')\"}}}" > /kaniko/.docker/config.json
wget --header "Authorization: Basic $(echo -n $PC_ACCESSKEY:$PC_SECRETKEY | base64 | tr -d '\n')" "$TL_CONSOLE/api/v1/util/twistcli"; chmod a+x twistcli;
wget --header "PRIVATE-TOKEN: ${GITLAB_PASSWORD}" "https://gitl-host.<your_domain>/api/v4/projects/<twistlock_injection_script_project_ID>/repository/files/prisma-scan.txt/raw?ref=main"
mv raw?ref=main prisma-scan.txt
cat prisma-scan.txt >> ./Dockerfile
sed -i "s/SCANIMAGE/$CI_PROJECT_TITLE/g" ./Dockerfile
sed -i "s/PRISMAPASSWORD/$PC_SECRETKEY/g" ./Dockerfile
sed -i "s/PRISMAUSER/$PC_ACCESSKEY/g" ./Dockerfile
KANIKOPROXYBUILDARGS=""
KANIKOCFG="{\"auths\":{\"$CI_REGISTRY\":{\"auth\":\"$(echo -n ${CI_REGISTRY_USER}:${CI_REGISTRY_PASSWORD} | base64 | tr -d '\n')\"}}}"
       if [ "x${http_proxy}" != "x" -o "x${https_proxy}" != "x" ]; then
         KANIKOCFG="${KANIKOCFG}, \"proxies\": { \"default\": { \"httpProxy\": \"${http_proxy}\", \"httpsProxy\": \"${https_proxy}\", \"noProxy\": \"${no_proxy}\"}}"
         KANIKOPROXYBUILDARGS="--build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} --build-arg no_proxy=${no_proxy}"
       fi
KANIKOCFG="${KANIKOCFG} }"
echo "${KANIKOCFG}" > /kaniko/.docker/config.json
#this should only run if the above doesn't fail!
 mkdir /tmp
/kaniko/executor --context $CI_PROJECT_DIR --dockerfile $CI_PROJECT_DIR/Dockerfile $KANIKOPROXYBUILDARGS --no-push
```
Kaniko Push looks like this: 

```yaml
echo "Starting process to push $IMAGE_NAME "
mkdir -p /kaniko/.docker
echo "{\"auths\":{\"$CI_REGISTRY\":{\"auth\":\"$(echo -n ${CI_REGISTRY_USER}:${CI_REGISTRY_PASSWORD} | base64 | tr -d '\n')\"}}}" > /kaniko/.docker/config.json
KANIKOPROXYBUILDARGS=""
KANIKOCFG="{\"auths\":{\"$CI_REGISTRY\":{\"auth\":\"$(echo -n ${CI_REGISTRY_USER}:${CI_REGISTRY_PASSWORD} | base64 | tr -d '\n')\"}}}"
       if [ "x${http_proxy}" != "x" -o "x${https_proxy}" != "x" ]; then
         KANIKOCFG="${KANIKOCFG}, \"proxies\": { \"default\": { \"httpProxy\": \"${http_proxy}\", \"httpsProxy\": \"${https_proxy}\", \"noProxy\": \"${no_proxy}\"}}"
         KANIKOPROXYBUILDARGS="--build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} --build-arg no_proxy=${no_proxy}"
       fi
KANIKOCFG="${KANIKOCFG} }"
echo "${KANIKOCFG}" > /kaniko/.docker/config.json
wget --header "PRIVATE-TOKEN: ${GITLAB_PASSWORD}" "https://git_host.<your_domain>/api/v4/projects/<kaniko_scripts_projectID>/repository/files/git_host.<your_domain>.crt/raw?ref=main"
mv raw?ref=main e4cent0git_host.datalinklabs.local.crt
cat ./git_host.<your_domain>.crt  >> /kaniko/ssl/certs/additional-ca-cert-bundle.crt
/kaniko/executor --context $CI_PROJECT_DIR --dockerfile $CI_PROJECT_DIR/Dockerfile $KANIKOPROXYBUILDARGS --destination $CI_REGISTRY_IMAGE:$IMAGE_NAME
```
These files are stored in a seperate registry from our demo application. The demo application has a CI file that looks like this: 

```yaml
stages: 
  - build-scan 
  - semantic-update
  - build-push
build-scan:
  image:
    name: git_host.<your_domain>:5050/eden-prairie-hub/kaniko:1.7.0 
    entrypoint: [""]
  stage: build-scan 
  before_script: 
    - |
      wget --header "PRIVATE-TOKEN: ${GITLAB_PASSWORD}" "https://git_host.<your_domain>/api/v4/projects/<kaniko_scripts_projectID>/repository/files/kaniko-scan.sh/raw?ref=main"
       mv raw?ref=main kaniko-scan.sh
       chmod +x kaniko-scan.sh
  script:
    - sh ./kaniko-scan.sh 
semantic-update:
  image:
    name:  git_host.<your_domain>:5050/eden-prairie-hub/ubuntu-utility:18.04
    entrypoint: [""]
  stage: semantic-update
  needs:
    - build-scan
  before_script: 
    - |
      wget --header "PRIVATE-TOKEN: ${GITLAB_PASSWORD}" "https://git_host.<your_domain>/api/v4/projects/<kaniko_scripts_projectID>/repository/files/semantic-update.bash/raw?ref=main"
       mv raw?ref=main semantic-update.bash
       chmod +x semantic-update.bash
  script:
    - bash ./semantic-update.bash #make sure to run this with bash
  only:
    variables:
      - $CI_COMMIT_MESSAGE =~ /RELEASE/
build-push:
  image:
    name: git_host.<your_domain>:5050/eden-prairie-hub/kaniko:1.7.0
    entrypoint: [""]
  stage: build-push
  needs:
    - semantic-update
  before_script: 
    - |
      wget --header "PRIVATE-TOKEN: ${GITLAB_PASSWORD}" "https://git_host.<your_domain>/api/v4/projects/<kaniko_scripts_projectID>/repository/files/kaniko-push.sh/raw?ref=main"
      mv raw?ref=main kaniko-push.sh
      chmod +x kaniko-push.sh
  script:
    - sh ./kaniko-push.sh 
  only:
    variables:
      - $CI_COMMIT_MESSAGE =~ /RELEASE/ #checks for RELEASE in the CI message 
```
We do a branch per release so we can even cherry pick the build and runner versions just in case. More details on that can be found in https://sre.google/sre-book/release-engineering/. Insight and Prisma cloud strongly believe that release engineering is core to hermetic builds and secure pipelines. Maybe just like we added sec to devops to voltron us a DevSecOps titan, we can now say SECURE Release Engineering as a best practice. Hermetic builds, translatable metrics, and well undertsood software bill of materials.

We now know every image we used in our pipeline because they all went through the ringer and we have them within our own regisitry if we need to leverage them again at a later date. Even the ones we used to build the containers! 

The semantic-update phase pulls our utility container ( a container with specific tools on it since we want to keep Kaniko has clean as lean as possible) to update our CI/CD variables in Gitlab. Even the semantic versioning is handled by our script. Part of our platforms cultural capital. Keep the developers developing and not double checking versions etc.. let that policy be enforced by our pipeline. 

Environment Variables You Need to Worry About:

* `$TL_CONSOLE` = Path to the Prisma Cloud Compute URL found in documentatation here: https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/tools/twistcli_scan_images.html
* `$GITLAB_CRED` = Token to access our kaniko project
* `$GITLAB_USER` = User to access our kaniko project
* `$IMAGE_NAME` =  Tag of the image to be created by kaniko push. This is updated by our semantic versioning script
* `$PC_SECRETKEY` = Prisma Cloud Secret key created along with the Access Key in the console
* `$SEM_VERSION` = Current application version
* `$PC_ACCESSKEY` = Prisma Cloud Access key created along with the Secret Key in the console.  

The other ENV variables are part of Gitlab. Check out https://docs.gitlab.com/ee/ci/variables/ for more details 🛰️.

There is a lot to unpack when it comes to secure release engineering, but rootless containers are just the tip of the iceberg. Kubernetes offloads its actual work to all sorts of interfaces. The Container Runtime Interface (CRI) being the interesting one here. Docker is actually a root daemon that you make calls to in order to make child processes ( ROOT child processes!) that we call containers. Kyle shared with me this post: https://redo.readthedocs.io/en/latest/cookbook/container/ that really helps demystify containers. Understanding how your platform runs your containers and securing the hosts themselves is the next step. Stop disabling SE Linux and start scanning your hosts just like you do your containers! That discussion is for another day when we discuss some of the BridgeCrew integrations the teams have been working on. Thanks for reading and feel free to reach out with any questions about the proceses or the decisions behind them! 

