# Setting Up a New Customer Tenant

Instructions for setting up new customer tenant where you need access to assist them through setup.

## Assumptions and Things to Know:
1) This use case assumes the customer owns the tenant.
2) The customer who was listed in the Deal Registration in Salesforce should be the one assigned as the owner of the tenant.
3) The Eval/Tenant request was approved and customer has received email(s) for access.  The welcome email the customer receives from Palo Alto Networks (noreply@prismacloud.paloaltonetworks.com) includes a link to where they can access their instance of Prisma Cloud.
4) There are **TWO (2)** layers of Access Required - **Customer Support Portal (CSP)** and **Prisma Cloud**  
**VERY IMPORTANT TO UNDERSTAND:** 
    - **IF you are the first registered user**, a Palo Alto Networks Customer Support Portal (CSP) account is created for you and you can log in to Prisma Cloud to start securing your cloud deployments.
    - **For all other Prisma Cloud users**, when your Prisma Cloud system administrator adds you to the tenant, you receive two emails. Use the *Welcome to Palo Alto Networks Support* email to activate the **CSP account** and set a password to access the Palo Alto Networks Support portal **before** you click *Get Started* in the *Welcome to Prisma Cloud* email to log in to your Prisma Cloud instance.
5) In order for additional users who already have a separate CSP account (i.e. a PANW SA or Partner Engineer's company's account) to obtain access to the customer tenant: 
    - the **Super User** of the customer Palo Alto Networks Customer Support Portal Account will need to manually add users to their account.
    - the **Owner/System Admin** of the Prisma Cloud tenant will need to manually add users to their new Prisma Cloud tenant.
    - If the customer you are working with is the first registered user, then they will be able to do both.  

## Steps 
1) Confirm customer can obtain access to their Prisma Cloud tenant. 
    - Refer to these instructions if needed: [Access Prisma Cloud](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin/get-started-with-prisma-cloud/access-prisma-cloud#id3d308e0b-921e-4cac-b8fd-f5a48521aa03)
2) Assist customer to add you as a User to their Customer Suppor Portal Account (https://support.paloaltonetworks.com).
    - Refer to these instructions: [Manage Users in Your CSP Account](https://knowledgebase.paloaltonetworks.com/KCSArticleDetail?id=kA10g000000ClNaCAK)
3) Assist customer to add you as a User to their Prisma Cloud tenant.
    - With the customer logged into their Prisma Cloud tenant, add new users: [Add Administrative Users On Prisma Cloud](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin/manage-prisma-cloud-administrators/add-prisma-cloud-users)
    - After clicking **Add User** have them fill in the form with your Name, Email, Assign 'System Admin' Role, and click Save and Close.    
    - This will automatically and immediately send an email to you, however:
**IMPORTANT NOTE:** As mentioned in the *Assumptions and Things to Know* section above, **THIS ALONE WILL NOT GRANT YOU ACCESS TO THE USERS TENANT.**  Ensure the Customer also already added you to their Customer Support Portal Account (Step 2 above).  If not, you most likely will be redirected to your Hub account but NOT able to see the new customer tenant in your list of accounts.  You need to be given access to **BOTH** the **Customer's CSP Account** and **Prisma Cloud tenant.**
4) Verify your own access to customer's account via Hub/Apps account page - https://apps.paloaltonetworks.com/apps
    - Click top right drop down and select the customer's account.
5) Verify your own access to customer's Prisma Cloud tenant.
    - From the **Welcome to Prisma Cloud** email you received, click the **Get Started** button.
    - OR if already on the Hub Account with the Customer Account selected, Select the Prisma Cloud App to access the customer tenant.
6) Enable initial configuration settings, including default policies
    - Navigate to **Settings > Enterprise Settings > Enable all Severity levels of Default Policies**
7) Enable additional Modules as agreed with the customer
    - Click the 'Person/Profile Icon' from the very bottom left of the Console > **Subscription > Enable desired Modules**
8) Assist Customer with setting up Cloud Account(s)
    - Refer to [Cloud Account Onboarding](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin/connect-your-cloud-platform-to-prisma-cloud/cloud-account-onboarding)


## Troubleshooting and Additional References:

### Alternative Method to Accessing Prisma Cloud - Legacy/Auth Signin Method - This eventually will be deprecated. Use only if needed.

1) Determine what App Stack this new tenant is assigned to.  You can do this by clicking the link in the email you received and look for one of the following app stacks under Step 1 of [Access Prisma Cloud](https://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin/get-started-with-prisma-cloud/access-prisma-cloud) 
2) Add `/auth/signin` to end of the url. For example:   
`https://app2.prismacloud.io/auth/signin`
3) This should bring up a login screen like this:

<img src="https://user-images.githubusercontent.com/31355989/162478211-b840b544-cb15-4a4c-8f50-6f003ab00fc2.png" width="300">

4) Click the 'Forgot Password'
5) Type in email and new password
6) Sign into tenant.  If you have access to mutiple tenants on this stack, choose the customer tenant you want to login into from the drop down list.


