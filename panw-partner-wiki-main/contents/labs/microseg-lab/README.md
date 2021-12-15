Rev 0.1
# Purpose of this demo

* To teach partners and internal PANW SA's how to install Aporeto enforcer agent on an on-prem environment and connect agent to Prisma Cloud console.


Goals

 * We will install aporeto enforcer agent on linux VM and in K8s environment ([Minikube](https://minikube.sigs.k8s.io/docs/start/) is used in this lab). Also, we will create Microsegmentation namespaces for our lab environment. More info regarding the Microsegmentation namespaces can be found [here](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-microsegmentation/concepts/namespaces.html).
 
 * In this demo we use multiple scripts that should be ran in an order (first run script **0b_aporeto_vm_prep.sh**, then **1_aporeto_install_apoctl.sh** and so on).



## Requirements:


* Prisma Cloud Microsegmentation license
* Prisma Cloud Microsegmentation Credentials (this can be generated in PC console under **Network Security > MANAGE > Credentials**)
* Prisma Cloud Microsegmentation API URL (click on the key icon at the bottom of any page on *Cloud Network Security The URL should look something like this: https://api.east-01.network.prismacloud.io)
* Hypervisor - [VirtualBox - Free](https://www.virtualbox.org/wiki/Downloads) or VMWare
* [Ubuntu VM Image 20.04 Desktop](https://releases.ubuntu.com/20.04/)
* [curl](https://curl.se/)
* [jq](https://stedolan.github.io/jq/)
* [Kubectl Installed - Install before installing Minikube](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) - [instructions](https://github.com/Kyle9021/panw-partner-wiki/blob/main/contents/labs/Prisma_Cloud_Compute_Minikube_Lab.md)
* [Minikube](https://minikube.sigs.k8s.io/docs/start/) - [instructions](https://github.com/Kyle9021/panw-partner-wiki/blob/main/contents/labs/Prisma_Cloud_Compute_Minikube_Lab.md)
<br />

## Instructions
---

### Initial set-up

* Create an Ubuntu VM with the Ubuntu 20.04 Desktop image downloaded from the above link
* Provision with reasonable specs —(would love assistance seeing what the lower limits might be) My configuration is as follows:
	*  4 virtual CPU’s
	*  8 GBs of RAM
	*  50 GBs of Storage
* Once machine is up and user is created start the VM
* Open terminal
* Download relevant script files in working directory
* Inside working directory create directory named **secrets** 
* Create a new empty file and name it **aporeto_admin_app_credentials** (it is important to use this name because it is used in scripts) - open file with the text editor of your choice and create multiline string variable called **APORETO_CREDENTIALS** - the content of the variable should be previously downloaded Prisma Cloud Microsegmentation Credentials JSON file (see Requirements above). We are using [HereDoc](https://linuxize.com/post/bash-heredoc/) in order to pass our multi-line block of data into the variable. The content of the **aporeto_admin_app_credentials** should look like:

```
APORETO_CREDENTIALS=$(cat <<EOF
<YOUR Prisma Cloud Microsegmentation Credentials JSON content goes here>
EOF
)
```
* Save this **aporeto_admin_app_credential** inside **secrets** directory


### Step 1: Modify 0a_aporeto_config file 

This file contains names of the Microsegmentation namespaces you want to create in your environment. Also, here you can specify Prisma Cloud app stack (this can be taken from the Prisma Cloud URL used to login to Prisma Cloud console (e.g. for https://app.prismacloud.io/ app stack is "app"). In this example we are creating two different Microsegmentation namespaces, one for VM enforcer and one for K8s enforcer agent. Here is the example of **0a_aporeto_config** file: 

```
APORETO_CHILD_NAMESPACE=on-prem-vm

APORETO_GRANDCHILD_NAMESPACE=vm
APORETO_GRANDCHILD_NAMESPACE2=k8s

PRISMA_APP_STACK="app"
```


### Step 2: Disable and stop any local Linux firewall

* As per instructions in [system requirements](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-microsegmentation/start/enforcer/reqs.html), linux firewalls like **firewalld**, **iptables** and **ufw** should be disabled and stopped before installing the enforcer.

* The first script **0b_aporeto_vm_prep.sh** contains systemctl (a utility which is responsible for examining and controlling the systemd system and service manager) commands to disable and stop releavnt services on a linux host:
```
#!/bin/bash

#for an ubuntu vm

sudo systemctl disable ufw
sudo systemctl stop ufw
sudo systemctl disable iptables
sudo systemctl stop iptables
sudo systemctl disable firewalld
sudo systemctl stop firewalld
```
 

### Step3: Download apoctl tool

* Run **1_aporeto_install_apoctl.sh** script to [download apoctl tool for linux](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-microsegmentation/start/install-apoctl.html) that will be used to build up automation in later steps. 

* This script uses **curl** tool to download **apoctl** tool from relevant Prisma Cloud app stack and makes it executable. `source` command inside script is used to read and execute the content of the **0a_aporeto_config** file:
```
#!/bin/bash

source ./0a_aporeto_config

sudo curl -o /usr/local/bin/apoctl \
  	 --url https://download.aporeto.com/prismacloud/$PRISMA_APP_STACK/apoctl/linux/apoctl \
     && sudo chmod 755 /usr/local/bin/apoctl
```


### Step4: Generate certificates that will be used to configure apoctl tool

* Run **2_aporeto_generate_cert.sh** script to generate certificate that will be used in the following script to configure apoctl tool to communicate with Prisma Cloud console. In this script we use credentials from **aporeto_admin_app_credentials** file. 

* These credentials are parsed by **jq** tool (`jq -r` is used to extract relevant certificate and certificate key which is decoded by `base64` command an appended to **/secrets/aporeto.pem** file):
```
#!/bin/bash

source ./secrets/aporeto_admin_app_credentials

printf %s $APORETO_CREDENTIALS | jq -r '.certificateKey'| base64 -d > ./secrets/aporeto.pem
printf %s $APORETO_CREDENTIALS | jq -r '.certificate'| base64 -d >> ./secrets/aporeto.pem
```

### Step5: Configure apoctl tool

* Run **3_aporeto_configure_apoctl.sh** script to configure apoctl tool. As per [procedure - STEP5](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-microsegmentation/start/install-apoctl.html), in order to configure **apoctl** tool, we need parent namespace, relevant URL and aporeto token. 

* Script is using **aporeto_admin_app_credentials** file and **jq** tool to exstract parent namespace and URL, while aporeto token is taken by **curl** tool and previously saved **aporeto.pem** certificate (containing the key) file (more info, howt to retrieve a token using authentication with an X.509 certificate, can be found [here](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-microsegmentation/start/install-apoctl.html).

* Script is using `apoctl configure -A "$APORETO_APIURL" -n "$APORETO_PARENT_NAMESPACE" -t "$APORETO_TOKEN" --force` with the **force** option to reset existing credentials (if any):
```
#!/bin/bash

source ./secrets/aporeto_admin_app_credentials

APORETO_PARENT_NAMESPACE=$(printf %s $APORETO_CREDENTIALS | jq -r '.namespace')
APORETO_APIURL=$(printf %s $APORETO_CREDENTIALS | jq -r '.APIURL')

APORETO_TOKEN=$(curl --url $APORETO_APIURL/issue \
                     --request POST \
                     -E "./secrets/aporeto.pem" \
                     --header 'Content-Type: application/json' \
                     --data '{"realm": "Certificate"}' | jq -r '.token')

apoctl configure -A "$APORETO_APIURL" -n "$APORETO_PARENT_NAMESPACE" -t "$APORETO_TOKEN" --force
```

### Step6: Create child and grandchild namespace for VM and K8s environment

* Run **4b_aporeto_create_child_and_grand_child_namespace.sh** script to configure Microsegmentation namespaces. Relevant documentation how to configure namespaces with **apoctl** toool can be found [here](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-microsegmentation/start/create-ns.html).

* Relevant information needed to create namespaces with apoctl tool are extracted from **aporeto_admin_app_credentials** and **0a_aporeto_config** files:
```
#!/bin/bash

source ./secrets/aporeto_admin_app_credentials
source ./0a_aporeto_config

APORETO_PARENT_NAMESPACE=$(printf %s $APORETO_CREDENTIALS | jq -r '.namespace')

cat <<EOF | apoctl api create namespace -n $APORETO_PARENT_NAMESPACE -f -
name: $APORETO_CHILD_NAMESPACE
type: Group
defaultPUIncomingTrafficAction: Allow
defaultPUOutgoingTrafficAction: Allow
EOF

cat <<EOF | apoctl api create namespace -n $APORETO_PARENT_NAMESPACE/$APORETO_CHILD_NAMESPACE -f -
name: $APORETO_GRANDCHILD_NAMESPACE
type: Group
defaultPUIncomingTrafficAction: Allow
defaultPUOutgoingTrafficAction: Allow
EOF

cat <<EOF | apoctl api create namespace -n $APORETO_PARENT_NAMESPACE/$APORETO_CHILD_NAMESPACE -f -
name: $APORETO_GRANDCHILD_NAMESPACE2
type: Group
defaultPUIncomingTrafficAction: Allow
defaultPUOutgoingTrafficAction: Allow
EOF
```

* If you want to create just one child namespace, you can use **4a_aporeto_create_child_namespace.sh script** instead.


### Step7: Install agent (enforcer) on linux host

* Run **5a_aporeto_linux_vm_enforcer_install.sh** script to install an agent on a linux host. Script is using following **apoct** command to install agent [On-premise linux host - STEP11](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-microsegmentation/start/enforcer/linux.html#_linux_hosts__on-premise-install):
```
#!/bin/bash

source ./0a_aporeto_config
source ./secrets/aporeto_admin_app_credentials


APORETO_PARENT_NAMESPACE=$(printf %s $APORETO_CREDENTIALS | jq -r '.namespace')
APORETO_APIURL=$(printf %s $APORETO_CREDENTIALS | jq -r '.APIURL')

APORETO_TOKEN=$(curl --url $APORETO_APIURL/issue \
                     --request POST \
                     -E "./secrets/aporeto.pem" \
                     --header 'Content-Type: application/json' \
                     --data '{"realm": "Certificate"}' | jq -r '.token')

CLUSTER_NS="$APORETO_PARENT_NAMESPACE/$APORETO_CHILD_NAMESPACE/$APORETO_GRANDCHILD_NAMESPACE"

apoctl enforcer install linux \
 --auth-mode appcred \
 --api "$APORETO_APIURL" \
 --namespace $CLUSTER_NS \
 --token $APORETO_TOKEN
```

* The linux enforcer agent is installed in **APORETO_GRANDCHILD_NAMESPACE** which has been defined inside  **0a_aporeto_config** file

* Script should be run as a root user.


### Step8: Install agent (enforcer) deamon-set in a K8s environment 

* Run **5c_aporeto_k8s_enforcer_install.sh** script to install enforcer deamon-set on a K8s environment.

* This script uses **apoctl** command to install enforcer on a K8s custom environment. In this command you have to specify a namespace where enforcer deamon-set will be installed (**APORETO_GRANDCHILD_NAMESPACE2** which has been defined inside  **0a_aporeto_config** file), aporeto URL and aporeto token. Similarelly as in previous scripts, these pieces of information can be extracted from **aporeto_admin_app_credentials** and **0a_aporeto_config** files:
```
#!/bin/bash

source ./0a_aporeto_config
source ./secrets/aporeto_admin_app_credentials


APORETO_PARENT_NAMESPACE=$(printf %s $APORETO_CREDENTIALS | jq -r '.namespace')
APORETO_APIURL=$(printf %s $APORETO_CREDENTIALS | jq -r '.APIURL')

APORETO_TOKEN=$(curl --url $APORETO_APIURL/issue \
                     --request POST \
                     -E "./secrets/aporeto.pem" \
                     --header 'Content-Type: application/json' \
                     --data '{"realm": "Certificate"}' | jq -r '.token')

CLUSTER_NS="$APORETO_PARENT_NAMESPACE/$APORETO_CHILD_NAMESPACE/$APORETO_GRANDCHILD_NAMESPACE2"


apoctl enforcer install k8s \
 --cluster-type custom \
 --api "$APORETO_APIURL" \
 --namespace $CLUSTER_NS \
 --custom-cni-bin-dir /opt/cni/bin \
 --custom-cni-conf-dir /etc/cni/net.d \
 --custom-cni-chained \
 --token $APORETO_TOKEN 
 ```


* Alternativelly, enforcer deamon-set can be deployed via helm chart - use this [apoctl command](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-microsegmentation/start/enforcer/k8s.html#_kubernetesopenshift_clusters__using-a-helm-chart) inside **5d_aporeto_k8s_enforcer_helm_generate.sh** script:
```
#!/bin/bash

source ./0a_aporeto_config
source ./secrets/aporeto_admin_app_credentials


APORETO_PARENT_NAMESPACE=$(printf %s $APORETO_CREDENTIALS | jq -r '.namespace')
APORETO_APIURL=$(printf %s $APORETO_CREDENTIALS | jq -r '.APIURL')

APORETO_TOKEN=$(curl --url $APORETO_APIURL/issue \
                     --request POST \
                     -E "./secrets/aporeto.pem" \
                     --header 'Content-Type: application/json' \
                     --data '{"realm": "Certificate"}' | jq -r '.token')

CLUSTER_NS="$APORETO_PARENT_NAMESPACE/$APORETO_CHILD_NAMESPACE/$APORETO_GRANDCHILD_NAMESPACE2"

apoctl enforcer install k8s \
 --cluster-type custom \
 --installation-mode helm \
 --output-dir . \
 --custom-cni-bin-dir /opt/cni/bin \
 --custom-cni-conf-dir /etc/cni/net.d \
 --custom-cni-chained \
 --api "$APORETO_APIURL" \
 --namespace $CLUSTER_NS \
 --token $APORETO_TOKEN 
 ```
 
* This script will created helm chart named **enforced** 

* After that, you can create k8s namespace aporeto by **kubectl** tool:
`kubectl create namespace aporeto`

* And use [helm](https://helm.sh/docs/intro/install/) command to install enforcer deamon-set inside aporeto k8s namespace:
```
helm install enforcerd ./enforcerd --namespace aporeto
```




