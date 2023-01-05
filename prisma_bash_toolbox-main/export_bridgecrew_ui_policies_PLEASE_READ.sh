#!/usr/bin/env bash
#------------------------------------------------------------------------------------------------------------------#
# Written By Kyle Butler
#
# REQUIREMENTS:
# Requires jq to be installed: 'sudo apt-get install jq'
#
# SET-UP:
# Create Access Key and Secret Key in the Prisma Cloud Console
# Access keys and Secret keys are created in the Prisma Cloud Console under: Settings > Access Keys
# Find the Prisma Cloud Enterprise Edition API URL specific to your deployment: https://prisma.pan.dev/api/cloud/api-url
#
# INFO:
# Exports all the UI custom policies written as code from the BridgeCrew console and attempts to transform them into their yaml syntax
#
# LIMITATIONS AND WARNINGS
# This will only work if you have simple custom UI policies in the BridgeCrew Console. Meaning you don't have more than one layer of nesting of rules/conditions.
# If this doesn't make sense to you I'd suggest manually trying to bring the policies over.
# Additonally, the policies will not be able to be modified using the GUI after they've been transformed into their code syntax. So ensure
# You're familar with the YAML policy syntax located here: https://docs.bridgecrew.io/docs/examples-yaml-based-custom-policies
# Also, the compliance mappings will be lost if you've mapped the policies to a framework. I plan to add that later on, but there's no timeline to that.
# The script will ask you to respond before it attempts to upload the policies into the prisma cloud console. Recommend reviewing the files if you're unsure.
#
# SUPPORT
# This is a community project and the script is offered as is without any official support. Please review the SUPPORT.md file before running this script.


source ./secrets/secrets
source ./func/func.sh

# CREATE BRIDGECREW API KEY IN BRIDGECREW CONSOLE AND ASSIGN IT TO THE VAR BELOW
BC_API_KEY="<BC_API_KEY>"

####### END OF USER CONFIGURATION ##############################################################################################################################

REPORT_DATE=$(date  +%m_%d_%y)

BRIDGECREW_POLICY_RESPONSE=$(curl --request GET \
                                   --url https://www.bridgecrew.cloud/api/v1/policies/table/data \
                                   --header 'Accept: application/json' \
                                   --header "authorization: $BC_API_KEY")

quick_check "https://www.bridgecrew.cloud/api/v1/policies/table/data"

printf '%s' "$BRIDGECREW_POLICY_RESPONSE" > ./temp/bridgecrew_policies_table_data.json

REPORT_DATE=$(date  +%m_%d_%y)

# Gets the number of custom UI policies
BC_UI_CUSTOM_POLICY_NUMBER=$(jq '[.data[] | select( .isCustom == true) | select(.code == null)] | length' < ./temp/bridgecrew_policies_table_data.json)

# Reads the export out from the BC API and then seperates the UI policies into a seperate file
jq '[.data[] | select( .isCustom == true) | select(.code == null)]' < ./temp/bridgecrew_policies_table_data.json > ./temp/bridgecrew_ui_policies.json

# Subtract once so it works with seq and indexing for the "for" loops below
BC_UI_NUMBER_MINUS_ONE=$(( "$BC_UI_CUSTOM_POLICY_NUMBER" - 1 ))

# Reads in the UI policies files and breaks apart the policies into their own seperate files in the temp folder. Example: ./temp/ui_policy_0001.json and so on. 
for number in $(seq 0 "$BC_UI_NUMBER_MINUS_ONE"); do

  jq --argjson number "$number" '.[$number]'  < ./temp/bridgecrew_ui_policies.json > "./temp/ui_policy_$(printf '%04d' "$number").json"

done

# Essentially a list of the sperated UI policies
BC_SEPERATED_UI_POLICIES="./temp/ui_policy_*.json"


# For loop for processing each custom ui policy file.
for bc_ui_policy in $BC_SEPERATED_UI_POLICIES; do

# There's a thousand other ways to do this. This was the first one that popped into my head. Essentially removes the relative path from the file name
BC_POLICY_FILE_NAME_ONLY=$(printf '%s' "$bc_ui_policy" | sed 's/\.\/temp\///g')

# Checks if there's a single policy condition for the policy and there aren't multiple conditional statements. Checks the JSON to see if there's anything assigned to the values along the path.
  if [[ -z "$(jq '.conditionQuery.and[]?' < "$bc_ui_policy" )" ]] && [[ -z "$(jq '.conditionQuery.or[]?' < "$bc_ui_policy" )" ]]; then

title=$(jq '.title' < "$bc_ui_policy")
guideline=$(jq '.guideline' < "$bc_ui_policy")
category=$(jq '.category' < "$bc_ui_policy" | tr '[:upper:]' '[:lower:]')
severity=$(jq '.pcSeverity' < "$bc_ui_policy")
provider=$(jq '.provider' < "$bc_ui_policy" | tr '[:upper:]' '[:lower:]')
cond_type=$(jq '.conditionQuery.cond_type' < "$bc_ui_policy")
resource_types=$(jq '.conditionQuery.resource_types[]' < "$bc_ui_policy")
attribute=$(jq '.conditionQuery.attribute' < "$bc_ui_policy")
operator=$(jq '.conditionQuery.operator' < "$bc_ui_policy")
value=$(jq '.conditionQuery.value' < "$bc_ui_policy")


BC_UI_EXPORT=$(cat <<EOF
---
metadata:
  name: $title
  guidelines: $guideline
  category: $category
  severity: $severity
scope:
  provider: $provider
  definition:
EOF
)

BC_UI_EXPORT_AND_ARRAY=$(cat <<EOF
    and:
EOF
)

BC_UI_EXPORT_PARAMETERS=$(cat <<EOF
     - cond_type: $cond_type
       resource_types:
         - $resource_types
       attribute: $attribute
       operator: $operator
       value: $value
EOF
)

# create a policy code file

CODE=$(printf '%s\n%s\n%s\n' "$BC_UI_EXPORT" "$BC_UI_EXPORT_AND_ARRAY" "$BC_UI_EXPORT_PARAMETERS")

# final transform
jq --arg CODE "$CODE" --arg DATE "$REPORT_DATE" '. | {cloudType: .provider, complianceMetadata: [], description: .guideline, labels: [], name: (.title + "_" + $DATE), policySubTypes: ["build"], policyType: "config", recommendation: "", rule: { children: [{metadata: {code: $CODE}, type: "build", recommendation: ""}], name:  (.title + "_" + $DATE), parameters: {savedSearch: "false", withIac: "true"}, type: "Config" }, severity: .severity }' < "$bc_ui_policy" | sed 's/\"severity\"\: \"CRITICAL\"/\"severity\"\: \"HIGH\"  /g'  > "./temp/finished_$BC_POLICY_FILE_NAME_ONLY"

# If there are no  "or" conditions in the policy but multiple AND statements
  elif [[ -n "$(jq '.conditionQuery.and[]?' < "$bc_ui_policy" )" ]] && [[ -z "$(jq '.conditionQuery.and[]?.or[]?' < "$bc_ui_policy" )" ]]; then

number_of_conditions=$(jq -r '.conditionQuery.and? | length' < "$bc_ui_policy")
number_of_conditions_minus_one=$(( "$number_of_conditions" - 1))

  for condition in $(seq 0 "$number_of_conditions_minus_one"); do

title=$(jq '.title' < "$bc_ui_policy")
guideline=$(jq '.guideline' < "$bc_ui_policy")
category=$(jq '.category' < "$bc_ui_policy" | tr '[:upper:]' '[:lower:]')
severity=$(jq '.pcSeverity' < "$bc_ui_policy")
provider=$(jq '.provider' < "$bc_ui_policy" | tr '[:upper:]' '[:lower:]')


cond_type=$(jq --argjson condition "$condition" '.conditionQuery.and[$condition].cond_type' < "$bc_ui_policy")
resource_types=$(jq --argjson condition "$condition" '.conditionQuery.and[$condition].resource_types[]' < "$bc_ui_policy")
attribute=$(jq  --argjson condition "$condition" '.conditionQuery.and[$condition].attribute' < "$bc_ui_policy")
operator=$(jq  --argjson condition "$condition" '.conditionQuery.and[$condition].operator' < "$bc_ui_policy")
value=$(jq  --argjson condition "$condition" '.conditionQuery.and[$condition].value' < "$bc_ui_policy")


BC_UI_EXPORT=$(cat <<EOF
---
metadata:
  name: $title
  guidelines: $guideline
  category: $category
  severity: $severity
scope:
  provider: $provider
  definition:
EOF
)

BC_UI_EXPORT_AND_ARRAY=$(cat <<EOF
    and:
EOF
)

BC_UI_EXPORT_PARAMETERS=$(cat <<EOF
     - cond_type: $cond_type
       resource_types:
         - $resource_types
       attribute: $attribute
       operator: $operator
       value: $value
EOF
)

touch "./temp/$(printf '%03d_%s' "$condition" "$BC_POLICY_FILE_NAME_ONLY")"

printf '%s\n' "$BC_UI_EXPORT_PARAMETERS" >> "./temp/$(printf '%03d_%s' "$condition" "$BC_POLICY_FILE_NAME_ONLY")"

FULL_CONDITIONS=$(cat ./temp/0*_"$BC_POLICY_FILE_NAME_ONLY")

CODE=$(printf '%s\n%s\n%s\n' "$BC_UI_EXPORT" "$BC_UI_EXPORT_AND_ARRAY" "$FULL_CONDITIONS" )

# final transform
jq --arg CODE "$CODE" --arg DATE "$REPORT_DATE" '. | {cloudType: .provider, complianceMetadata: [], description: .guideline, labels: [], name: (.title + "_" + $DATE), policySubTypes: ["build"], policyType: "config", recommendation: "", rule: { children: [{metadata: {code: $CODE}, type: "build", recommendation: ""}], name:  (.title + "_" + $DATE), parameters: {savedSearch: "false", withIac: "true"}, type: "Config" }, severity: .severity }' < "$bc_ui_policy" |sed 's/\"severity\"\: \"CRITICAL\"/\"severity\"\: \"HIGH\"  /g' > "./temp/finished_$BC_POLICY_FILE_NAME_ONLY"


done

# if there's multiple "or" statements between policy condtions and no "and" statements
  elif [[ -z "$(jq '.conditionQuery.and[]?' < "$bc_ui_policy" )" ]] && [[ -n "$(jq '.conditionQuery.or[]?' < "$bc_ui_policy" )" ]]; then


number_of_conditions=$(jq -r '.conditionQuery.or? | length' < "$bc_ui_policy")
number_of_conditions_minus_one=$(( "$number_of_conditions" - 1))

  for condition in $(seq 0 "$number_of_conditions_minus_one"); do

title=$(jq '.title' < "$bc_ui_policy")
guideline=$(jq '.guideline' < "$bc_ui_policy")
category=$(jq '.category' < "$bc_ui_policy" | tr '[:upper:]' '[:lower:]')
severity=$(jq '.pcSeverity' < "$bc_ui_policy")
provider=$(jq '.provider' < "$bc_ui_policy" | tr '[:upper:]' '[:lower:]')


cond_type=$(jq --argjson condition "$condition" '.conditionQuery.or[$condition].cond_type' < "$bc_ui_policy")
resource_types=$(jq --argjson condition "$condition" '.conditionQuery.or[$condition].resource_types[]' < "$bc_ui_policy")
attribute=$(jq  --argjson condition "$condition" '.conditionQuery.or[$condition].attribute' < "$bc_ui_policy")
operator=$(jq  --argjson condition "$condition" '.conditionQuery.or[$condition].operator' < "$bc_ui_policy")
value=$(jq  --argjson condition "$condition" '.conditionQuery.or[$condition].value' < "$bc_ui_policy")


BC_UI_EXPORT=$(cat <<EOF
---
metadata:
  name: $title
  guidelines: $guideline
  category: $category
  severity: $severity
scope:
  provider: $provider
  definition:
EOF
)

BC_UI_EXPORT_OR_ARRAY=$(cat <<EOF
    or:
EOF
)

BC_UI_EXPORT_PARAMETERS=$(cat <<EOF
     - cond_type: $cond_type
       resource_types:
         - $resource_types
       attribute: $attribute
       operator: $operator
       value: $value
EOF
)

touch "./temp/$(printf '%03d_%s' "$condition" "$BC_POLICY_FILE_NAME_ONLY")"

printf '%s\n' "$BC_UI_EXPORT_PARAMETERS" >> "./temp/$(printf '%03d_%s' "$condition" "$BC_POLICY_FILE_NAME_ONLY")"


FULL_CONDITIONS=$(cat ./temp/0*_"$BC_POLICY_FILE_NAME_ONLY")

CODE=$(printf '%s\n%s\n%s\n' "$BC_UI_EXPORT" "$BC_UI_EXPORT_OR_ARRAY" "$FULL_CONDITIONS")

# final transform
jq --arg CODE "$CODE" --arg DATE "$REPORT_DATE" '. | {cloudType: .provider, complianceMetadata: [], description: .guideline, labels: [], name: (.title + "_" + $DATE), policySubTypes: ["build"], policyType: "config", recommendation: "", rule: { children: [{metadata: {code: $CODE}, type: "build", recommendation: ""}], name:  (.title + "_" + $DATE), parameters: {savedSearch: "false", withIac: "true"}, type: "Config" }, severity: .severity }' < "$bc_ui_policy" | sed 's/\"severity\"\: \"CRITICAL\"/\"severity\"\: \"HIGH\"  /g' > "./temp/finished_$BC_POLICY_FILE_NAME_ONLY"

done

# if there's multiple "and" statements between policy condtions and nested "or" statements. Currently will only work with two layers
  elif [[ -n "$(jq -r '.conditionQuery.and[]?' < "$bc_ui_policy" )" ]] && [[ -n "$(jq -r '.conditionQuery.and[]?.or[]?' < "$bc_ui_policy" )" ]]; then

number_of_unested_and_conditions=$(jq -r '[.conditionQuery.and[]?| select( .or == null)] | length' < "$bc_ui_policy")
number_of_and_conditions_minus_one=$(( "$number_of_unested_and_conditions" - 1))
filtered_and_bc_ui_policy=$(jq '[.conditionQuery.and[] | select(.or == null)]' < "$bc_ui_policy")

  for and_condition in $(seq 0 "$number_of_and_conditions_minus_one"); do


title=$(jq '.title' < "$bc_ui_policy")
guideline=$(jq '.guideline' < "$bc_ui_policy")
category=$(jq '.category' < "$bc_ui_policy" | tr '[:upper:]' '[:lower:]')
severity=$(jq '.pcSeverity' < "$bc_ui_policy")
provider=$(jq '.provider' < "$bc_ui_policy" | tr '[:upper:]' '[:lower:]')


cond_type=$(printf '%s' "$filtered_and_bc_ui_policy" | jq --argjson and_condition "$and_condition" '.[$and_condition].cond_type')
resource_types=$(printf '%s' "$filtered_and_bc_ui_policy" | jq --argjson and_condition "$and_condition" '.[$and_condition].resource_types[]')
attribute=$(printf '%s' "$filtered_and_bc_ui_policy" | jq  --argjson and_condition "$and_condition" '.[$and_condition].attribute')
operator=$(printf '%s' "$filtered_and_bc_ui_policy" | jq  --argjson and_condition "$and_condition" '.[$and_condition].operator')
value=$(printf '%s' "$filtered_and_bc_ui_policy" | jq  --argjson and_condition "$and_condition" '.[$and_condition].value')


BC_UI_EXPORT=$(cat <<EOF
---
metadata:
  name: $title
  guidelines: $guideline
  category: $category
  severity: $severity
scope:
  provider: $provider
  definition:
EOF
)

BC_UI_EXPORT_AND_ARRAY=$(cat <<EOF
    and:
EOF
)

BC_UI_EXPORT_AND_PARAMETERS=$(cat <<EOF
     - cond_type: $cond_type
       resource_types:
         - $resource_types
       attribute: $attribute
       operator: $operator
       value: $value
EOF
)

touch "./temp/$(printf '%s_%03d_%s' "and" "$and_condition" "$BC_POLICY_FILE_NAME_ONLY")"

if [[ -n "$value" ]]; then
printf '%s\n' "$BC_UI_EXPORT_AND_PARAMETERS" >> "./temp/$(printf '%s_%03d_%s' "and" "$and_condition" "$BC_POLICY_FILE_NAME_ONLY")"
fi

done

number_of_nested_or_conditions=$(jq -r '[.conditionQuery.and[].or[]?] | length' < "$bc_ui_policy")
number_of_nested_or_conditions_minus_one=$(( "$number_of_nested_or_conditions" - 1))
filtered_bc_ui_policy_or=$(jq '[.conditionQuery.and[]?.or[]?]' < "$bc_ui_policy")


  for or_condition in $(seq 0 "$number_of_nested_or_conditions_minus_one"); do


title=$(jq '.title' < "$bc_ui_policy")
guideline=$(jq '.guideline' < "$bc_ui_policy")
category=$(jq '.category' < "$bc_ui_policy" |tr '[:upper:]' '[:lower:]')
severity=$(jq '.pcSeverity' < "$bc_ui_policy")
provider=$(jq '.provider' < "$bc_ui_policy" | tr '[:upper:]' '[:lower:]')


cond_type=$(printf '%s' "$filtered_bc_ui_policy_or" | jq --argjson or_condition "$or_condition" '.[$or_condition].cond_type')
resource_types=$(printf '%s' "$filtered_bc_ui_policy_or" | jq --argjson or_condition "$or_condition" '.[$or_condition].resource_types[]')
attribute=$(printf '%s' "$filtered_bc_ui_policy_or"| jq  --argjson or_condition "$or_condition" '.[$or_condition].attribute')
operator=$(printf '%s' "$filtered_bc_ui_policy_or" | jq  --argjson or_condition "$or_condition" '.[$or_condition].operator')
value=$(printf '%s' "$filtered_bc_ui_policy_or" | jq  --argjson or_condition "$or_condition" '.[$or_condition].value')

BC_UI_EXPORT=$(cat <<EOF
---
metadata:
  name: $title
  guidelines: $guideline
  category: $category
  severity: $severity
scope:
  provider: $provider
  definition:
EOF
)

BC_UI_EXPORT_AND_ARRAY=$(cat <<EOF
    and:
EOF
)

BC_UI_EXPORT_NESTED_OR_ARRAY=$(cat <<EOF
     - or:
EOF
)

BC_UI_EXPORT_NESTED_OR_PARAMETERS=$(cat <<EOF
         - cond_type: $cond_type
           resource_types:
             - $resource_types
           attribute: $attribute
           operator: $operator
           value: $value
EOF
)
touch "./temp/$(printf '%s_%03d_%s' "or" "$or_condition" "$BC_POLICY_FILE_NAME_ONLY")"

if [[ -n "$value" ]]; then
printf '%s\n' "$BC_UI_EXPORT_NESTED_OR_PARAMETERS" >> "./temp/$(printf '%s_%03d_%s' "or" "$or_condition" "$BC_POLICY_FILE_NAME_ONLY")"
fi

done

FULL_AND_CONDITIONS=$(cat ./temp/and_0*_"$BC_POLICY_FILE_NAME_ONLY")
FULL_NESTED_OR_CONDITIONS=$(cat ./temp/or_0*_"$BC_POLICY_FILE_NAME_ONLY")

CODE=$(printf '%s\n%s\n%s\n%s\n%s\n' "$BC_UI_EXPORT" "$BC_UI_EXPORT_AND_ARRAY" "$FULL_AND_CONDITIONS" "$BC_UI_EXPORT_NESTED_OR_ARRAY" "$FULL_NESTED_OR_CONDITIONS")

# final transform
jq --arg CODE "$CODE" --arg DATE "$REPORT_DATE" '. | {cloudType: .provider, complianceMetadata: [], description: .guideline, labels: [], name: (.title + "_" + $DATE), policySubTypes: ["build"], policyType: "config", recommendation: "", rule: { children: [{metadata: {code: $CODE}, type: "build", recommendation: ""}], name:  (.title + "_" + $DATE), parameters: {savedSearch: "false", withIac: "true"}, type: "Config" }, severity: .severity }' < "$bc_ui_policy" |sed 's/\"severity\"\: \"CRITICAL\"/\"severity\"\: \"HIGH\"  /g' > "./temp/finished_$BC_POLICY_FILE_NAME_ONLY"


# if there's multiple "or" statements between policy condtions and nested "and" statements. Currently will only work with two layers
  elif [[ -n "$(jq -r '.conditionQuery.or[]?' < "$bc_ui_policy" )" ]] && [[ -n "$(jq -r '.conditionQuery.or[]?.and[]?' < "$bc_ui_policy" )" ]]; then

number_of_unested_or_conditions=$(jq -r '[.conditionQuery.or[]?| select( .and == null)] | length' < "$bc_ui_policy")
number_of_or_conditions_minus_one=$(( "$number_of_unested_or_conditions" - 1))
filtered_or_bc_ui_policy=$(jq '[.conditionQuery.or[] | select(.and == null)]' < "$bc_ui_policy")

  for or_condition in $(seq 0 "$number_of_or_conditions_minus_one"); do



title=$(jq '.title' < "$bc_ui_policy")
guideline=$(jq '.guideline' < "$bc_ui_policy")
category=$(jq '.category' < "$bc_ui_policy" | tr '[:upper:]' '[:lower:]')
severity=$(jq '.pcSeverity' < "$bc_ui_policy")
provider=$(jq '.provider' < "$bc_ui_policy" | tr '[:upper:]' '[:lower:]')


cond_type=$(printf '%s' "$filtered_or_bc_ui_policy" | jq --argjson or_condition "$or_condition" '.[$or_condition].cond_type')
resource_types=$(printf '%s' "$filtered_or_bc_ui_policy" | jq --argjson or_condition "$or_condition" '.[$or_condition].resource_types[]')
attribute=$(printf '%s' "$filtered_or_bc_ui_policy" | jq  --argjson and_condition "$or_condition" '.[$or_condition].attribute')
operator=$(printf '%s' "$filtered_or_bc_ui_policy" | jq  --argjson and_condition "$or_condition" '.[$or_condition].operator')
value=$(printf '%s' "$filtered_or_bc_ui_policy" | jq  --argjson and_condition "$or_condition" '.[$or_condition].value')


BC_UI_EXPORT=$(cat <<EOF
---
metadata:
  name: $title
  guidelines: $guideline
  category: $category
  severity: $severity
scope:
  provider: $provider
  definition:
EOF
)

BC_UI_EXPORT_OR_ARRAY=$(cat <<EOF
    or:
EOF
)

BC_UI_EXPORT_OR_PARAMETERS=$(cat <<EOF
     - cond_type: $cond_type
       resource_types:
         - $resource_types
       attribute: $attribute
       operator: $operator
       value: $value
EOF
)

touch "./temp/$(printf '%s_%03d_%s' "or" "$or_condition" "$BC_POLICY_FILE_NAME_ONLY")"

if [[ -n "$value" ]]; then
printf '%s\n' "$BC_UI_EXPORT_OR_PARAMETERS" >> "./temp/$(printf '%s_%03d_%s' "or" "$or_condition" "$BC_POLICY_FILE_NAME_ONLY")"
fi

done

number_of_nested_and_conditions=$(jq -r '[.conditionQuery.or[].and[]?] | length' < "$bc_ui_policy")
number_of_nested_and_conditions_minus_one=$(( "$number_of_nested_and_conditions" - 1))
filtered_bc_ui_policy_and=$(jq '[.conditionQuery.or[]?.and[]?]' < "$bc_ui_policy")


  for and_condition in $(seq 0 "$number_of_nested_and_conditions_minus_one"); do


title=$(jq '.title' < "$bc_ui_policy")
guideline=$(jq '.guideline' < "$bc_ui_policy")
category=$(jq '.category' < "$bc_ui_policy" | tr '[:upper:]' '[:lower:]')
severity=$(jq '.pcSeverity' < "$bc_ui_policy")
provider=$(jq '.provider' < "$bc_ui_policy" | tr '[:upper:]' '[:lower:]')


cond_type=$(printf '%s' "$filtered_bc_ui_policy_and" | jq --argjson and_condition "$and_condition" '.[$and_condition].cond_type')
resource_types=$(printf '%s' "$filtered_bc_ui_policy_and" | jq --argjson and_condition "$and_condition" '.[$and_condition].resource_types[]')
attribute=$(printf '%s' "$filtered_bc_ui_policy_and"| jq  --argjson and_condition "$and_condition" '.[$and_condition].attribute')
operator=$(printf '%s' "$filtered_bc_ui_policy_and" | jq  --argjson and_condition "$and_condition" '.[$and_condition].operator')
value=$(printf '%s' "$filtered_bc_ui_policy_and" | jq  --argjson and_condition "$and_condition" '.[$and_condition].value')


BC_UI_EXPORT=$(cat <<EOF
---
metadata:
  name: $title
  guidelines: $guideline
  category: $category
  severity: $severity
scope:
  provider: $provider
  definition:
EOF
)

BC_UI_EXPORT_OR_ARRAY=$(cat <<EOF
    or:
EOF
)

BC_UI_EXPORT_NESTED_AND_ARRAY=$(cat <<EOF
     - and:
EOF
)

BC_UI_EXPORT_NESTED_AND_PARAMETERS=$(cat <<EOF
         - cond_type: $cond_type
           resource_types:
             - $resource_types
           attribute: $attribute
           operator: $operator
           value: $value
EOF
)
touch "./temp/$(printf '%s_%03d_%s' "and" "$and_condition" "$BC_POLICY_FILE_NAME_ONLY")"

if [[ -n "$value" ]]; then
printf '%s\n' "$BC_UI_EXPORT_NESTED_AND_PARAMETERS" >> "./temp/$(printf '%s_%03d_%s' "or" "$and_condition" "$BC_POLICY_FILE_NAME_ONLY")"
fi

done

FULL_OR_CONDITIONS=$(cat ./temp/or_0*_"$BC_POLICY_FILE_NAME_ONLY")
FULL_NESTED_AND_CONDITIONS=$(cat ./temp/and_0*_"$BC_POLICY_FILE_NAME_ONLY")

CODE=$(printf '%s\n%s\n%s\n%s\n%s\n' "$BC_UI_EXPORT" "$BC_UI_EXPORT_OR_ARRAY" "$FULL_OR_CONDITIONS" "$BC_UI_EXPORT_NESTED_AND_ARRAY" "$FULL_NESTED_AND_CONDITIONS" )

# final transform
jq --arg CODE "$CODE" --arg DATE "$REPORT_DATE" '. | {cloudType: .provider, complianceMetadata: [], description: .guideline, labels: [], name: (.title + "_" + $DATE), policySubTypes: ["build"], policyType: "config", recommendation: "", rule: { children: [{metadata: {code: $CODE}, type: "build", recommendation: ""}], name:  (.title + "_" + $DATE), parameters: {savedSearch: "false", withIac: "true"}, type: "Config" }, severity: .severity }' < "$bc_ui_policy"  | sed 's/\"severity\"\: \"CRITICAL\"/\"severity\"\: \"HIGH\"  /g'> "./temp/finished_$BC_POLICY_FILE_NAME_ONLY"


fi

done

pce-var-check

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




printf '\n%s\n' "Policies have been transformed. Would you like to continue? If you'd like you can review the files called finished to ensure they're convereted correctly before proceeding. To exit without uploading hit ctrl + c"
read -r ANSWER

if [ "$ANSWER" != "${ANSWER#[Yy]}" ]
  then
        printf '\n%s\n' "Uploading the policies to the Prisma Console"
        POLICIES="./temp/finished_*.json"
        for policy_file in $POLICIES; do

                curl --request POST \
                     --header 'content-type: application/json; charset=UTF-8' \
                     --url "$PC_APIURL/policy" \
                     --header "x-redlock-auth: $PC_JWT" \
                     --data-binary @"$policy_file"

                quick_check "/policy"

                printf '\n%s\n' "policies uploaded" 

        done
  else
    exit
fi


printf '\n%s\n' "Clear the temp folder? Please clear the files in the ./temp folder before running the script again"
read -r ANSWER

if [ "$ANSWER" != "${ANSWER#[Yy]}" ] 
  then
        printf '\n%s\n' "Uploading the policies to the Prisma Console"

# clean up task
{
rm ./temp/*.json
}
  else
    exit
fi


exit
