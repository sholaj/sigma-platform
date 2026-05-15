# Azure bootstrap — Phase 1 runbook

One-time setup that gets a working Terraform-managed Azure plane for the
sigma-platform project. Run in order; each step is annotated with
expected duration and cost impact.

## 0. Off-platform prerequisites

- [ ] **Quota increase request** at https://portal.azure.com → Help + Support → New Support Request → Service & subscription limits (quotas) → Compute-VM (cores-vCPUs) subscription limit increases → region `uksouth`. Request:
  - `cores` (regional total): 60
  - `standardDSv3Family`: 50  (hub workers)
  - `standardDSv5Family`: 50  (virt workers, when virt-day comes)
  - `standardBsv2Family`: 8   (Spot bastion)
  PAYG quota bumps usually auto-approve within minutes; allow up to 24h for a human reviewer.
- [ ] **Red Hat account + ARO subscription linking**: create an account at https://console.redhat.com, then link it to this Azure subscription via the Azure Portal Marketplace (search "Azure Red Hat OpenShift"). Required before `az aro create` will succeed.
- [ ] **Pull secret** download from https://console.redhat.com/openshift/install/pull-secret to `~/.config/sigma-platform/pull-secret.txt`.

## 1. CLI auth + provider registration

```bash
az login                       # opens browser, ~30s
az account show                # confirm correct sub is default
az provider register --namespace Microsoft.RedHatOpenShift
```

The other RPs (`Microsoft.Network`, `Microsoft.Compute`, `Microsoft.Storage`,
`Microsoft.Authorization`, `Microsoft.KeyVault`, `Microsoft.ManagedIdentity`)
are usually already registered on a PAYG sub. Verify:

```bash
for ns in Microsoft.RedHatOpenShift Microsoft.Network Microsoft.Compute \
          Microsoft.Storage Microsoft.Authorization Microsoft.KeyVault \
          Microsoft.ManagedIdentity; do
  printf "%-32s %s\n" "$ns" "$(az provider show --namespace "$ns" --query registrationState -o tsv)"
done
```

## 2. Shared env Terraform — first apply (LOCAL state)

The shared env creates the storage account that will hold Terraform state
for every env (including itself). The chicken-and-egg is resolved by
running the FIRST apply against local state, then migrating.

```bash
cd infra/terraform/envs/shared

# Create tfvars from the example
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars       # fill in subscription_id, tenant_id, alert_emails

# First init runs with local state (backend block in versions.tf is commented out)
terraform init
terraform plan -out tfplan
terraform apply tfplan         # ~30–60 seconds, ≈£0 on first creation
```

Expected output: a new RG `rg-sigma-shared-uksouth`, a storage account
`sigmatf<hex>`, a container `tfstate`, and a subscription-scope budget
`sigma-platform-monthly`.

## 3. Migrate state to the new SA

Uncomment the `backend "azurerm"` block at the bottom of `versions.tf`
and fill in the `storage_account_name` from the `terraform output` line
above. Then:

```bash
terraform init -migrate-state
# Confirm "yes" at the prompt to copy state into Azure.
rm -f terraform.tfstate*       # local state file no longer authoritative
```

From this point, every `terraform plan/apply` in the shared/ env reads/writes
state against the SA. Other envs (`hub/`, `virt/`, `bastion/`) drop a similar
backend block into their `versions.tf` with their own `key = "<env>.tfstate"`.

## 4. AAD app + service principal + federated credential for GitHub Actions

The nightly-teardown workflow needs to call `az group delete` against the
ephemeral RGs. Federated identity (OIDC) avoids storing a client secret in
GitHub. Authored as `scripts/setup/aad-oidc.sh` in a follow-up commit.

## 5. GitHub repo secrets

After the AAD app exists:

```bash
gh secret set AZURE_CLIENT_ID       --repo sholaj/sigma-platform < <(printf '%s' "$APP_CLIENT_ID")
gh secret set AZURE_TENANT_ID       --repo sholaj/sigma-platform < <(az account show --query tenantId -o tsv)
gh secret set AZURE_SUBSCRIPTION_ID --repo sholaj/sigma-platform < <(az account show --query id       -o tsv)
```

(Sub + tenant IDs are not strictly secrets — they're discoverable via the
Azure Portal — but treating them uniformly with `gh secret` simplifies the
workflow.)

## 6. Verify

```bash
# Confirm budget exists
az consumption budget list --query "[?name=='sigma-platform-monthly']" -o table

# Confirm RG + SA + container exist
az group show --name rg-sigma-shared-uksouth -o table
az storage account list --resource-group rg-sigma-shared-uksouth -o table
```

## Day-2: rotating / destroying the shared env

The shared env is **persistent** by design (tag `auto-destroy=false`). To
nuke and recreate (rare — only for a full project reset):

```bash
cd infra/terraform/envs/shared
# Drain remote state back to local first so the SA can delete itself
terraform init -migrate-state -backend=false
terraform destroy
```
