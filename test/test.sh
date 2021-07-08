#!/bin/bash

set -e

docker run --rm \
  -e ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID \
  -e ARM_TENANT_ID=$ARM_TENANT_ID \
  -e ARM_CLIENT_ID=$ARM_CLIENT_ID \
  -e ARM_CLIENT_SECRET=$ARM_CLIENT_SECRET \
  -e INPUT_ENVIRONMENT=test \
  -e INPUT_DEFAULT_CONFIG_FILE="test/integration-api-default-config.json" \
  -v $(pwd):"/github/workspace" \
  leanixacrpublic.azurecr.io/integration-api-default-config-action:$1