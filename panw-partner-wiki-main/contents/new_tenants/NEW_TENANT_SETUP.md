# Setting Up a New Customer Tenant

Instructions for assisting customer in setting up new tenant.

## Objectives
1) Have customer obtain access to their Prisma Cloud tenant
2) Have customer add Partner/SA Users to their Customer Suppor Portal Account
3) Have customer add Partner/SA Users to their Prisma Cloud tenant
4) Partner/SA verify their access to customer's account via Hub/Apps account page - https://apps.paloaltonetworks.com/apps 
5) Partner/SA verify their access to customer's Prisma Cloud tenant
6) Enable initial configuration settings, including default policies
7) Assist Customer with setting up Cloud Account(s)

### Assumptions and things to know:
1) This use case assumes the customer owns the tenant.
2) The customer who was listed in the Deal Registration in Salesforce should be the one assigned as the owner of the tenant.
3) The Eval/Tenant request was approved and customer has received 2 emails.  ***More detail to be provided here.***
4) This user will be the ONLY one initially who can grant access to others and is by default both:
    - the **Super User** of their Palo Alto Networks Customer Support Portal Account
    - granted **System Admin** access to their new Prisma Cloud tenant.

## Instructions

### 1 - Customer First Time Login to Prisma Cloud Tenant

* Have the customer follow these instructions: [Access Prisma Cloud](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin/get-started-with-prisma-cloud/access-prisma-cloud#id3d308e0b-921e-4cac-b8fd-f5a48521aa03)


### 2 - Customer Add Partner/SA Users in Customer Support Portal (CSP) Account

* Have the customer follow these instructions: [Manage Users in Your CSP Account](https://knowledgebase.paloaltonetworks.com/KCSArticleDetail?id=kA10g000000ClNaCAK)


### 3 - Customer Add Partner/SA Users in Prisma Cloud

1) With the customer logged into their Prisma Cloud tenant, have them follow these instructions to add new users: [Add Administrative Users On Prisma Cloud](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin/manage-prisma-cloud-administrators/add-prisma-cloud-users)
3) **Add User** and have them fill in your Name, Email, Assign 'System Admin' Role, and click Save and Close.
4) This will automatically and immediately send an email to you, however:
IMPORTANT NOTE: THIS ALONE WILL NOT GRANT YOU ACCESS TO THE USERS TENANT.  Ensure the Customer also already added you to their Customer Support Portal Account (Step 2 above).  If not, you most likely will be redirected to your Hub account but NOT able to see the new customer tenant in your list of accounts.  You need to be given access to BOTH the Customer's CSP Account and Prisma Cloud tenant.

### 4 - Verify Visibility to Customer's Account via Hub/Apps Page

### 5 - Login to Customer's Prisma Cloud Tenant

### 6 - Enable initial configuration settings, including default policies

### 7 - Assist Customer with setting up Cloud Account(s)



### Troubleshooting and Additional References:

## Alternative Method to Accessing Prisma Cloud - Legacy/Auth Signin Method - This eventually will be deprecated. Use only if needed.

1) Determine what App Stack this new tenant is assigned to.  You can do this by clicking the link in the email you received and look for one of the following app stacks under Step 1 of [Access Prisma Cloud](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin/get-started-with-prisma-cloud/access-prisma-cloud) 
2) Add `/auth/signin` to end of the url. For example:   
`https://app2.prismacloud.io/auth/signin`
3) This should bring up a login screen like this:

<img src="https://user-images.githubusercontent.com/31355989/162478211-b840b544-cb15-4a4c-8f50-6f003ab00fc2.png" width="300">

4) Click the 'Reset Password'
5) Type in email and new password
6) Sign into tenant.  If you have access to mutiple tenants on this stack, choose the customer tenant you want to login into from the drop down list.


