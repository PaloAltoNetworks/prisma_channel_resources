# Prisma Cloud and XDR Better together Story

Written by Kyle Butler in collaboration with Jamie Hodge, Chris Harris, Goran Bogojevic, and John Chavanne. (FYI, if you'd like to collaborate with us, we'll add your name to this list.)

We've been working with a Cortex SE to work through some of the major technical differences between the way the XDR agent works vs. the Prisma Defender, so that we can work through some of the technical nuances when installing both agents, and determine the best agent to use when the customer might be unwilling to deploy both the defender and the XDR agent. This will be a work in progress and will be updated everyone collaborating on this topic is satisfied. 


## Finding #1

Deploying the XDR agent and the Prisma Defender on the same host machine can create a lot of noise in the Prisma Compute Console if a runtime policy isn't created beforehand. To solve for this follow the documentation in the link [here](https://docs.paloaltonetworks.com/prisma/prisma-cloud/21-08/prisma-cloud-compute-edition-admin/configure/custom_feeds.html#_custom_feeds_create-a-list-of-trusted-executables) and check out the information below!

* Log into the Prisma Cloud Console
* Go to the compute (enterprise edition only) tab.
* Under Defend > Runtime > Host Policy create a new policy named:  `allow XDR`
* Under the allowed processes by path enter the following:
1. `/opt/traps/bin/pmd`
2. `/opt/traps/bin/dypd` 
3. `/opt/traps/analyzerd/analyzerd` 
4. `/opt/traps/ltee/lted`
* Ensure scope and collections are set to ALL

## Finding #2

The Prisma WAAS functionality is better suited to protect exposed APIs and WebApps from OWASP top 10 attacks. This is because the WAAS operates at runtime, effectively blocking malicious requests prior to them being processed; whereas the XDR agent looks at events that have ran and then responds. This can easily be demonstrated on the DVWA doing a SQL injection attack with the SQL Injection prevention turned on for using Prisma WAAS and an XDR agent installed on the host. 

For Command Injection where we created a reverse shell connection, we found the WAAS blocks the attack which never allows the connection to be made. XDR in contrast stops the connection after the fact. The amount of time that the connection is allowed is near nil. 

## Finding #3

The Cortex XDR agent has more robust capabilities in regards to users workstations. Where an XDR admin has the ability to remotely connect to any machine with the XDR agent installed on it. Allowing full access to the administrator to audit things in real-time. 

## Finding #4

While Cortex XDR has some lightweight capabilities on cloud inventory, it's limited to showing you only what resources are in your cloud account, whether the resource is up and running, and the network information (internal, external ip). Whereas in Prisma Cloud you can get all that information and have visability to whether or not the resource has been configured in a way that would create vulnerabilities/violate compliance frameworks. 

## Finding #5 

Aporeto/MicroSegmentation in Prisma Cloud is incompatibile with the XDR agent. See the documentation listed here: https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-microsegmentation/start/enforcer/reqs.html

## Discussions topics we're working on. 

* Runners --- my feelings are the XDR agent may be more appropriate here. The reason being is that the runtime protection is based off of runtime modeling. Something like a runner would be difficult to model because it could argueably need to be made to do lots of things, and nearly impossible to set a baseline for. The important part about a runner is that no build should be able to change the runner or permissions on the runner itself. XDR in report only mode might be a better fit. 

* GitOps feasability with the XDR Agent - right now you have the option to deploy the XDR agent as a daemonset to a k8s cluster via a k8s manifest. This is great if you're doing manual deployments. Less useful if you're using a tool like Flux or ArgoCD to do deployments. A helm chart would need to be made from the manifest. 

* Linux vs Windows machines - both agents support a number of operating systems. We're exploring the differences and will report back accordingly.

* Synergies between the two tools - we're working on practical usecases for both tools and how admins might enhance their findings from one tool to the next. Because XDR is specifically designed for the SOC we have some great ideas and will update and share once we've fully flushed them out. 

Stay tuned. 

## Useful links

https://www.gartner.com/doc/reprints?id=1-26RQNWUM&ct=210713&st=sb?utm_source=marketo&utm_medium=email&utm_campaign=Global-DA-EN-20-05-04-7010g000001JNCsAAO-P1-Prisma-2020-gartner-market-guide-cwpp
