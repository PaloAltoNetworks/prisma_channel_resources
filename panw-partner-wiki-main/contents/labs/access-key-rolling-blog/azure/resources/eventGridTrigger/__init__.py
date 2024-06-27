import os
import json
import logging
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential
from azure.identity import ManagedIdentityCredential
from prismacloud.api import pc_api
from datetime import datetime
import azure.functions as func

def main(event: func.EventGridEvent):
    logger = logging.getLogger()

    result = json.dumps({
        'id': event.id,
        'data': event.get_json(),
        'topic': event.topic,
        'subject': event.subject,
        'event_type': event.event_type,
    })

    logger.info('Python EventGrid trigger processed an event: %s', result)
    
    secret_name = event.get_json()['ObjectName']
    key_vault_name = event.get_json()['VaultName']
    
    # create a SecretClient client
    key_vault_uri = f"https://{key_vault_name}.vault.azure.net"    
    credential = ManagedIdentityCredential()
    az_secret_client = SecretClient(vault_url=key_vault_uri, credential=credential)

    # Get the current secret
    logger.info(f"Retrieving your secret from {key_vault_name}.")
    raw_secret = az_secret_client.get_secret(secret_name)
    current_secret = json.loads(raw_secret.value)
    
    # let's figure out what we have to do
    if event.event_type == "Microsoft.KeyVault.SecretNewVersionCreated":   
        # get a dict of tags
        if raw_secret.properties.tags is None or 'ROTATE_ON_INITIAL' not in raw_secret.properties.tags.keys() or raw_secret.properties.tags['ROTATE_ON_INITIAL'] != "true":
            logger.info("SecretNewVersionCreated event but we don't have to do anything. Exiting.")
            return None
    
    # Create a PC API client
    settings = {
        "url": current_secret['PRISMA_CLOUD_CONSOLE_URL'],
        "identity": current_secret['PRISMA_CLOUD_USER'],
        "secret": current_secret['PRISMA_CLOUD_PASS']
    }
    pc_api.configure(settings)
    pc_api.logger = logger
        
    # who am I? get the username from the current session
    # the email field is populated with the username even for service accounts
    current_user = pc_api.current_user().get('email')

    # get the current users key(s) for the user
    pc_access_keys = pc_api.access_keys_list_read()
    service_account_keys = [] #array of dicts - key_id/status pairs
    for item in pc_access_keys:
        if item.get('username') == current_user:
            service_account_keys.append( { 'id': item.get('id'), 'status': item.get('status') } )
    
    # you can only have 2 keys, so delete the one that's not current (if exists)
    if len(service_account_keys) == 2:
        for pc_access_key in service_account_keys:
            if pc_access_key['id'] != current_secret['PRISMA_CLOUD_USER']:
                pc_api.access_key_delete( pc_access_key['id'] )
                    
    # create the new key
    keyname = f'{current_user}-{datetime.now().strftime("%d%m%Y%H%M%S")}'
    new_pc_key = pc_api.access_key_create({"name": keyname, "serviceAccountName": current_user})
    
    # disable the current secret - but we can't be logged in as that or else it will error
    # first get the current (old)
    key_id_to_disable = current_secret['PRISMA_CLOUD_USER']
    logger.info("setSecret: found this key to disable - %s" % (key_id_to_disable))
         
    # log in with the new key
    pc_api.token = None
    settings = {
        "url": current_secret['PRISMA_CLOUD_CONSOLE_URL'],
        "identity": new_pc_key['id'],
        "secret": new_pc_key['secretKey']
    }
    pc_api.configure(settings)
    pc_api.logger = logger
    pc_api.access_key_status_update(key_id_to_disable,'false')
    logger.info("setSecret: Successfully disabled current key %s." % (key_id_to_disable))

    # if we got here, we successfully tested the new secret and disabled the existing
    # lets set the new secret
    logger.info("Setting the current secret in the Key Vault")
    current_secret['PRISMA_CLOUD_USER'] = new_pc_key['id']
    current_secret['PRISMA_CLOUD_PASS'] = new_pc_key['secretKey']
    az_secret_client.set_secret(secret_name, json.dumps(current_secret))
