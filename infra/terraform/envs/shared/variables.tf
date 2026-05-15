variable "subscription_id" {
  description = "Azure subscription ID (from `az account show --query id -o tsv`)"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID (from `az account show --query tenantId -o tsv`)"
  type        = string
}

variable "location" {
  description = "Single Azure region for the whole project"
  type        = string
  default     = "uksouth"
}

variable "cost_owner" {
  description = "GitHub handle of the cost owner — applied as the `cost-owner` tag on every resource"
  type        = string
}

variable "monthly_budget_gbp" {
  description = "Monthly soft budget ceiling in GBP. Alerts at 50/80/100% — does NOT hard-cap PAYG spend."
  type        = number
  default     = 500
}

variable "alert_emails" {
  description = "Email addresses notified at 50/80/100% of monthly_budget_gbp"
  type        = list(string)
}

variable "github_org_repo" {
  description = "GitHub org/repo for OIDC federated credentials (used by the Phase 1 AAD app)"
  type        = string
  default     = "sholaj/sigma-platform"
}

variable "budget_start_date" {
  description = "First-of-month start date for the budget (YYYY-MM-01). Set explicitly so plans are stable across runs."
  type        = string
  # Format must be YYYY-MM-01T00:00:00Z and not more than 12 months in the past.
}
