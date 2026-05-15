output "resource_group_name" {
  description = "Shared resource group name"
  value       = azurerm_resource_group.shared.name
}

output "tfstate_storage_account_name" {
  description = "Name of the storage account holding Terraform state"
  value       = azurerm_storage_account.tfstate.name
}

output "tfstate_container_name" {
  description = "Container name for Terraform state blobs"
  value       = azurerm_storage_container.tfstate.name
}

output "tenant_id" {
  description = "Azure AD tenant ID (passthrough — used by downstream envs)"
  value       = var.tenant_id
}

output "subscription_id" {
  description = "Azure subscription ID (passthrough — used by downstream envs)"
  value       = var.subscription_id
}

# Copy-paste-ready backend block for downstream envs (hub/, virt/, bastion/).
output "backend_config_snippet" {
  description = "Backend block to drop into envs/<name>/versions.tf after the first apply migrates state here"
  value       = <<-EOT
    backend "azurerm" {
      resource_group_name  = "${azurerm_resource_group.shared.name}"
      storage_account_name = "${azurerm_storage_account.tfstate.name}"
      container_name       = "${azurerm_storage_container.tfstate.name}"
      key                  = "<env-name>.tfstate"
      use_azuread_auth     = true
    }
  EOT
}
