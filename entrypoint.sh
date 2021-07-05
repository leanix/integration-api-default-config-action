#!/bin/bash

set -e

# Parse INPUT variable from GitHub Action to ENV
for input_var in "${!INPUT_@}"; do
  echo "Export GitHub Action input for ${input_var}"
  export "${input_var#INPUT_}"="${!input_var}"
done

echo $ENVIRONMENT
echo $REGION