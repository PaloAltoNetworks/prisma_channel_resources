import os
import sys
import json
import logging
import requests
from prismacloud.api import pc_api
from datetime import datetime
from base64 import b64encode
from nacl import encoding, public

logger = logging.getLogger()

def main_function():
    ###########################################################################
    ###########################################################################
    # 1. Get the current secret from the environment
    # 2. Create a PC API client
    # 3. Get the service account name
    # 4. Get the current users key(s) for the user
    # 5. Manage current keys - you can only have 2 keys
    # 6. Create the new key
    # 7. Log in with the new key
    # 8. Disable the current key
    # 9. Write the secret to GitHub
    ###########################################################################
    ###########################################################################
    
    
    ###########################################################################
    # 1. Get the current secret and console url
    ###########################################################################
    github_secret_pc_access_key_name = os.environ[ 'PRISMA_CLOUD_ACCESS_KEY_SECRET_NAME' ]
    github_secret_pc_secret_key_name = os.environ[ 'PRISMA_CLOUD_SECRET_KEY_SECRET_NAME' ]
    current_pc_access_key = os.environ[ github_secret_pc_access_key_name ]
    current_pc_secret_key = os.environ[ github_secret_pc_secret_key_name ]
    pc_console_url = os.environ[ 'PRISMA_CLOUD_CONSOLE_URL' ]
    
    ###########################################################################
    # 2. Create a PC API client  based on the current secret
    ###########################################################################
    
    settings = {
        "url":     pc_console_url,
        "identity": current_pc_access_key,
        "secret":   current_pc_secret_key
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
            if pc_access_key['id'] != current_pc_access_key:
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

    key_id_to_disable = current_pc_access_key
    print( f"found this key to disable - {key_id_to_disable}")
         
    # log in with the new key
    pc_api.token = None
    settings = {
        "url":     pc_console_url,
        "identity": new_pc_key['id'],
        "secret":   new_pc_key['secretKey']
    }
    pc_api.configure(settings)
    pc_api.logger = logger
    
    ###########################################################################
    # 8. Disable the current key
    ###########################################################################  
    
    pc_api.access_key_status_update(key_id_to_disable,'false')
    print("successfully disabled current key %s." % (key_id_to_disable))

    ###########################################################################
    # 9. Write the new secret to Github
    ###########################################################################  
    print("Updating the secret in GitHub")
    github_token = os.environ['PERSONAL_ACCESS_TOKEN']
    owner_repository = os.environ['OWNER_REPOSITORY']

    for repos in [x.strip() for x in owner_repository.split(',')]:
        # get repo pub key info
        (public_key, pub_key_id) = get_pub_key(repos, github_token)

        # encrypt the secrets
        encrypted_access_key = encrypt(public_key, new_pc_key['id'])
        encrypted_secret_key = encrypt(public_key, new_pc_key['secretKey'])

        # upload secrets
        upload_secret(repos, github_secret_pc_access_key_name, encrypted_access_key, pub_key_id, github_token)
        upload_secret(repos, github_secret_pc_secret_key_name, encrypted_secret_key, pub_key_id, github_token)
  
def encrypt(public_key: str, secret_value: str) -> str:
    public_key = public.PublicKey(public_key.encode("utf-8"), encoding.Base64Encoder())
    sealed_box = public.SealedBox(public_key)
    encrypted = sealed_box.encrypt(secret_value.encode("utf-8"))
    return b64encode(encrypted).decode("utf-8")


def get_pub_key(owner_repo, github_token):
    # get public key for encrypting
    endpoint = f'https://api.github.com/repos/{owner_repo}/actions/secrets/public-key'
    pub_key_ret = requests.get(
        endpoint,
        headers={'Authorization': f"token {github_token}"}
    )

    if not pub_key_ret.status_code == requests.codes.ok:
        print( f"github public key request failed: {pub_key_ret.text}")
        sys.exit(1)

    # convert to json
    public_key_info = pub_key_ret.json()

    # extract values
    public_key = public_key_info['key']
    public_key_id = public_key_info['key_id']

    return (public_key, public_key_id)

def upload_secret(owner_repo, key_name, encrypted_value, pub_key_id, github_token):
    endpoint = f'https://api.github.com/repos/{owner_repo}/actions/secrets/{key_name}'
    updated_secret = requests.put(
        endpoint,
        json={
            'encrypted_value': encrypted_value,
            'key_id': pub_key_id
        },
        headers={'Authorization': f"token {github_token}"}
    )

    if updated_secret.status_code not in [204, 201]:
        print(f'Update returned status code: {updated_secret.status_code}')
        sys.exit(1)

    print(f'Updated: {key_name} in {owner_repo}')    
        
# run it!
main_function()
