#!/bin/bash
set -eo pipefail # http://redsymbol.net/articles/unofficial-bash-strict-mode/

# The dictionary contains all the available regions
declare -A REGION_IDS
REGION_IDS["westeurope"]="eu"
REGION_IDS["eastus"]="us"
REGION_IDS["canadacentral"]="ca"
REGION_IDS["australiaeast"]="au"
REGION_IDS["germanywestcentral"]="de"
REGION_IDS["horizon"]="horizon" # edge-case for horizon

# The file containing the default integration-api config from the calling repository
NEW_CONFIG_LOCATION=/github/workspace/${INPUT_DEFAULT_CONFIG_FILE}
echo "Reading provided default config file from '${NEW_CONFIG_LOCATION}' ..."
EXTERNAL_ID=$(cat ${NEW_CONFIG_LOCATION} | jq -r '.externalId')
echo "Found provided default config with externalId='${EXTERNAL_ID}'"

echo "Login to Azure ..."
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
az account set -s $ARM_SUBSCRIPTION_ID

if [[ -z "${INPUT_REGION}" ]]; then
  # use all regions
  REGIONS=${!REGION_IDS[@]}
else
  # use provided region only
  REGIONS=("${INPUT_REGION}")
fi
# hard-coded test environment
if [[ "${INPUT_ENVIRONMENT}" == "test" ]]; then
  REGIONS=( westeurope )
fi

for REGION in $REGIONS; do
  REGION_ID=${REGION_IDS[$REGION]} # e.g. 'eu' for 'westeurope'
  if [[ "${REGION}" == "horizon" ]]; then
    # edge-case for horizon
    KEY_VAULT_NAME="lxeastusprod"
    VAULT_SECRET_KEY="integration-api-horizon-oauth-secret-horizon-svc"
    REGION_ID="app-9"
  else
    KEY_VAULT_NAME="lx${REGION}${INPUT_ENVIRONMENT}"
    VAULT_SECRET_KEY="integration-api-oauth-secret-${REGION_ID}-svc"
  fi
  # hard-coded test environment
  if [[ "${INPUT_ENVIRONMENT}" == "test" ]]; then
    KEY_VAULT_NAME="lxwesteuropetest"
    VAULT_SECRET_KEY="integration-api-oauth-secret-test-svc-flow-2"
    REGION_ID="test-app-flow-2"
  fi

  echo "Using key '${VAULT_SECRET_KEY}' to fetch the SYSTEM user secret from Azure Key Vault '${KEY_VAULT_NAME}' ..."
  VAULT_SECRET_VALUE=$(az keyvault secret show --vault-name ${KEY_VAULT_NAME} --name ${VAULT_SECRET_KEY} | jq -r .value)

  echo "Fetching oauth token from ${REGION_ID}.leanix.net ..."
  TOKEN=$(curl --silent --request POST \
    --url "https://${REGION_ID}.leanix.net/services/mtm/v1/oauth2/token" \
    --header 'content-type: application/x-www-form-urlencoded' \
    --header 'User-Agent: integration-api-default-config-action' \
    --data client_id=integration-api \
    --data client_secret=${VAULT_SECRET_VALUE} \
    --data grant_type=client_credentials \
    | jq -r .'access_token')

  echo "GET integration-api/v1/defaultConfigurations/${EXTERNAL_ID} ..."
  REMOTE_CONFIG_STATUS_CODE=$(curl --write-out %{http_code} --silent --output /dev/null --request GET \
    --url "https://${REGION_ID}.leanix.net/services/integration-api/v1/defaultConfigurations/${EXTERNAL_ID}" \
    --header "Authorization: Bearer ${TOKEN}" \
    --header 'User-Agent: integration-api-default-config-action' \
    --header 'Accept: application/json')
  
  if [[ "${REMOTE_CONFIG_STATUS_CODE}" -eq 200 ]] ; then
    echo "Found remote config by externalId='${EXTERNAL_ID}'"
    UPSERT_RESULT=$(curl --write-out %{http_code} --silent --output /dev/null --request PUT \
    --url "https://${REGION_ID}.leanix.net/services/integration-api/v1/defaultConfigurations/${EXTERNAL_ID}" \
    --header "Authorization: Bearer ${TOKEN}" \
    --header 'User-Agent: integration-api-default-config-action' \
    --header 'Accept: application/json' \
    --header "Content-Type: application/json" \
    --data-binary @${NEW_CONFIG_LOCATION})

     if [[ "${UPSERT_RESULT}" -eq 200 ]] ; then
      echo "Successfully updated default config with externalId='${EXTERNAL_ID}'"
    else
      echo "Failed to update default config. externalId='${EXTERNAL_ID}' http-code='${UPSERT_RESULT}'"
      exit 1
    fi
  else
    echo "No remote config found by externalId='${EXTERNAL_ID}'"
    UPSERT_RESULT=$(curl --write-out %{http_code} --silent --output /dev/null --request POST \
    --url "https://${REGION_ID}.leanix.net/services/integration-api/v1/defaultConfigurations" \
    --header "Authorization: Bearer ${TOKEN}" \
    --header 'User-Agent: integration-api-default-config-action' \
    --header 'Accept: application/json' \
    --header "Content-Type: application/json" \
    --data-binary @${NEW_CONFIG_LOCATION})

     if [[ "${UPSERT_RESULT}" -eq 200 ]] ; then
      echo "Successfully created default config with externalId='${EXTERNAL_ID}'"
    else
      echo "Failed to create default config. externalId='${EXTERNAL_ID}' http-code='${UPSERT_RESULT}'"
      exit 1
    fi
  fi
done
