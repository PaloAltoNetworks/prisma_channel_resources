## Minikube Prisma Cloud Compute Deployment - Mini lab deployment for testing

### Purpose:

To provide engineers hands on experience working with Kubernetes and writing Docker containers. This is a beginner lab. It also provides the steps necessary to create an Dockerfile with an "app embeded defender"

### Requirements:

* If you're on Global Protect you'll need to disable for this lab - PAN Internal
* Hypervisor - [VirtualBox - Free](https://www.virtualbox.org/wiki/Downloads) or VMWare
* Prisma Cloud Compute License
* [Ubuntu VM Image 20.04 Desktop](https://releases.ubuntu.com/20.04/)
* [Docker Installed](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04)
* [Kubectl Installed - Install before installing Minikube](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
* [Minikube Linux](https://minikube.sigs.k8s.io/docs/start/)


### Initial set-up

* Create an Ubuntu VM with the Ubuntu 20.04 Desktop image downloaded from the above link
* Provision with reasonable specs —(would love assistance seeing what the lower limits might be) My configuration is as follows:
	*  4 virtual CPU’s
	*  8 GBs of RAM
	*  50 GBs of Storage
* Once machine is up and user is created start the VM
* Open terminal


### Option 1 Install Docker Kubectl and Minikube using a bash script

```bash
sudo apt install git
git clone https://github.com/Kyle9021/Set-up_Scripts
cd Set-up_Scripts/
chmod +x Ubuntu_20.04_BASH_INSTALL_DOCKER_MINIKUBE_KUBECTL
sudo ./Ubuntu_20.04_BASH_INSTALL_DOCKER_MINIKUBE_KUBECTL
```
* Enter the username you created for your vm and let the script run. 
* Proceed to the step "Prepare the Prisma Compute Tarball"

### Option 2 Install the tools manually

* Install [Docker](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04)

```bash
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt update
apt-cache policy docker-ce
sudo apt install docker-ce
sudo usermod -aG docker ${USER}
su - ${USER}
```

* Install [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256”
echo "$(<kubectl.sha256) kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

* Install [Minikube](https://minikube.sigs.k8s.io/docs/start/) following the instructions for a Linux Debian package

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb
```

### Prepare the Prisma Cloud Compute tarball

```bash
mkdir <PRISMA_DEPLOY_DIR_VERSION>
cd <PRISMA_DEPLOY_DIR_VERSION>
wget https://cdn.twistlock.com/releases/<UNIQUETOKEN>/prisma_cloud_compute_edition<VERSION_WITH_UNDERSCORES>.tar.gz
mkdir prisma_cloud_compute_edition
tar xvzf prisma_cloud_compute_edition_<VERSION_WITH_UNDERSCORES>.tar.gz -C prisma_cloud_compute_edition/
cd prisma_cloud_compute_edition
./linux/twistcli console export kubernetes --service-type LoadBalancer
```

### Create the cluster

`minikube start`
* run the following command until you see all pods are up and running `kubectl get pods --all-namespaces`

* make and mount a directory
```bash
cd
mkdir mount
cd mount
minikube mount $PWD:/host
```

* Open a new terminal window (keep the other one running; Important)
* get back to the Prisma Deployment directory by entering `cd` brings you back to home then `cd /<PRISMA_DEPLOY_DIR_VERSION>/prisma_cloud_compute_edition/`

### Deploy the Prisma Compute Platform 

`kubectl apply -f twistlock_console.yaml`

* In your terminal session `su - ${USER}`
* Start the emulated load balancer `minikube tunnel`
* Copy the IP address that’s shown in the logging `route <IP_Address> ->  <COPY_THIS_IP_ADDRESS>
* Open a third terminal session (keep other two running in the background)
* In your third terminal session `su - ${USER}`
* Then enter `kubectl get svc -n twistlock` and check the port mapping from `8083:<COPY_THIS_PORT>`
* Open up Firefox and access the console at `https://<IP_ADDRESS_YOU_COPIED>:<PORT_YOU_COPIED>`
* Set your username and password - this will be the global admin for the prisma cloud compute console. 
* Enter license key


### Deploy your first container defender

* Open a new terminal session and enter `kubectl get service -—all-namespaces`
* Write down the port mappings for the twistlock console under the port column. We’ll use this for steps in this section. `8084:<WRITE_8084_PORT_DOWN>` & `8083:<WRITE_8083_PORT_DOWN>`
* In the Prisma Cloud Compute Console go to Manage > Defenders
* Under the ‘Names’ Tab click the warning bar at the top of the screen which adds the Subject Alternative Name of the console to the list. Note it will cause an error —Just refresh the webpage and continue on.
* After you confirm the IP address is added to the list click the ‘Deploy’ tab
* Choose the ‘Single Defender’ deployment method 
* Set the name that the Defender will use to connect to the console as the IP address you added
* Tun the switch to on for the ‘Defender communication port’ and enter the <8084_PORT_MAP_YOU_WROTE_DOWN>
* For the ‘Defender Type’ choose ‘Container Defender - Linux’ 
* Copy the curl command to your clipboard and paste it in a text file; it should look something like this:
`curl -sSL -k --header "authorization: Bearer <HASH>” -X POST https://192.168.49.2:8083/api/v1/scripts/defender.sh -d  '{"port":<PORT_MAPPING_TO_8084_YOU_WROTE_DOWN>}' | sudo bash -s -- -c "192.168.49.2" -d "none"  `
* Update the ‘8083 port’ for your IP address Url. Example:
`curl -sSL -k --header "authorization: Bearer <HASH>“ -X POST https://192.168.49.2:<8083_PORT_MAP_YOU_WROTE_DOWN>/api/v1/scripts/defender.sh -d  '{"port":<PORT_MAPPING_TO_8084_YOU_WROTE_DOWN>}' | sudo bash -s -- -c "192.168.49.2" -d "none"  `
* Copy the altered command to your clipboard and open the terminal session you ran the `kubectl get service` command in. Paste and hit enter
* Check your radar view under the containers section to see it beginning the scan.

### Deploy an Orchestrator Defender

* In the Prisma Cloud Compute console go to manage > defenders
* Go to the deploy tab and ensure it's on the orchestrator deployment method.
* Ensure that the name of the console is set to the IP address. 
* Turn on the opition for Defender communication port. 
* Set it to the (8084_PORT_MAPPING_YOU_WROTE_DOWN)
* Ensure the target machine OS is set to linux
* Copy the script and paste in your terminal window. It takes a moment for the scan to begin.

### Add twistcli to /usr/bin

```bash
cd 
cd <PRISMA_DEPLOY_DIR_VERSION>/prisma_cloud_compute_edition/linux
sudo cp twistcli /usr/bin/twistcli
su - ${USER}
```

### Deploy the DVWA Web App served behind a reverse proxy using Docker

* In the same terminal window you ran your `kubectl get service command` enter `cd` to ensure you’re in the user’s home directory
* Enter `su - ${USER}`
* Create a new directory `mkdir dvwa_proxy` then `cd dvwa_proxy`
* Create a ‘Caddyfile’ by entering `nano Caddyfile` 
* In the Caddyfile paste the following:

```bash
localhost
route * {
    uri replace * /setup/php 
    reverse_proxy dvwa:80
}
```

* Type `ctrl + x` then `y` and finally `enter`
* Now create a ‘Dockerfile’ by entering `nano Dockerfile`
* In the Dockerfile copy and paste the following:

```bash
FROM caddy:2.3.0-alpine
COPY Caddyfile /etc/caddy/Caddyfile
EXPOSE 80
EXPOSE 443
ENTRYPOINT ["/usr/bin/caddy","run","--config","/etc/caddy/Caddyfile","--adapter","caddyfile"]
```

* Type `ctrl + x` then `y` and finally `enter`
* Now you’re ready to build your reverse proxy container by entering `docker build -t proxy:1 . `
* After the build completes pull the DVWA web container by entering `docker pull vulnerables/web-dvwa`
* Tag the vulnerables/web-dvwa image by entering `docker tag vulnerables/web-dvwa dvwa:1`
* Now create a docker bridge network so that DNS is enabled. Enter `docker network create --driver bridge app-net`
* Enter the following two commands to run your containers in the network:

`docker run -dit --name dvwa --network app-net dvwa:1`
`docker run -dit -p 80:80 -p 443:443 --name dvwa_reverse_proxy --network app-net proxy:1`

* In Firefox open a new tab and type in the address bar `https://localhost` and hit enter! 
* Username is: `admin` Password is `password`


### Add an App Embedded Container Defender to a new reverse proxy container using twistcli and modifying the Dockerfile

* `cd` to your home directory
* `mkdir newproxy` this is where we'll build our new docker image
* `cp -r dvwa_proxy/* newproxy` this will copy over the files we'll use
* If you haven't done so already ensure that the twistcli exe is in /usr/bin (see instructions above)
* `cd newproxy/` you shoud see your Caddyfile and Dockerfile that we created earlier. 
* `nano Dockerfile` and add two lines near the bottom right before the ENTRYPOINT

```bash
EXPOSE <PORT_MAPPING_YOU_WROTE_DOWN_EARLIER_TO_8083>
EXPOSE <PORT_MAPPING_YOU_WROTE_DOWN_EALIER_TO_8084>
```

* `ctl + X` then `y` then enter
* Now get the defender files by running the following command `twistcli app-embedded embed --user <ADMIN> --app-id embedded_proxy --data-folder /srv --address https://<YOUR_CONSOLE_IP_ADDRESS>:<PORT_MAPPING_YOU_WROTE_DOWN_TO_8083> -p <ADMINPASSWORD> Dockerfile`
* This will bring down a zip file to your project directory. `ls` to see that it downloaded
* Make another directory `mkdir defender_build`
* Copy your Caddyfile to the directory `cp Caddyfile defender_build/Caddyfile`
* Unzip the archive to the new directory `unzip app_embedded_embed_embedded_proxy.zip -d defender_build/`
* `cd defender_build` and `nano Dockerfile` you'll notice that your Dockerfile has been updated to embed the defender.

* On the line that reads `ENV WS_ADDRESS="wss://<YOUR_CONSOLE_IP_ADDRESS>:8084` change the `8084` to the `<PORT_MAPPING_YOU_WROTE_DOWN_TO_8084>`

* Your new Dockerfile should look like the example below:

```bash
FROM caddy:2.3.0-alpine
COPY Caddyfile /etc/caddy/Caddyfile
EXPOSE 80
EXPOSE 443
EXPOSE <PORT_MAPPING_YOU_WROTE_DOWN_TO_8083>
EXPOSE <PORT_MAPPING_YOU_WROTE_DOWN_TO_8084>
ENTRYPOINT ["/usr/bin/caddy","run","--config","/etc/caddy/Caddyfile","--adapter","caddyfile"]


# Twistlock Container Defender - app embedded
ADD twistlock_defender_app_embedded.tar.gz /srv
ENV DEFENDER_TYPE="appEmbedded"
ENV DEFENDER_APP_ID="proxy_with_embedded_defender"
ENV WS_ADDRESS="wss://<YOUR_CONSOLE_IP_ADDRESS>:<PORT_MAPPING_YOU_WROTE_DOWN_TO_8084>"
ENV DATA_FOLDER="/srv"
ENV INSTALL_BUNDLE="<LONG_UNIQUE_STRING>"
ENTRYPOINT ["/srv/defender", "app-embedded", "/usr/bin/caddy","run","--config","/etc/caddy/Caddyfile","--adapter","caddyfile"]
```
* Enter `ctl + x` then `y` then `enter`
* It's time to build your app embedded image `docker build -t app_embedded_reverse_proxy:1 .`
* Final steps: 

```bash
docker stop dvwa_reverse_proxy
docker rm dvwa_reverse_proxy
docker run -dit -p 80:80 -p 443:443 --name app_embedded_reverse_proxy --network minikube app_embedded_reverse_proxy:1
```
* In the prisma cloud compute console, check the defenders and hit the manage tab to see your new app_embedded container checking in. 
* I'll go into PCC WAAS configuration for app-embedded containers at a later date. Stay tuned. 

