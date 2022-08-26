#!/usr/bin/env bash
#------------------------------------------------------------------------------------------------------------------#
# Written By Kyle Butler
#
# REQUIREMENTS: 
# Requires jq to be installed: 'sudo apt-get install jq'
#

# the resource tags applied to ec2 instances. All three tags must be present in order for this report to generate. You must know the name of the tag keys in order for this to work. Case sensitive.

TAG_KEY_1="Supported By"
TAG_KEY_2="Environment"
TAG_KEY_3="Company"

# END OF USER CONFIG #######


source ./secrets/secrets
source ./func/func.sh



JSON_LOCATION=./temp
AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)


PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")

quick_check "/login"


PC_JWT=$(printf %s "$PC_JWT_RESPONSE" | jq -r '.token' )

INSTANCE_QUERY=$(cat <<EOF
{
  "query":"config from cloud.resource where api.name = 'aws-ec2-describe-instances'",
  "timeRange":{
     "type":"relative",
     "value":{
        "unit":"hour",
        "amount":24
     }
  }
}
EOF
)

INSTANCE_QUERY_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/search/config" \
                       --header 'content-type: application/json; charset=UTF-8' \
                       --header "x-redlock-auth: $PC_JWT" \
                       --data "$INSTANCE_QUERY")

quick_check "/search/config"

printf '%s' "$INSTANCE_QUERY_RESPONSE" | jq -r --arg tag_key_1 "$TAG_KEY_1" --arg tag_key_2 "$TAG_KEY_2" --arg tag_key_3 "$TAG_KEY_3" '[.data.items[] | {imageId: .data.imageId, id, firstTagKeyValue: .data.tags[], secondTagKeyValue: .data.tags[], thirdTagKeyValue: .data.tags[], name, accountId, accountName, regionId, regionName, instanceType: .data.instanceType} | select( .firstTagKeyValue.key == $tag_key_1) | select( .secondTagKeyValue.key == $tag_key_2 ) | select( .thirdTagKeyValue.key ==  $tag_key_3 )]' > "$JSON_LOCATION/temp_instance.json"



IMAGE_ARRAY=($(printf '%s' "$INSTANCE_QUERY_RESPONSE" | jq -r --arg tag_key_1 "$TAG_KEY_1" --arg tag_key_2 "$TAG_KEY_2" --arg tag_key_3 "$TAG_KEY_3" '.data.items[] | {imageId: .data.imageId, id, firstTagKeyValue: .data.tags[], secondTagKeyValue: .data.tags[], thirdTagKeyValue: .data.tags[], name, accountId, accountName, regionId, regionName, instanceType: .data.instanceType} | select( .firstTagKeyValue.key == $tag_key_1) | select( .secondTagKeyValue.key == $tag_key_2 ) | select( .thirdTagKeyValue.key ==  $tag_key_3 ) | .imageId ' ))

for image in "${!IMAGE_ARRAY[@]}"; do \

IMAGE_QUERY=$(cat <<EOF
{
  "query":"config from cloud.resource where api.name = 'aws-ec2-describe-images' AND json.rule = image.imageId equals ${IMAGE_ARRAY[image]}",
  "timeRange":{
    "type":"relative",
    "value":{
      "unit":"hour",
       "amount":24
     }
    }
  }
EOF
)




curl -s --request POST \
     --url "$PC_APIURL/search/config" \
     --header 'content-type: application/json; charset=UTF-8' \
     --header "x-redlock-auth: $PC_JWT" \
     --data "$IMAGE_QUERY" | jq '.data.items[] | {platformDetails: .data.image.platformDetails?, usageOperation: .data.image.usageOperation?, imageId: .data.image.imageId?}' > "$JSON_LOCATION/temp_image_$(printf '%05d' "$image").json" &

done
wait

cat $JSON_LOCATION/temp_image_* | jq '[inputs]' > $JSON_LOCATION/temp_complete_image.json

REPORT_DATE=$(date  +%m_%d_%y)

cat $JSON_LOCATION/temp_instance.json | jq -r '. | map({id, firstTagKeyValue, secondTagKeyValue, thirdTagKeyValue ,name, accountId, accountName, regionId, regionName, instanceType, imageId, imageInfo: [.imageId as $imageId | $imagedata |..| select(.imageId? and .imageId==$imageId)]})' --slurpfile imagedata $JSON_LOCATION/temp_complete_image.json | jq -r '[.[] | {ec2Id: .id, firstTagKey: .firstTagKeyValue.key, firstTagValue: .firstTagKeyValue.value, secondTagKey: .secondTagKeyValue.key, secondTagValue: .secondTagKeyValue.value, thirdTagKey: .thirdTagKeyValue.key, thirdTagValue: .thirdTagKeyValue.value, name, accountId, accountName, regionId, regionName, instanceType, imageId, platformDetails: .imageInfo[].platformDetails, usageOperation: .imageInfo[].usageOperation, checkImageId: .imageInfo[].imageId}] | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' > ./reports/aws_instance_image_report_"$REPORT_DATE".csv


{
rm ./temp/*
}

printf '\n%s\n\n' "All done! Your report is saved in the ./reports directory as: aws_instance_image_report_$REPORT_DATE.csv"


exit


