# Prisma Cloud Code Security Self Hosted Version Control System (or Source Control Management System) CI Scan
written by Kyle Butler

This tutorial builds on the knowledge gained in the container ci scanning demo which you
can find [here](https://github.com/PaloAltoNetworks/prisma_channel_resources/blob/main/lab_deploy/ci_vulnerability_lab_guide.md).

If you haven't completed that full tutorial. I'd highly recommend working
through that one first as it will introduce you to the basic concepts of CI and
working with drone. 


## Goal

To teach engineers how to configure an IaC scanning test for use in a CI pipeline. This should be useful when an organization is using a self-hosted, non-offically supported, version control system (VCS)/source control management system (SCM).

## Requirements and Assumptions

* You've already ran through the [container scanning tutorial](https://github.com/PaloAltoNetworks/prisma_channel_resources/blob/main/lab_deploy/ci_vulnerability_lab_guide.md).
* You're working in the [Prisma Compute Lab environment](https://github.com/PaloAltoNetworks/prisma_channel_resources/tree/main/lab_deploy). 
* Drone, git, gitea, and docker are all locally installed and configured. 
* You have an enterprise edition of Prisma Cloud Enterprise with the Code Security module enabled. 
* You have configured `git` to authenticate with your gitea server.
* Gitea server is available at `http://gitea:3000`
* Drone is available at `http://drone:8000`


## Set-up

### Step 1: Create and save access keys, secret keys, and prisma cloud api url

* Create a set of access keys and secret keys in the prisma cloud console.
    Settings > Access Control > Access Keys
* Retrieve the corresponding api url for your Prisma Cloud tenent (ie. if on
    app2.prismacloud.io then it should be api2.prismacloud.io) Documentation
    [here](https://prisma.pan.dev/api/cloud/api-urls)
* Open your browser and navigate to http://drone:8000
* Click the prisma-presenter/bridgecrew_self_hosted_version_control_ci
    repository
* Create three secrets and add the corresponding values:

   * `prisma_api_url` Secret one. The value should be the api url you copied down from above. Example value: `https://api2.prismacloud.io`
   * `prisma_access_key` Secret two. The value should be your access key you created earlier.
   * `prisma_secret_key` Secret three. The value should be your secret key you created earlier.

### Step 2: Create a repo in Gitea and create a local copy. 

* Navigate to Gitea 
* Click the `+` symbol next to the profile icon and select create a new repository. 
* Provide a name for the repository. Recommending no spaces in the name. 
* Select default readme. 
* Hit create. 
* Clone the reposoitory. (If using the ova ssh keys have been set-up and enabled). If not use the http method as outlined below. First, open terminal and enter the commands below:

  * `cd $HOME` - ensure's your in your users HOME directory
  * `mkdir Projects` - creates a Projects directory
  * `cd Projects/` - changes the directory to the Project directory
  * `git clone <YOUR_REPO_URL>` - this will clone the files from your repo to a local directory with the same name as your repo
  * `cd <REPO_NAME_DIRECTORY>`
  * `git clone https://github.com/bridgecrewio/terragoat` - adds demo IaC files to your repo
  * `cd terragoat` - changes directory to the terragoat repo directory
  * `rm -rf .git` - removes the .git directory from terragoat
  * `cd ..` - changes the directory to the local repo directory
  * `git add .` - stages all the changes in your local copy of the repo
  * `git commit -m "added terragoat directory"` 
  * `git push` - provide your gitea username and password, pushes the changes back to the repository

Once you've completed the steps above, move on to the next section Choose a pipeline. 

## Choose a pipeline

Instead of teaching you how to build a pipeline I'm going to provide three
different examples which hopefully cover a number of situations for pipeline set-up. All
you need to do in order to run the demo is, create a file in your local repo directory named `.drone.yml` with the same code block from the examples below and then commit the file back to the master branch. The commands to run after you read through the different Pipeline example are provided in the last section. 


### Pipeline 1: Using the BridgeCrew container as a runner

Since drone uses containers as runners this is by far the easiest to use. Keep
in mind that drone isn't unique as a CI tool and this isn't a unique feature.
Gitlab and others also use containers for runners. The first example pipeline
uses the bridgecrew container image to do the scan. It looks like this:

```yaml
---
kind: pipeline
type: docker
name: self-hosted_iac_scan_demo

steps:
- name: IaC_CI_CONFIG_SCAN
  image: bridgecrew/checkov:latest
  environment:
    PRISMA_API_URL:
      from_secret: prisma_api_url
    PRISMA_ACCESS_KEY:
      from_secret: prisma_access_key
    PRISMA_SECRET_KEY:
      from_secret: prisma_secret_key
  commands:
    - checkov -d terragoat --bc-api-key $PRISMA_ACCESS_KEY::$PRISMA_SECRET_KEY --repo-id $DRONE_REPO
```

Breaking this pipeline down, we can see it's pretty easy. All we're doing is
declaring the container image where the test should be run. In this case,
we're using bridgecrew/checkov:latest. Because all the
dependencies are already in the `bridgecrew/checkov:latest` container image, there really isn't much to do but run
the scan using the `checkov` command: `checkov -d terragoat --bc-api-key $PRISMA_ACCESS_KEY::$PRISMA_SECRET_KEY --repo-id $DRONE_REPO`. 


### Pipeline 2: Using Python container as runner

This pipeline syntax is useful if the customer is using a runner where you know
two things: One, `python3` is available and installed on the runner and `pip3` is
also installed. 


```yaml
---
kind: pipeline
type: docker
name: self-hosted_iac_scan_demo

steps:
- name: IaC_self_hosted_python_runner_container_ci_scan
  image: python:latest
  environment:
    PRISMA_API_URL:
      from_secret: prisma_api_url
    PRISMA_ACCESS_KEY:
      from_secret: prisma_access_key
    PRISMA_SECRET_KEY:
      from_secret: prisma_secret_key
  commands:
    - pip3 install checkov
    - checkov -d terragoat --bc-api-key $PRISMA_ACCESS_KEY::$PRISMA_SECRET_KEY --repo-id $DRONE_REPO
```


The upper part of this pipeline isn't really the part you should pay attention
to, but rather the commands. In this scenario all we need to do is, use `pip3`
(python3 package manager) to install `checkov` and then run our `checkov` command
as we did before. 

But what if we don't know if `python3` is available and if pip3 is installed on
the runner? Enter the last pipeline example...

### Pipeline 3: Using an Ubuntu box/container as a runner. 

Okay, so if you don't know whether `python3` or `pip3` is available on the runner, then
you'll need to do a tiny bit of homework. The first thing you'll need to know is,
which package manager the runner OS uses. In this case, we know that `Ubuntu`
uses `apt` as the default package manager.

Other examples: `Mac OS` = `brew`, `RHEL` = `yum`, `Alpine` = `apk` etc. 

Each package manager utilizes slightly different syntax, but the process is the same.
`update` --retrieves the information about what packages can be installed and
then `install` --installs the package. 

So for `ubuntu`, we use `apt update` followed by a `&&` and then `apt install -y python3 pip3`, which installs the two packages we need `python` and the python package manager `pip3`. Then using `pip3`, we install the `checkov` python tool! 


```yaml
---
kind: pipeline
type: docker
name: self-hosted_iac_scan_demo

steps:
- name: IaC_self_hosted_python_runner_container_ci_scan
  image: ubuntu:latest
  environment:
    PRISMA_API_URL:
      from_secret: prisma_api_url
    PRISMA_ACCESS_KEY:
      from_secret: prisma_access_key
    PRISMA_SECRET_KEY:
      from_secret: prisma_secret_key
  commands:
    - apt update && apt install -y python3 python3-pip
    - pip3 install checkov
    - checkov -d terragoat --bc-api-key $PRISMA_ACCESS_KEY::$PRISMA_SECRET_KEY --repo-id $DRONE_REPO
```

From there the process is the same. We simply run the same `checkov` command as before.


## See it work and run the demo

Okay, so you've read everything above and it makes sense right? It's all pretty
straight forward. We simply need to be able to allow `outgoing` traffic to
the prisma cloud console and we need to be able to ensure that we can get our
dependencies to the runner. Our dependencies for this test are: `python3`, `pip3`, and `checkov`. That's it!

Here's commands you'll use:

* (assuming you're still in your <REPO_NAME_DIRECTORY>) `touch .drone.yml` creates a hidden file named `.drone.yml`
* `nano .drone.yml` opens the `nano` editor and the `.drone.yml` file. 
* copy one of the code blocks from the Pipeline examples below. 
* paste the contents into the `.drone.yml` file
* `ctrl + X` on your keyboard; then hit `y` followed by `enter` - will save your changes in the `.drone.yml` file
* `git add .` - stages the changes in your local directory
* `git commit -m "added drone IAC pipeline test"` - provides human readable message on what changed
* `git push` - provide your gitea username and password to push the changes back to the repository. 

Once that's done, go back to your drone webpage http://drone:8000. 

Click the repository you created earlier, ensure that everything has been activated and that the secrets are entered, then click the builds link in drone. 

Click your build which should be the same name as your commit message. And watch
the scan fail due to you having the terragoat repository in your repo! 

You can now see your scans in the Prisma Cloud Console under Code Security >
Projects! Woohoo! Self-hosted weird version control system is now able to be
seen anytime someone makes a change to the files in the repo. That's it!

Congrats!
