# LeanIX Integration API Default Config Action

This action provides a standard way of provisioning a default configuration into the Integration-API of all regions.

## Usage

This action reads the default configuration from a file and calls the Integration-API to provision the provided config.
Use in advance the provided [leanix/secrets-action](https://github.com/leanix/secrets-action) to inject the required secrets.

A simple provision step in the connector's workflow would look like this:
```yaml
- name: Provision default config
  uses: leanix/integration-api-default-config-action@master
  with:
    environment: 'prod'  
```
This reads the file `integration-api-default-config.json` from the root of your repository and provisions it globally on all prod instances of Integration-API.
### Input Parameter
| input | required | default | description |
|-------|----------|---------|-------------|
|default_config_file|no|`integration-api-default-config.json`|The location of the file that contains the default configuration that is used as the input for this action.|
|environment|yes|test|The environment to provision to, e.g. test or prod|
|region|no|-|The region to provision to, e.g. westeurope or australiaeast. Leave empty to provision to all regions.|

## Requires
This action requires following GitHub actions in advance:
- [leanix/secrets-action@master](https://github.com/leanix/secrets-action)

## Copyright and license
Copyright 2021 LeanIX GmbH under the [Unlicense license](LICENSE).
