terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.2"
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

  # State migrated to Azure on 2026-05-15 — see git history.
  # The bootstrap dance (local apply -> migrate) is documented in
  # scripts/setup/azure-bootstrap.md.
  backend "azurerm" {
    resource_group_name  = "rg-sigma-shared-uksouth"
    storage_account_name = "sigmatf2e1c79"
    container_name       = "tfstate"
    key                  = "shared.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  # The state storage account has shared_access_key_enabled=false, so the
  # provider's data-plane probes (post-creation availability check,
  # container management) must use the caller's AAD identity instead of
  # shared keys. Without this, apply fails with
  # "KeyBasedAuthenticationNotPermitted" when reaching the blob service.
  storage_use_azuread = true
}

provider "azuread" {
  tenant_id = var.tenant_id
}
