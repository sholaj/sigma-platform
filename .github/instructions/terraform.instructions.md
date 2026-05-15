---
applyTo: "infra/terraform/**/*.tf"
---
- Provider: `azurerm` >= 4.0. Pin exact version in `terraform.required_providers`.
- Resource names: `azurerm_<type>.<purpose>` (e.g., `azurerm_resource_group.hub`).
- Tag every taggable resource with:
    project       = "sigma-platform"
    environment   = var.environment   # hub | virt | bastion
    cost-owner    = var.cost_owner
    auto-destroy  = "true"
    created       = timestamp()
- State: remote backend (azurerm) with `use_azuread_auth = true` and
  state locking via the storage account's lease mechanism.
- Variables ALWAYS go through `variables.tf`; never hard-code.
- Output sensitive values with `sensitive = true`.
- For ARO: register Microsoft.RedHatOpenShift provider first, then
  AAD app + SP, then VNet + subnets, then ARO cluster.
- Use `azurerm_redhat_openshift_cluster` (>= provider 4.x).
