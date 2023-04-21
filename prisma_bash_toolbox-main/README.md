# Prisma Bash Tool Box
[![CodeFactor](https://www.codefactor.io/repository/github/kyle9021/prisma_channel_resources/badge)](https://www.codefactor.io/repository/github/kyle9021/prisma_channel_resources)


## A collection of bash scripts/tools to assist engineers with the day-to-day maintenance and reporting for Prisma Cloud. 

Disclaimer:

This is a community toolkit and IS NOT supported nor maintained by Palo Alto Networks. Please review license before using. 


## Requirements:

* Linux/Unix shell. All instructions will be written for a debian/ubuntu distro. 
* Jq

## How to use:

* install jq - for ubuntu: `sudo apt-get install jq` 
* install jq -for RHEL: 
```bash
sudo yum install epel-release -y
sudo yum update
sudo yum install jq
```
* clone the repo `git clone https://github.com/PaloAltoNetworks/prisma_channel_resources`
* `cd ./prisma_channel_resources/prisma_bash_toolbox-main/`
* `bash ./setup.sh`
* edit the script you want to run, then `bash ./<script_name>.sh` or `chmod a+x <script_name>.sh` and run by entering `./<script_name>.sh`

Each Script Has it's own set of variables which need to be assigned prior to running them. 

* edit the script you'd like to run (for self-hosted versions ensure that `curl` is ran with `-k` if using the default deployment method)
* run! modify enjoy!

# Security recommendations

* Recommending the user has a strong password for their account and ensuring that the permissions on the ./secrets/secrets file are set accordingly. ie `chmod 700 ./secrets/secrets`

# Errors, debugging, and known gotchas

* MacOs uses (BRE) vs Ubuntu which uses the GNU (ERE) so the function I wrote to check the validity of the secrets file fails when run on MacOS. 
   * If you're sure the secrets are entered correctly by checking the ./secrets/secrets file then you can either remove the function from the scripts `pce-var-check` or just hit `y` on your keyboard. 
* Debugging the scripts. All you need to do to get the RESPONSE code is add `-v` to any `curl` command in the script. 


