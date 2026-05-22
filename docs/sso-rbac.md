# ArgoCD SSO/RBAC With Azure Entra ID

This project keeps ArgoCD SSO disabled by default so the student demo remains repeatable on fresh clusters. The Terraform environments are SSO-ready and can be switched to Azure Entra ID OIDC when an app registration and group mappings are available.

## What This Adds

- ArgoCD OIDC login through Azure Entra ID.
- Group-based ArgoCD RBAC.
- `devsecops-admins` mapped to `role:admin`.
- `devsecops-developers` mapped to `role:readonly`.
- OIDC client secret stored in the ArgoCD Kubernetes secret through Helm values.

## Why It Is Opt-In

Azure Entra app registrations and group claims depend on tenant permissions. Some student tenants do not allow users to create applications, service principals, or security groups. Keeping this opt-in avoids breaking the base infrastructure apply.

## Create The Entra App

Run:

```powershell
.\scripts\configure-argocd-entra-sso.ps1 -ArgoCdUrl "https://argocd.example.com"
```

The script creates:

- an Entra application registration,
- a service principal,
- a one-year client secret,
- `argocd-sso.auto.tfvars` files for both Terraform environments.

The redirect URI must match the ArgoCD URL:

```text
https://argocd.example.com/auth/callback
```

For a temporary local demo through port-forward, use the URL that the browser will use and register:

```text
http://localhost:8080/auth/callback
```

## Group Mapping

For real Entra group-based RBAC, replace the placeholder group names in the generated `argocd-sso.auto.tfvars` files with Entra security group object IDs:

```hcl
argocd_sso_admin_groups    = ["<entra-admin-group-object-id>"]
argocd_sso_readonly_groups = ["<entra-developer-group-object-id>"]
```

ArgoCD then receives the `groups` claim and applies:

```csv
g, <admin-group>, role:admin
g, <developer-group>, role:readonly
```

## Apply

After reviewing the generated tfvars files:

```powershell
cd terraform\environments\aws
terraform plan
terraform apply
```

Repeat for Azure if the standby ArgoCD controller should also use SSO:

```powershell
cd terraform\environments\azure
terraform plan
terraform apply
```

## Demo Explanation

Use this wording:

> ArgoCD is prepared for enterprise SSO through Azure Entra ID OIDC. RBAC is not user-by-user; it is mapped from identity-provider groups into ArgoCD roles. Admin users can sync and manage applications, while developer users are readonly by default. This follows centralized identity and least privilege instead of local shared admin accounts.
