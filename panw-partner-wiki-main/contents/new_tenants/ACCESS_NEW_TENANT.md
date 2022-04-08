# Accessing a new customer tenant

These are a set of intstructions for partners and SAs that have customers setting up new tenants that the partner or SA will need access to.
Access to a customer tenant is needed most often for running new Evals & POVs.

### Assumptions and things to know:
1) This use case assumes the customer owns the tenant.
2) The customer who was listed in the Deal Registration in Salesforce should be the one assigned as the owner of the tenant and will receive 2 emails.  ***More detail to be provided here.***
3) The customer/user who received the emails with the license info, is by default the Super User and is automatically granted **System Admin** access to the new tenant.
4) This user will be the ONLY one initially who can grant access to others.

## First Time Login

* Have the customer follow these instructions: [Access Prisma Cloud](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin/get-started-with-prisma-cloud/access-prisma-cloud#id3d308e0b-921e-4cac-b8fd-f5a48521aa03)


## Adding SAs and/or Partners as Users in Prisma Cloud

1) Have the Admin User log in to their Prisma Cloud tenant
2) Have them follow these instructions to add new users: [Add Administrative Users On Prisma Cloud](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin/manage-prisma-cloud-administrators/add-prisma-cloud-users)
3) **Add User** and have them fill in your Name, Email, Assign 'System Admin' Role, and click Save and Close.
4) This will automatically and immediately send an email to you, however:
IMPORTANT NOTE: THIS ALONE WILL NOT GRANT YOU ACCESS TO THE USERS TENANT.  YOU MUST ADDITIONALLY FOLLOW ONE OF THE BELOW OPTIONS.
This is because, by default, you must also authentiate through the customer's Palo Alto Networks Customer Support Portal (CSP) account.
If you do not also follow one of the below options, and try to click the link in the email first, you will liekly be redirected to your Hub Account and NOT be able to see the new customer tenant.

## Accessing Prisma Cloud - Option #1 - Legacy/Auth Signin Method

1) Determine what App Stack this new tenant is assigned to.  You can do this by clicking the link in the email you received and look for one of the following app stacks under Step 1 of [Access Prisma Cloud](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin/get-started-with-prisma-cloud/access-prisma-cloud) 
2) Add `/auth/signin` to end of the url. For example:   
`https://app2.prismacloud.io/auth/signin`


## Accessing Prisma Cloud - Option #2 - Add Users in CSP Account

[MANAGE USERS IN YOUR CSP ACCOUNT](https://knowledgebase.paloaltonetworks.com/KCSArticleDetail?id=kA10g000000ClNaCAK)


### Additional References:
