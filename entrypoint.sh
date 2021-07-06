#!/bin/bash
set -eo pipefail # http://redsymbol.net/articles/unofficial-bash-strict-mode/

# The dictionary contains all the available regions
declare -A REGION_IDS
REGION_IDS["westeurope"]="eu"
REGION_IDS["eastus"]="us"
REGION_IDS["canadacentral"]="ca"
REGION_IDS["australiaeast"]="au"
REGION_IDS["germanywestcentral"]="de"
REGION_IDS["horizon"]="horizon" # edge case

# The file containing the default integration-api config from the calling repository
NEW_CONFIG_LOCATION=/github/workspace/${INPUT_DEFAULT_CONFIG_FILE}
echo "Reading provided default config file from '${NEW_CONFIG_LOCATION}'..."
EXTERNAL_ID=$(cat ${NEW_CONFIG_LOCATION} | jq -r '.externalId')
echo "Found provided default config with externalId='${EXTERNAL_ID}'"

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

echo "Login to Azure..."
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
az account set -s $ARM_SUBSCRIPTION_ID

if [[ -z "${INPUT_REGION}" ]]; then
  # use all regions
  REGIONS=${!REGION_IDS[@]}
else
  # use provided region only
  REGIONS=("${INPUT_REGION}")
fi

for REGION in $REGIONS; do
  REGION_ID=${REGION_IDS[$REGION]} # e.g. 'eu' for 'westeurope'
  if [[ "${REGION}" == "horizon" ]]; then
    # edge-case for horizon
    KEY_VAULT_NAME="lxeastusprod"
    DEFAULT_KEY="${INPUT_SYSTEM_USER_CLIENT_ID}-horizon-oauth-secret-horizon-svc"
    REGION_ID="app-9"
  else
    KEY_VAULT_NAME="lx${REGION}${INPUT_ENVIRONMENT}"
    DEFAULT_KEY="${INPUT_SYSTEM_USER_CLIENT_ID}-oauth-secret-${REGION_ID}-svc"
  fi
  VAULT_SECRET_KEY=${INPUT_SYSTEM_USER_VAULT_KEY:-$DEFAULT_KEY}

  echo "Using key '${VAULT_SECRET_KEY}' to fetch the SYSTEM user secret from Azure Key Vault '${KEY_VAULT_NAME}'..."
  VAULT_SECRET_VALUE=$(az keyvault secret show --vault-name ${KEY_VAULT_NAME} --name ${VAULT_SECRET_KEY} | jq -r .value)

  echo "Fetching oauth token from ${REGION_ID}.leanix.net with client_id='${INPUT_SYSTEM_USER_CLIENT_ID}'..."
  TOKEN=$(curl --silent --request POST \
    --url "https://${REGION_ID}.leanix.net/services/mtm/v1/oauth2/token" \
    --header 'content-type: application/x-www-form-urlencoded' \
    --header 'User-Agent: integration-api-default-config-action' \
    --data client_id=${INPUT_SYSTEM_USER_CLIENT_ID} \
    --data client_secret=${VAULT_SECRET_VALUE} \
    --data grant_type=client_credentials \
    | jq -r .'access_token')

  echo "GET integration-api/v1/defaultConfigurations/${EXTERNAL_ID}"
  REMOTE_CONFIG_STATUS_CODE=$(curl --write-out %{http_code} --silent --output /dev/null --request GET \
    --url "https://${REGION_ID}.leanix.net/services/integration-api/v1/defaultConfigurations/${EXTERNAL_ID}" \
    --header "Authorization: Bearer ${TOKEN}" \
    --header 'User-Agent: integration-api-default-config-action' \
    --header 'Accept: application/json')
  
  if [[ "${REMOTE_CONFIG_STATUS_CODE}" -eq 200 ]] ; then
    echo "Found remote config by externalId='${EXTERNAL_ID}'"
    #TODO: PUT new config
  else
    echo "No remote config found by externalId='${EXTERNAL_ID}'"
    #TODO: POST new config
  fi
done