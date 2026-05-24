# Apply/Destroy Runbook

This project is designed for full-stack ephemeral demo runs. The goal is to apply the complete AWS/Azure lab when needed, collect evidence, and destroy it without manual console cleanup.

## Apply Full Demo

```powershell
.\scripts\infra-up.ps1 -Environment full-demo
```

For non-interactive demo setup:

```powershell
.\scripts\infra-up.ps1 -Environment full-demo -AutoApprove
```

The script performs:

1. Local tool checks.
2. AWS identity check.
3. Azure identity check.
4. Terraform init/validate/plan/apply for Azure.
5. Terraform init/validate/plan/apply for AWS.
6. kubeconfig update for EKS and AKS.

## Destroy Full Demo

```powershell
.\scripts\infra-down.ps1 -Environment full-demo
```

For non-interactive teardown:

```powershell
.\scripts\infra-down.ps1 -Environment full-demo -AutoApprove
```

The script performs:

1. Safety confirmation.
2. Kubernetes pre-destroy cleanup.
3. Terraform destroy for AWS.
4. Terraform destroy for Azure.
5. Post-destroy cost reminder.

## Cost Guardrails

After every demo destroy, verify there are no remaining cost-bearing resources:

AWS:

- EKS clusters and node groups.
- EC2 instances and EBS volumes.
- NAT Gateways and Elastic IPs.
- Load Balancers.
- RDS instances and snapshots.
- ElastiCache clusters.
- VPN connections and gateways.

Azure:

- AKS clusters and node resource groups.
- Public IP addresses.
- Load balancers.
- Managed disks.
- VPN gateways.
- Storage accounts created for demo data.

Do not delete Terraform backend resources unless intentionally resetting the lab:

- AWS S3 state bucket.
- AWS DynamoDB lock table.
- Azure Storage Account/container for state.

## Troubleshooting Destroy

If destroy is stuck:

1. Check Kubernetes namespaces stuck in `Terminating`.
2. Delete ArgoCD Applications before deleting ArgoCD.
3. Delete Services of type `LoadBalancer`.
4. Check PVC/PV finalizers.
5. Re-run `infra-down.ps1`.

Avoid manual console deletion unless Terraform state is already reconciled. Manual deletion can create state drift and make the next apply harder.
