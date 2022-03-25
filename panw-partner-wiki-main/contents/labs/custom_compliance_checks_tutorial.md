# Using custom Compliance/Configuration checks to detect kernel vulnerabilites like Dirty Pipe

Okay, so here's the reason I wrote this lab; essentially, it has to do with a linux kernel vulnerablity called Dirty Pipe, you can read a more official write-up on the vulnerability [here](https://dirtypipe.cm4all.com/). 
It's a pretty big deal, because it can lead to a nasty privilage escalation allowing an unprivileged process to inject code into a root process. 

Imagine being able to execute a binary that would allow you change the usernames or passwords on a linux box...without the need to use `sudo`

## What is the problem? 

One of the challenges I had with this particular vulnerability was that it wouldn't always show up in every linux distro when performing vulnerbility scans(Our OS support is the best I've seen for a tool like this, but there's a few limitations if using not LTS distributions); Prisma Cloud supports all the mainstream linux distributions and their LTS flavors because that's what customers typically use in production environments. But because this vulnerability is so easy perform using self-compiled code which may delay malware detection and because it was so easy to perform the exploit; I thought it might be important for Prisma Cloud Customers to know how to detect and eliminate this kernel vulnerability using either twistcli or a prisma cloud defender. 

* [Link to our supported Operating systems](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/install/system_requirements.html)

Here's a usecase, what if my developers are using Unsupported linux OS XYZ. How can I check to ensure they have the patched version of the kernel on their machines...if I can't see the vulnerability show in vulnerability scans?

## Enter Custom Compliance Checks and the world of bash scripting
                                                
With Prisma Cloud Compute we call configuration checks compliance checks; because those configuration checks are mapped back to compliance frameworks. 

What's nice about the compliance checks, is they're completely customizable and really only limited to one's imagination and creativity. 

Essentially if you can write a script, then you can perform a configuration check. 

Here are my assumptions:

* Every linux box you'd like to check has the `bash` shell available. 
* You're either using a Prisma Cloud Defender or the twistcli tool (shifthing left). 
* You know the version where the vulnerability was introduced for the distrobution you're working with (easily googled; hint it started with linux kernel 5.8 and was fixed in Linux versions 5.10.102, 5.16.11, and 5.15.25) 


## How to set-up if using a defender

There's a few configurations you need to do if you're using the defender to detect this. 

First go to Compute > Manage > Defenders and click "Advanced settings" 

You'll need to ensure that custom compliance checks for hosts is set to on. If this was set to off, you'll need to redeploy defenders to any machines you'd like to check. 

## Rest of the configuration explained

Go to Compute > Defend > Compliance

Click on the "Custom" tab and then click the "+ Add check" button

* For Name: `Dirty-Pipe Kernel Check`
* For Description: `Host Kernel is vulnerable to Dirty-Pipe please upgrade the linux kernel`

Copy the script below into the rule and ensure you have the right versions assigned to `min` and `max`. For reference this kernel vulnerability was introduced in linux 5.8 and was fixed in 5.10.102, 5.16.11, and 5.15.25. 

```bash
#!/bin/bash

# The first kernel version where the vulnerability was discovered
min=5.8
# The last kernel version where the vulnerability exists
max=5.10.101


if [[ $(printf '%s\n%s\n' "$min" "$(uname -r)" | sort -V | head -n1) = $min && $(printf '%s\n%s\n' "$max" "$(uname -r)" | sort -rV | head -n1) = $max ]]; then
  echo "kernel version $(uname -r) is vulnerable to dirty pipe, please upgrade the kernel" & exit 1;
else echo "kernel isn't vulnerable"
fi
```

Hit the "Save" button. 

Click on the the "Hosts" tab and modify the "Default- alert on critical and High" policy

use the filter dropdown and change it from, "All types" to "custom". 

Set the action to "Alert" then hit save

That's it!

## Testing

Okay so now you have done your configuration time to do some scanning with a defender and twistcli. 

First, let's grab the twistcli tool and test it on a non-offically supported version. I choose the latest Ubuntu distro 21.10

To get the twistcli tool on the box, I simply navigated through the Prisma Compute UI to: Compute > Manage > System  and clicked the "Utilities" tab

Next, to retrieve the twistcli tool I clicked the "copy" button on the utitlities page to get the script that will call the api endpiont and bring down the twistcli tool. 

After that I sshd over to the Ubuntu box and entered the script. 

Then I ran the command: `sudo ./twistcli hosts scan --address <ADDRESS_TO_COMPUTE_API> -u <USERNAME> -p <PASSWORD> --details --skip-docker # skip docker flag only necessary if docker isn't installed`

And boom it showed up! 

Next, I wanted to ensure it'd show up with a defender. (Spoiler worked with both container and host defenders). So I deployed both types of defenders (not at the same time) and then went to Compute > Monitor > Compliance and clicked the "Hosts" tab. No suprise, it showed up there too. 

So now I feel confident, I know where to send my alerts so that our team can patch the machines which have the vulnerable kernels to this exploit. 

And because of the flexability of "scope" and "collections" I can easily route my alerts to the appropriate teams and have granular control on where the policy is implemented. 

Plus, I can now incorporate this test into my VM image config pipeline so I can eliminate issues like this going forward using a shift-left DevSecOps mentality. 


## Wrap-up

If you're wondering if you could do this all in some automated fashion through a RESTful API; the answer is sure! Here's the [link to the api documentation](https://prisma.pan.dev/api/cloud/cwpp/custom-compliance#operation/put-custom-compliance)

Here's an example request body you might use:

```json
[
  {
    "modified": "2022-03-24T22:18:31.685Z",
    "owner": "prisma-presenter",
    "name": "dirty-pipe kernel vuln",
    "previousName": "",
    "_id": 9000,
    "title": "Host Kernel is vulnerable to Dirty-Pipe",
    "script": "#!/bin/bash\n\n\nmin=5.8\nmax=5.14\n\n\n\n\nif [[ $(printf '%s\\n%s\\n' \"$min\" \"$(uname -r)\" | sort -V | head -n1) = $min && $(printf '%s\\n%s\\n' \"$max\" \"$(uname -r)\" | sort -rV | head -n1) = $max ]]; then\n  echo \"kernel is vulnerable\" & exit 1;\nelse echo \"kernel isn't vulnerable\" & exit 0;\nfi\n",
    "severity": "critical"
  }
]
```
