import boto3
import logging
import os
import json
from prismacloud.api import pc_api
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

'''
AWS published sample code for a custom lambda function, here:
https://github.com/aws-samples/aws-secrets-manager-rotation-lambdas/blob/master/SecretsManagerRotationTemplate/lambda_function.py
Using that as a template, we updated create_secret(), set_secret(), and test_secret() to 
create and manage access keys in Prisma Cloud.
'''

def lambda_handler(event, context):
    arn = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']

    service_client = boto3.client('secretsmanager')
    
    # Make sure the version is staged correctly
    metadata = service_client.describe_secret(SecretId=arn)
    if not metadata['RotationEnabled']:
        logger.error("Secret %s is not enabled for rotation" % arn)
        raise ValueError("Secret %s is not enabled for rotation" % arn)
    versions = metadata['VersionIdsToStages']
    if token not in versions:
        logger.error("Secret version %s has no stage for rotation of secret %s." % (token, arn))
        raise ValueError("Secret version %s has no stage for rotation of secret %s." % (token, arn))
    if "AWSCURRENT" in versions[token]:
        logger.info("Secret version %s already set as AWSCURRENT for secret %s." % (token, arn))
        return
    elif "AWSPENDING" not in versions[token]:
        logger.error("Secret version %s not set as AWSPENDING for rotation of secret %s." % (token, arn))
        raise ValueError("Secret version %s not set as AWSPENDING for rotation of secret %s." % (token, arn))

    if step == "createSecret":
        create_secret(service_client, arn, token)

    elif step == "setSecret":
        set_secret(service_client, arn, token)

    elif step == "testSecret":
        test_secret(service_client, arn, token)

    elif step == "finishSecret":
        finish_secret(service_client, arn, token)

    else:
        raise ValueError("Invalid step parameter")


def create_secret(service_client, arn, token):
    # Make sure the current secret exists
    get_secret_value_response = service_client.get_secret_value(SecretId=arn, VersionStage="AWSCURRENT")
    
    # Now try to get the secret version, if that fails, put a new secret
    try:
        service_client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
        logger.info("createSecret: Successfully retrieved secret for %s." % arn)
    except service_client.exceptions.ResourceNotFoundException:
        # use the current secret to connect to PC
        pc_admin_credentials = json.loads(get_secret_value_response['SecretString'])
        settings = {
            "url": pc_admin_credentials['PRISMA_CLOUD_CONSOLE_URL'],
            "identity": pc_admin_credentials['PRISMA_CLOUD_USER'],
            "secret": pc_admin_credentials['PRISMA_CLOUD_PASS']
        }
        
        # reset the pc_api token
        pc_api.token = None
    
        pc_api.configure(settings)
        pc_api.logger = logger
        
        # who am I? get the username from the current session
        # the email field is populated with the username even for service accounts
        current_user = pc_api.current_user().get('email')
        
        # Get the current users key(s) for the user  
        pc_access_keys = pc_api.access_keys_list_read()
        service_account_keys = [] #array of dicts - key_id/status pairs
        for item in pc_access_keys:
            if item.get('username') == current_user:
                logger.info( "found key for user: " + item.get('id') )
                service_account_keys.append( { 'id': item.get('id'), 'status': item.get('status') } )
                
        # you can only have 2 keys, so delete the one that's not current (if exists)
        if len(service_account_keys) == 2:
            for pc_access_key in service_account_keys:
                if pc_access_key['id'] != pc_admin_credentials['PRISMA_CLOUD_USER']:
                    logger.info( "trying to delete: " + pc_access_key['id'] )
                    pc_api.access_key_delete( pc_access_key['id'] )
                    
        # create the new key
        keyname = f'{current_user}-{datetime.now().strftime("%d%m%Y%H%M%S")}'
        new_pc_key = pc_api.access_key_create({"name": keyname, "serviceAccountName": current_user}) 
        
        # use the values in the old secret to update the new secret...there 
        # may be some additional info (e.g. CONSOLE_URL) that we don't want
        # to throw away
        pc_admin_credentials['PRISMA_CLOUD_USER'] = new_pc_key['id']
        pc_admin_credentials['PRISMA_CLOUD_PASS'] = new_pc_key['secretKey']
        service_client.put_secret_value(SecretId=arn, ClientRequestToken=token, SecretString=json.dumps(pc_admin_credentials), VersionStages=['AWSPENDING'])
        logger.info("createSecret: Successfully put secret for ARN %s and version %s." % (arn, token))


def set_secret(service_client, arn, token):
    logger.info("setSecret: entering set_secret")
    # disable the current secret - but we can't be logged in as that or else it will error
    # first get the current (old)
    get_secret_value_response = service_client.get_secret_value(SecretId=arn, VersionStage="AWSCURRENT")
    current_credentials = json.loads(get_secret_value_response['SecretString'])
    key_id_to_disable = current_credentials['PRISMA_CLOUD_USER']
    logger.info("setSecret: found this key to delete - %s" % (key_id_to_disable))
    
    # now get the new key
    get_secret_value_response = service_client.get_secret_value(SecretId=arn, VersionStage="AWSPENDING")
    new_credentials = json.loads(get_secret_value_response['SecretString'])
     
    logger.info("setSecret: found new creds in AWSPENDING - %s" % (new_credentials['PRISMA_CLOUD_USER']))
    
    # reset the token
    pc_api.token = None
    
    settings = {
        "url": new_credentials['PRISMA_CLOUD_CONSOLE_URL'],
        "identity": new_credentials['PRISMA_CLOUD_USER'],
        "secret": new_credentials['PRISMA_CLOUD_PASS']
    }
    pc_api.configure(settings)
    pc_api.logger = logger
    pc_api.access_key_status_update(key_id_to_disable,'false')
    logger.info("setSecret: Successfully disabled current key %s." % (key_id_to_disable))

def test_secret(service_client, arn, token):
    get_secret_value_response = service_client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
    pc_admin_credentials = json.loads(get_secret_value_response['SecretString'])
    settings = {
        "url": pc_admin_credentials['PRISMA_CLOUD_CONSOLE_URL'],
        "identity": pc_admin_credentials['PRISMA_CLOUD_USER'],
        "secret": pc_admin_credentials['PRISMA_CLOUD_PASS']
    }
    
    # reset the pc_api token
    pc_api.token = None
    
    pc_api.configure(settings)
    pc_api.logger = logger
    pc_api.current_user()
    logger.info("testSecret: Successfully tested new key %s." % (pc_admin_credentials['PRISMA_CLOUD_USER']))

def finish_secret(service_client, arn, token):
    # First describe the secret to get the current version
    metadata = service_client.describe_secret(SecretId=arn)
    current_version = None
    for version in metadata["VersionIdsToStages"]:
        if "AWSCURRENT" in metadata["VersionIdsToStages"][version]:
            if version == token:
                # The correct version is already marked as current, return
                logger.info("finishSecret: Version %s already marked as AWSCURRENT for %s" % (version, arn))
                return
            current_version = version
            break

    # Finalize by staging the secret version current
    service_client.update_secret_version_stage(SecretId=arn, VersionStage="AWSCURRENT", MoveToVersionId=token, RemoveFromVersionId=current_version)
    logger.info("finishSecret: Successfully set AWSCURRENT stage to version %s for secret %s." % (token, arn))
  
