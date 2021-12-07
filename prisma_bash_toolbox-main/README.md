# Prisma Bash Tool Box
[![CodeFactor](https://www.codefactor.io/repository/github/kyle9021/prisma_bash_toolbox/badge)](https://www.codefactor.io/repository/github/kyle9021/prisma_bash_toolbox)


## A collection of bash scripts/tools to assist engineers with the day-to-day maintenance and reporting for Prisma Cloud. 

Disclaimer:

This is a community toolkit and IS NOT supported nor maintained by Palo Alto Networks. Please review license before using. 


## Requirements:

* Linux/Unix shell. All instructions will be written for a debian/ubuntu distro. 
* Jq

## How to use:

* install jq `sudo apt-get install jq`
* clone the repo `git clone https://github.com/PaloAltoNetworks/prisma_channel_resources`
* `cd ./prisma_channel_resources/prisma_bash_toolbox-main/`
* add the `./secrets/secrets` file to .gitignore
* `chmod 700 ./secrets/secrets`
* create a set of access keys and secret keys in the prisma cloud console
* retrieve both api urls for the console 
* `TL_CONSOLE_URL` can be found under Compute > System > Utilities as `Path to Console` or is the url you use to navigate to the self-hosted edition of the platform. 
* `PC_CONSOLE_URL` can be found here: https://prisma.pan.dev/api/cloud/api-urls
* `PC_ACCESSKEY` is self explanitory
* `PC_SECRETKEY` is self explanitory 
* `TL_USER` is either the access key you created above or if using the self hosted version of the platform a `CI user` username.
* `TL_PASSWORD` is either the secret key you created above or if using the self hosted version of the platform a `CI user` password.
* edit the secrets file and assign the variables as needed. 

Each Script Has it's own set of variables which need to be assigned prior to running them. 

* edit the script you'd like to run (for self-hosted versions ensure that `curl` is ran with `-k` if using the default deployment method)
* run! modify enjoy!


I'll add more later


