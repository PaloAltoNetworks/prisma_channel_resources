## Step 1: Install twistcli tools, create access keys, and get path to console

* Enterprise Edition
    * Go to settings
    * Access keys
    * Click '+Add New' button on the top left on window
    * provide name
    * Copy the access key and secret key to a secure location where the access key is `<user_name>` and the secret key is `<password>` ---note you won't be able to retrieve these later. 
* Compute Edition 
    * Go to Manage
    * Authentication 
    * Click the '+ Add user' button 
    * Provide a username ---recommending something like cliadmin
    * Set password
    * change role to CI user
    * Set permissions to all 
    * Save the user name in a text file as `<User_name>` and the password as `<password>` (we'll use later)
* Copy the console web address:
    * Enterprise Edition:
        * Compute > System > Downloads tab ---copy from Path to Console Field 
        * Save to text doc as `<Path_to_console>`
* Go to the Prisma Cloud Compute Tab if you're using Prisma Cloud Enterprise Edition (Skip this step if you're on the compute edition)
* Go to the Manage Section and click system in the left hand menu
* On the tabs towards the top of the page click downloads
* On the downloads screen click the copy button
* Paste the command copied into your linux shell


## Step 2: (Optional) Pull a docker image to scan

* Must have docker installed in order to run 
* Docker command to pull a quick image `docker pull hello-world`
* If you'd like to just scan an image that's already on the host run `docker images` you'll want to note the `<repository_name>` of the image and the `<tag>`

## Step 3: Scan the image using twistcli
* (Optional) create an alias for the twistcli command in your users .bashrc profile
 
```
sudo cp twistcli /usr/bin
su ${USER}
```

* `./twistcli images scan --address <Address_to_console> -u <user_name> -p <password> --details <repository_name>:<tag>` or if you added the alias `twistcli images scan --address <Address_to_console> -u <user_name> -p <password> --details <repository_name>:<tag>`
* If using the demo-build on GCP use --address https://console-master-fill-this-in-with-yours.demo.twistlock.com and the username and password must be the one you use to log into the console (i.e. creating a new one doesn't work)
