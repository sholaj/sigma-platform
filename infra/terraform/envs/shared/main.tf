locals {
  project = "sigma-platform"

  common_tags = {
    project      = local.project
    environment  = "shared"
    cost-owner   = var.cost_owner
    auto-destroy = "false" # state SA is persistent
    managed-by   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Shared resource group — holds the Terraform state SA and any other resources
# that outlive the ephemeral hub/virt envs.
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "shared" {
  name     = "rg-sigma-shared-${var.location}"
  location = var.location
  tags     = local.common_tags
}

# -----------------------------------------------------------------------------
# Terraform state storage account.
#
# Naming: storage account names must be 3–24 lowercase alphanumeric chars,
# globally unique. We seed a 6-char random hex suffix to avoid collisions.
# -----------------------------------------------------------------------------

resource "random_id" "sa_suffix" {
  byte_length = 3
}

resource "azurerm_storage_account" "tfstate" {
  name                = "sigmatf${random_id.sa_suffix.hex}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location

  account_tier              = "Standard"
  account_replication_type  = "LRS" # state is small; single-region project
  account_kind              = "StorageV2"
  min_tls_version           = "TLS1_2"
  shared_access_key_enabled = false # force AAD auth — see ADR 0017

  public_network_access_enabled = true # required so the CLI + GH Actions runners can reach the SA

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  tags = local.common_tags
}

# Grant the Terraform principal Storage Blob Data Owner so it can read/write
# state once shared_access_key_enabled=false forces AAD auth. Without this,
# `terraform init -migrate-state` after the first apply would fail with
# AuthorizationPermissionMismatch.
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "tfstate_owner" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"

  depends_on = [azurerm_role_assignment.tfstate_owner]
}

# -----------------------------------------------------------------------------
# Subscription-scope monthly budget with 50/80/100% alerts.
#
# Important caveat: on PAYG subscriptions, budgets ALERT but do NOT hard-cap.
# The structural defence is the nightly-teardown GitHub Action that runs
# `az group delete` on RGs tagged auto-destroy=true. See ADR 0006.
# -----------------------------------------------------------------------------

resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "sigma-platform-monthly"
  subscription_id = "/subscriptions/${var.subscription_id}"

  amount     = var.monthly_budget_gbp
  time_grain = "Monthly"

  time_period {
    start_date = "${var.budget_start_date}T00:00:00Z"
  }

  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      enabled        = true
      threshold      = notification.value
      operator       = "GreaterThan"
      threshold_type = "Actual"
      contact_emails = var.alert_emails
    }
  }

  lifecycle {
    # start_date is immutable after creation; ignore drift so a re-plan
    # next month doesn't try to replace the budget.
    ignore_changes = [time_period]
  }
}
