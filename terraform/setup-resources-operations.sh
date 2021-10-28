#!/usr/bin/env bash
# -----------------SETTINGS VALUES BY CUSTOMER ----------------------------------------------
# Standard settings values
# The following values should be modified by customer.
# Global variables to assign name conventions to resources
customer_prefix=pfc
customer_environment=staging

# Exporting $customer_prefix and $customer_environment variables to be available from Terraform scripts
export TF_VAR_customer_environment=$customer_environment
export TF_VAR_customer_prefix=$customer_prefix
# ------------------- END SETTINGS VALUES BY CUSTOMER/ENVIRONMENT-----------------------------

# Create resource group name
# This is a general resource group, and it will be used to store the terraform
# state file.
RESOURCE_GROUP_NAME=$customer_prefix-terraform-envs-states
az group create --name $RESOURCE_GROUP_NAME --location westeurope
echo "Was created the resource group: $RESOURCE_GROUP_NAME"


# STORING TERRAFORM STATE FILES
# Create storage account
# This storage account will be used for store the terraform state files for environments deployments
STORAGE_ACCOUNT_NAME=pfcterraformstates
az storage account create -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP_NAME -l westeurope --sku Standard_LRS --encryption-services blob
# So that is why this storage account is created only once.
# It could be used for other k8s_test/dev/accp/prd

# We are getting the storage account key to access to it when we need to store the
# testing terraform state files
ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query [0].value -o tsv)

# Blob container inside the storage account
# We are going to create a new blob container for the testing environment
# We will have all environments terraform state files in the same
# blob container, but each environment in a different folder.
CONTAINER_NAME=pfcterraformstates
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --account-key $ACCOUNT_KEY

echo "storage_account_name created: $STORAGE_ACCOUNT_NAME"
echo "An storage blob container called $CONTAINER_NAME  was created to store the terraform.tfstate staging file."

# ----
# Creating KeyVault instance to store a service principal password
# KEYVAULT_RESOURCE_GROUP_NAME=$customer_prefix-$customer_environment-kv
# az group create --name $KEYVAULT_RESOURCE_GROUP_NAME --location westeurope

# Assigning name to the resource group which would contain the K8s cluster
# export TF_VAR_infra_resource_group_name=$KEYVAULT_RESOURCE_GROUP_NAME

# Determining which subscription create the resources
# Exposing subscription and tenant id to be readed from terraform scripts
# export TF_VAR_subscription_id=9148bd11-f32b-4b5d-a6c0-5ac5317f29ca
# export TF_VAR_tenant_id=4e6b0716-50ea-4664-90a8-998f60996c44
# export TF_VAR_client_id=15b673ac-a154-43e7-94d5-a293366d1dea

# Create an Azure KeyVault
# This KeyVault instance will be used to store the service principal secret
# That I created previously to be used in github actions.
# The secret in that KeyVAULT was created manually.
KEYVAULT_NAME=$customer_prefix-operations-kv
# echo "Creating $KEYVAULT_NAME key vault..."
# az keyvault create -g $KEYVAULT_RESOURCE_GROUP_NAME -l westeurope -n $KEYVAULT_NAME
# echo "Key vault $KEYVAULT_NAME created."
 
# Getting the nmbrs service principal client secret 
# SECRET_NAME=nmbrs-client-secret
# nmbrs_assessment_client_secret=$(az keyvault secret show -n $SECRET_NAME --vault-name $KEYVAULT_NAME --query value --output tsv)
# Exposing nmbrs_assessment_client_secret variable to be readed from terraform scripts variables
# export TF_VAR_client_secret=$nmbrs_assessment_client_secret
