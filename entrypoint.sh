#!/bin/bash

set -e

# The dictionary contains all the available regions
declare -A REGION_IDS
REGION_IDS["westeurope"]="eu"
REGION_IDS["eastus"]="us"
REGION_IDS["canadacentral"]="ca"
REGION_IDS["australiaeast"]="au"
REGION_IDS["germanywestcentral"]="de"

# The credentials of the Service Principal are set by the secrets-action
if [[ -z $AZURE_CLIENT_ID ]]; then
  export AZURE_CLIENT_ID=$ARM_CLIENT_ID
fi
if [[ -z $AZURE_CLIENT_SECRET ]]; then
  export AZURE_CLIENT_SECRET=$ARM_CLIENT_SECRET
fi
if [[ -z $AZURE_TENANT_ID ]]; then
  export AZURE_TENANT_ID=$ARM_TENANT_ID
fi
if [[ -z $AZURE_SUBSCRIPTION_ID ]]; then
  export AZURE_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID
fi

# Login to Azure
echo "Login to Azure..."
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
az account set -s $ARM_SUBSCRIPTION_ID

if [[ -z "$INPUT_REGION" ]]; then
  REGIONS=${!REGION_IDS[@]}
else
  REGIONS=("${INPUT_REGION}")
fi

for REGION in $REGIONS; do
  KEY_VAULT_NAME="lx${REGION}${INPUT_ENVIRONMENT}"
  REGION_ID=${REGION_IDS[$REGION]}
  VAULT_SECRET_KEY=${INPUT_SYSTEM_USER_KEY:-integration-api-oauth-secret-${REGION_ID}-svc} # TODO: horizon
  echo "Using key '${VAULT_SECRET_KEY}' to fetch the SYSTEM user secret from Azure Key Vault '${KEY_VAULT_NAME}'..."
  VAULT_SECRET_VALUE=$(az keyvault secret show --vault-name ${KEY_VAULT_NAME} --name ${VAULT_SECRET_KEY} | jq .value -j)
  
  echo ${VAULT_SECRET_VALUE:0:3}

  echo "Fetching oAuth token from ${REGION_ID}.leanix.net with client_id='integration-api'..."
  TOKEN=$(curl -s --request POST \
      --url "https://${REGION_ID}.leanix.net/services/mtm/v1/oauth2/token" \
      --header 'content-type: application/x-www-form-urlencoded' \
      --data client_id=integration-api \
      --data client_secret=${VAULT_SECRET_VALUE} \
      --data grant_type=client_credentials | jq .'access_token')
  echo ${TOKEN:0:20}
done

