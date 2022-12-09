# Prisma Cloud and XDR Better together Story

Written by Kyle Butler in collaboration with Jamie Hodge, Chris Harris, Brandon Goldstein, Goran Bogojevic, David Maclean, Nana-Ampofo, Calvin Mangubat, Steven de Boer, Ben Nicholson, Scott Coleman, Gareth Baruch, H.S. Song, and John Chavanne. (FYI, if you'd like to collaborate with us, we'll add your name to this list.)

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

## Finding #6 

We were able to successfully integrate Prisma Cloud and XDR. Both solutions now have the ability to easily integrate with one another within a matter of minutes. 

In XDR:

* Go to Settings
* Click Configurations
* Under the Collection menu, click collection integrations
* Select the Prisma Cloud Compute integration
* Provide a name, save and generate token. Copy Token username and Password. 

In Prisma Cloud: 

* Click Manage
* Click Alerts
* Click Add Profile
* Put a name in like `XDR`
* For provider choose Cortex
* Under Application XDR 
* Grab the webhook URL provided by Cortex XDR
* Click add credentials and put in the username and token generated earlier. 
* Choose your alert triggers
* Click send test alert. 


## Finding #7

Customers which have XDR installed on end user devices can quickly export network lists to enhance Prisma Cloud Compute and the Enterprise editions functionality. Quickly able to update trusted IP's and define network objects outside of the workloads with defenders on them. 

In XDR: 

* Click endpoints list 
* Click All endpoints

Or in the Query section in XDR use this: 

```
dataset = endpoints
| fields endpoint_name, ip_address as IP
```

I'll write up a sample API script and post it here in a bit. 


## Finding #8 - Thank you Steven de Boer!!! - Ability to allow XDR agent access to tools which are considered malicous by default Prisma Runtime Rules. 

So here's the scenario. In the default Host policy runtime rules under networking and spoofing ncat comes up as a tool that could be used for these purposes. However, the XDR utilizes ncat for forensic analysis. Steven de Boer was asked to come up with a custom rule that would allow the XDR agent to use the ncat tool but not create an alert in the Prisma Console. Here's how he did it!

* Create custom runtime rule under Defend > Runtime in the Prisma Compute console. 
* Name Allow ncat to be executed by XDR agent
* Message: `%proc.name is used, it's parent is %proc.pname`
* Rule should be: `proc.name = "ncat" and (proc.pname = "pmd")`

What this does is it allows the XDR agent access to the `ncat` tool and will ensure there's no alert generated when it uses the binary. However if a user were to attempt to use it then the alert or prevententive behavior would still occur. 

## Finding #9 - In collaboration with Brandon Goldstein (Prisma Cloud Sr. Customer Success Engineer) - Ability to deploy Cortex XDR agent and Prisma Cloud defender in K8s cluster. Thank you Brandon Goldstein!

Here's the scenario: 

Alerts on suspicous binary - audit type file system. 

Context: 

Cortex XDR is able to be deployed as a daemonset into a k8s cluster. The XDR agent writes encrypted files to a specific directory which gets flagged as suspicious by the Prisma Cloud Defender. We want to ensure that a trusted process is able to write files to a given directory path. How do you ensure there aren't alerts created and also see that the exception is logged?

Here's the process to follow:

* First create a collection scoped to the environment you'd like this policy to apply to. [Documentation](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/configure/collections)
* Then create a custom runtime rule scoped to your new collection. Under Defend > Runtime in the Prisma Cloud Console. 
* Name of the rule: Alllow trusted process XDR (pmd)
* Create a custom rule with the type: filesystem
* Set to log as Audit with the effect as alert. 
* Message should be: Trusted XDR (pmd) allowed
* Rule should be: `(proc.name = "pmd" or proc.pname = "pmd") and file.dir startswith "/opt/traps"`

This allows for the xdr agent to writes files to the directory path that starts with `/opt/traps/` and also allows the xdr agent to spawn child processes to writes files to that directory. This same process can be used of course with any trusted process in a k8s cluster where this type alert is being seen and the process in known to the organization! 



## Discussions topics we're working on. 

* Runners --- my feelings are the XDR agent may be more appropriate here. The reason being is that the runtime protection is based off of runtime modeling. Something like a runner would be difficult to model because it could argueably need to be made to do lots of things, and nearly impossible to set a baseline for. The important part about a runner is that no build should be able to change the runner or permissions on the runner itself. XDR in report only mode might be a better fit. 

* GitOps feasability with the XDR Agent - Update. Helm Chart has been created for XDR agent see the repo [here](https://github.com/PaloAltoNetworks/cortex-helm)

* Linux vs Windows machines - both agents support a number of operating systems. We're exploring the differences and will report back accordingly.

* Synergies between the two tools - we're working on practical usecases for both tools and how admins might enhance their findings from one tool to the next. Because XDR is specifically designed for the SOC we have some great ideas and will update and share once we've fully flushed them out. 

Stay tuned. 

## Useful links

* [Gartner Report on Endpoint Protection vs CWPP](https://www.gartner.com/doc/reprints?id=1-26RQNWUM&ct=210713&st=sb?utm_source=marketo&utm_medium=email&utm_campaign=Global-DA-EN-20-05-04-7010g000001JNCsAAO-P1-Prisma-2020-gartner-market-guide-cwpp)
* [Support matrix for Prisma Cloud Defenders](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/install/system_requirements.html)
* [Support matrix for XDR Agent](https://docs.paloaltonetworks.com/compatibility-matrix/cortex-xdr/where-can-i-install-the-cortex-xdr-agent) 
