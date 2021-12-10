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

Building containers inside the kaniko container is spartan, to say the least. The primary challenges we faced were:

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
      wget --header "Authorization: Basic $(echo -n $USERNAME:$PASSWORD | base64 | tr -d '\n')" "$CONSOLE/api/v1/util/twistcli"; chmod a+x twistcli; # brings down the twistcli tool
      wget --header "PRIVATE-TOKEN: ${GITLAB_PASSWORD}" "https://<FQDN_OF_GITLAB>/api/v4/projects/<GITLAB_PROJECT_NUMBER>/repository/files/prisma-containerized-scan.txt/raw?ref=main" # GITLAB_PASSWORD/TOKEN needs global permissions or at least permissions to pull from other repos. Only applies to private repos
    - IMAGE_NAME="${CI_DEFAULT_BRANCH}--${CI_COMMIT_SHA}"
    - mv raw?ref=main prisma-containerized-scan.txt # rename the file that comes down ----needs to be updated and fixed. Probably issue with the wget command.
    - cat prisma-containerized-scan.txt >> ./Dockerfile #adds the twistcli container scanning file to the Dockerfile prior to the build
    - sed -i "s/PC_ACCESSKEY/$PC_ACCESSKEY/g" ./Dockerfile # Securely ensures that the env variables are injected only when the build happens. 
    - sed -i "s/PC_SECRETKEY/$PC_SECRETKEY/g" ./Dockerfile # No need to store anything sensitive in the other repo that contains the prisma-containerized-scan.txt file
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

We hope you enjoy!
