terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.10"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Backend block is intentionally absent on the FIRST apply.
  # The shared/ env creates the storage account that holds state for
  # every env (including itself). The bootstrap dance is documented
  # in scripts/setup/azure-bootstrap.md:
  #   1. terraform init  (local backend)
  #   2. terraform apply (creates the SA + container)
  #   3. Uncomment the backend block below with the output values
  #   4. terraform init -migrate-state
  #
  # After step 4, state lives in Azure and subsequent envs reference
  # the same SA via their own backend blocks (key = "<env>.tfstate").

  # backend "azurerm" {
  #   resource_group_name  = "rg-sigma-shared-uksouth"
  #   storage_account_name = "<set from output after first apply>"
  #   container_name       = "tfstate"
  #   key                  = "shared.tfstate"
  #   use_azuread_auth     = true
  # }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {
  tenant_id = var.tenant_id
}
