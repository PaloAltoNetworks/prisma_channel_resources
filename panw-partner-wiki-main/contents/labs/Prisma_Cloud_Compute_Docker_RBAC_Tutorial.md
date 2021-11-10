## Purpose:

To provide a "why" behind incorporating this feature and to provide a practical working example of implementation. 

## Prerequisites: 

* Prisma Cloud Compute Deployed with a container defender deployed (Created with version 21.04).
* Docker installed

## Why is this important? 

This is an incredibly useful feature for Prisma Cloud Compute and if operationalized correctly it has the potential to greatly increase the security for an organization which utilizes the docker engine. I've written a tutorial outlining why one might want to incorporate this into their workflow. See [Show why running a container in privilaged mode can create a risk](https://pa-partner-wiki.ml/Demo%20Security%20Risks%20of%20Running%20a%20Docker%20Container%20in%20Privileged%20Mode.md). This capability is also useful to incorporate the zero-trust principle into container operations as it pertains to the least privilege principle. 

## Where this might make sense because of the organizational security policies:

On the developer's machines who are creating containers. Create policies that restrict from pulling container images from public registries; etc. 

## Where this definitely makes sense. 

Any vms/hosts utilizing the docker engine in staging or production environments. Not best practice to be using docker!
Any vms/hosts where the docker api is exposed. 

## How-to deploy:

* Step 1: Log into your Prisma Cloud Compute console
* Step 2: Go to Manage > Defenders 
* Step 3: On the Manage Tab select the Defenders subtab. Click the Actions `...` button and then the "Edit" button to bring up the container defender configuration. Turn on the setting "Set Defender as a TCP listener". Then hit save. 
* Step 4: On the left-hand side of the page under the Manage menu click the "Authentication" sub menu and then click the "User certificates tab" in the middle of the page. 
* Step 5: Copy the script to install the Client certificate, client private key, and the ca certificate. 
* Step 6: Open terminal and paste the script into the terminal window. 
* Step 7: In terminal run the following command `docker --tlsverify -H <COMPUTE_CONSOLE_HOSTNAME>:9998 ps`. You should see the action is denied based on the Default rule - deny all. 


## How-to-set-up for your demo in a box env: 

* Run these commands to make things more useful and usable:

```bash
cd $HOME
echo "export DOCKER_HOST=tcp://<COMPUTE_CONSOLE_HOSTNAME>:9998" >> .bashrc
echo "export DOCKER_TLS_VERIFY=1" >> .bashrc
echo "alias docker ='docker --tlsverify -H <COMPUTE_CONSOLE_HOSTNAME>:9998'" >> .bashrc
source .bashrc
```

* Now you can try running a simple docker command on your machine:

`docker ps`

* You should see the same error as you saw when you intially ran this before. 
* Combine this with other host runtime rules and you have a very secure docker environment. 
* You can work on tuning and adjusting the rules based on Groups and Policies. 
* The policies can be found in the Prisma Compute Console under Defend > Access under the "Docker" tab. 

Offical Documentation around this feature can be found: 
https://docs.twistlock.com/docs/compute_edition/access_control/rbac.html 


## Wait though, a developer can secure the docker daemon without Prisma Cloud Compute, so why do this process?

[Docker Documentation on how to secure the docker daemon (without Prisma Compute)](https://docs.docker.com/engine/security/protect-access/)

A well informed security minded developer will point to the documentation above and probably argue the value of this feature. What I'd point out is that following these security best practices isn't enabling "DevSecOps" but rather good developer hardening guidelines. The problem here is the lack of visability and auditability for other departments in the organization who require this information. A lot of what Prisma Cloud Compute is meant to do is provide visability and control to the IT team. DevSecOps is catering to everyone involved in managing technology, not just the development team. All of the features in this tutorial work hand-in-hand with the security recommendations outlined in the docker documentation above. 

Another important thing to keep in mind is the documentation above handles authentication but not authorizations, which is a critical differentiator for this feature. 

Hopefully you find this tutorial useful I'll look forward to any feedback you may have. 

