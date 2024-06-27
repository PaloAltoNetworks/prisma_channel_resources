import os
import json
import logging
import base64
import urllib.request
import functions_framework
from urllib.parse import urlparse
from prismacloud.api import pc_api
from datetime import datetime
from cloudevents.http import CloudEvent
from google.cloud import secretmanager

# need to figure out where this goes...
logger = logging.getLogger()
    
# Triggered from a message on a Cloud Pub/Sub topic.
@functions_framework.cloud_event
def rollkey(cloud_event: CloudEvent) -> None:
    # allow admins to manually request a key roll using the folloiwng gcloud command: 
    #   gcloud pubsub topics publish prisma-cloud-key-rolling-topic --message="MANUAL_ROTATION_REQUESTED|projects/my_project_name/secrets/secret"
    check_for_manual = base64.b64decode(cloud_event.data["message"]["data"]).decode()
    #print( f"message data is this: {check_for_manual}" )
    
    if check_for_manual.startswith("MANUAL_ROTATION_REQUESTED"):
        secret_name = check_for_manual.split("|", 1)[1]
        print( f"Manual rotation of secret {secret_name} requested" )
        process_secret( secret_name )
    else:
        event_type = cloud_event.data["message"]["attributes"]["eventType"]
        secret_name = cloud_event.data["message"]["attributes"]["secretId"]
        print( f"event found of type: {event_type} for secret {secret_name}" )
        
        if event_type == "SECRET_VERSION_ADD":
            version = cloud_event.data["message"]["attributes"]["versionId"].split("/")[-1]
            print( f"secret version is: {version}" )
            if version == "1":
                # this was the first version on new creation.  let's roll it.
                print( "We found the first version of the secret" )
                process_secret( secret_name )
            else: 
                print( "New version added, but it's not the first." )
        elif event_type == "SECRET_ROTATE":
            print( "Looks like it is time to roll the secret" )
            process_secret( secret_name )
        else:
            print( "No need to process this event." )
    return 0

def process_secret( secret_name ):
    ###########################################################################
    ###########################################################################
    # 1. Get the current secret
    # 2. Create a PC API client
    # 3. Get the service account name
    # 4. Get the current users key(s) for the user
    # 5. Manage current keys - you can only have 2 keys
    # 6. Create the new key
    # 7. Log in with the new key
    # 8. Disable the current key
    # 9. Write the secret to GCP Secret Manager
    # 10. Disable the current version in GCP Secret Manager
    ###########################################################################
    ###########################################################################
    
    
    ###########################################################################
    # 1. Get the current secret
    ###########################################################################
    
    # create a secrets client
    secret_client = secretmanager.SecretManagerServiceClient()
    
    # set the project id
    project_id = get_project_id()
    
    # get the latest version of the secret
    secret_version = f"{secret_name}/versions/latest"
    
    # get the secret version
    secret_version_response = secret_client.access_secret_version(name=secret_version)
    
    # get the actual version number for later
    old_secret_version_number = secret_version_response.name
    
    # get the secret value
    current_secret_value = json.loads( secret_version_response.payload.data.decode("UTF-8") )

    ###########################################################################
    # 2. Create a PC API client  based on the current secret
    ###########################################################################
    
    settings = {
        "url": current_secret_value['PRISMA_CLOUD_CONSOLE_URL'],
        "identity": current_secret_value['PRISMA_CLOUD_USER'],
        "secret": current_secret_value['PRISMA_CLOUD_PASS']
    }
    pc_api.configure(settings)
    pc_api.logger = logger
       
    ###########################################################################
    # 3. Get the service account name
    ###########################################################################       
    
    # the email field is populated with the username even for service accounts
    current_user = pc_api.current_user().get('email')
    print( f"Current user is: {current_user}" )
    
    ###########################################################################
    # 4. Get the current users key(s) for the user
    ###########################################################################  
    
    pc_access_keys = pc_api.access_keys_list_read()
    service_account_keys = [] #array of dicts - key_id/status pairs
    for item in pc_access_keys:
        if item.get('username') == current_user:
            print( "found key for user: " + item.get('id') )
            service_account_keys.append( { 'id': item.get('id'), 'status': item.get('status') } )
    
    ###########################################################################
    # 5. Manage current keys - you can only have 2 keys
    ###########################################################################  
    
    if len(service_account_keys) == 2:
        for pc_access_key in service_account_keys:
            if pc_access_key['id'] != current_secret_value['PRISMA_CLOUD_USER']:
                print( "trying to delete: " + pc_access_key['id'] )
                pc_api.access_key_delete( pc_access_key['id'] )

    ###########################################################################
    # 6. Create the new key
    ###########################################################################   

    keyname = f'{current_user}-{datetime.now().strftime("%d%m%Y%H%M%S")}'
    new_pc_key = pc_api.access_key_create({"name": keyname, "serviceAccountName": current_user})
    print( f"created new key {keyname}")
    
    ###########################################################################
    # 7. Log in with the new key
    ###########################################################################   

    key_id_to_disable = current_secret_value['PRISMA_CLOUD_USER']
    print( f"found this key to disable - {key_id_to_disable}")
         
    # log in with the new key
    pc_api.token = None
    settings = {
        "url": current_secret_value['PRISMA_CLOUD_CONSOLE_URL'],
        "identity": new_pc_key['id'],
        "secret": new_pc_key['secretKey']
    }
    pc_api.configure(settings)
    pc_api.logger = logger
    
    ###########################################################################
    # 8. Disable the current key
    ###########################################################################  
    
    pc_api.access_key_status_update(key_id_to_disable,'false')
    print("successfully disabled current key %s." % (key_id_to_disable))

    ###########################################################################
    # 9. Write the secret to GCP Secret Manager
    ###########################################################################  
    
    print("Setting the current secret in the secrets manager")
    current_secret_value['PRISMA_CLOUD_USER'] = new_pc_key['id']
    current_secret_value['PRISMA_CLOUD_PASS'] = new_pc_key['secretKey']
    version = secret_client.add_secret_version( request={"parent": secret_name, "payload": {"data": bytes(json.dumps(current_secret_value), 'utf-8')  }})
    
    ###########################################################################
    # 10. Disable the current version in GCP Secret Manager
    ###########################################################################  
    
    destroy_response = secret_client.destroy_secret_version(request={"name": old_secret_version_number})
    print(f"Destroyed secret version: {destroy_response.name}")
  
def get_project_id():
    url = "http://metadata.google.internal/computeMetadata/v1/project/project-id"
    parsed_url = urlparse(url)

    allowed_schemes = ['http','https']
    if parsed_url.scheme not in allowed_schemes:
        raise ValueError(f"Disallowed scheme in URL: {parsed_url.scheme}")
        
    req = urllib.request.Request(url)
    req.add_header("Metadata-Flavor", "Google")
    try:
        response = urllib.request.urlopen(req)
        return response.read().decode()
    except urllib.error.URLError as e:
        print(f"Failed to retrieve project ID: {e}")
        return None
