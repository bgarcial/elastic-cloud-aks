terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.82.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {}
  username = var.username
  password = var.password

}

# Block to play around with the state if needed
terraform {
  #   backend "azurerm" {
  #     resource_group_name  = "pfc-terraform-envs-states"
  #     storage_account_name = "pfcterraformstates"
  #     container_name       = "pfcterraformstates"
  #     key                  = "staging.terraform.tfstate"
  #   }
}