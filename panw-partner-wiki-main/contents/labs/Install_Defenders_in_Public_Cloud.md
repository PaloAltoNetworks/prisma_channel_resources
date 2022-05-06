# Install Compute Defenders

Written by John Chavanne
    
## Host and Container Defenders on Public Cloud (Written and Verified on AWS)

Refs:
- [Install Host Defender](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/install/install_defender/install_host_defender)
- [Install Container Defender](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/install/install_defender/install_single_container_defender)

These instructions are using EC2 Ubuntu instances for examples, however you can use many other compute types.  See docs above for additional help with other deployment types.
1. If not already create an EC2 instance on AWS that meets minimum requirements (TODO - add link to docs here)
    - ensure to configure it so you can connect to it (TODO - add details here)
    - Optional - Use sample Terraform files to deploy your EC2 instances (TODO - add details here)
    - After creation, in AWS Console, Click Connect and folow instructions:
    - Edit permissions on your key file, i.e. `chmod 400 linux-key-pair.pem`
    - SSH into your instance, i.e. `ssh -i "linux-key-pair.pem" ubuntu@ec2-54-173-140-85.compute-1.amazonaws.com`
2. Login into EC2 instance and run modified version of the curl command in the docs
    - find the [Compute Console address](https://prisma.pan.dev/docs/cloud/cwpp/access-api-saas/#:~:text=Retrieve%20your%20Compute%20Console's%20address,your%20Prisma%20Cloud%20user%20credentials.)
    - Use this modifed command (vs. one in install doc) to test connectivity.  Documentation is wrong (unless it was meant for self-host only, but in that case, should be udpated)
    - `curl -sk -D - <Path to Console>/api/v1/_ping`
    - Example: `curl -sk -D - https://us-east1.cloud.twistlock.com/us-2-158256885/api/v1/_ping`
3. Download twistcli
    - Go to **Compute > Manage > System > Utilities > twistcli tool**, click the copy button and paste on your EC2 instance.
    - After running, confirm twistcli is successfully installed
    ```
    ./twistcli -h
    ```
4. If using Enterprise Edition, gather your Prisma Cloud Access & Secret Key, and Path to Console and Export variables, entering your values between the `""`.  Find the Path to Console in **Compute > Manage > System > Utilities > Path to Console**:
```
export PC_ACCESSKEY=""
export PC_SECRETKEY=""
export PC_CONSOLE=""
```

5. Installing Host Defender (If Installing a Container Defender, skip to next section):
```
  sudo ./twistcli defender install standalone host-linux \
  --address $PC_CONSOLE \
  --user $PC_ACCESSKEY \
  --password $PC_SECRETKEY
```
6. Installing Container Defender 
    - First confirm Docker or CRI-O are installed (ADD MORE DETAIL HERE).  Verify with: `docker ps`
    - If needed, install Docker - taken from [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
```
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
```
If asks **Do you want to continue?**, type `Y`    
    
- Test Docker is running
```
sudo docker run hello-world
```

Install container defender:    
Example where I used Enterprise Edition and passed in key values for user and password
```
  sudo ./twistcli defender install standalone container-linux \
  --address $PC_CONSOLE \
  --user $PC_ACCESSKEY \
  --password $PC_SECRETKEY
```

7. Verify that Defender is installed and connected to Console.
    - In Console, go to Manage > Defenders > Manage. Your new Defender should be listed in the table, and the status box should be green and checked.

## Removing a Defender
[Decommission Defenders](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/install/install_defender/decommission_defender)


## Notes on our documentation - Beware of some potentially issues from the docs.  More research needed.

These curl commands came from the docs but did not work for me as written.  As seen above I provided modified version for my deployment.
```
curl -k \
  -u <USER> \
  -L \
  -o twistcli \
  https://<CONSOLE>/api/v1/util/twistcli
```

Example I used
```
curl -k \
  -u <USER> \
  -L \
  -o twistcli \
  https://https://us-east1.cloud.twistlock.com/us-2-158256885/api/v1/util/twistcli
```
