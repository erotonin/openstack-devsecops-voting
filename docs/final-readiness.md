# Final Readiness Review

This file summarizes the final project state for the capstone handoff.

## Completed Scope

- AWS EKS primary site and Azure AKS warm standby.
- Terraform-managed AWS and Azure infrastructure.
- Route-based IPSec VPN with BGP between AWS and Azure.
- GitHub Actions cloud access through OIDC, not static cloud keys.
- PR security gates for secret scan, SAST, IaC scan, dependency/image scan, Helm validation, and Conftest policy checks.
- Main-branch image pipeline for Trivy image scan, Syft SBOM, ECR/ACR push, and Cosign keyless signing.
- Manual production approval gate through GitHub Environments.
- ArgoCD GitOps deployment for AWS and Azure.
- Azure Entra ID SSO-ready ArgoCD configuration with group-based RBAC.
- External Secrets Operator integration with AWS Secrets Manager and Azure Key Vault.
- Gatekeeper constraints for restricted workload posture.
- Sigstore policy-controller enforcement for signed ECR images.
- Prometheus/Grafana SLI/SLO monitoring.
- Loki/Promtail logging.
- Falco/Falcosidekick runtime detection and incident workflow.
- DR failover script for AKS warm standby validation and RTO measurement.

## Verified Evidence

- AWS ArgoCD application `voting-aws` is `Synced Healthy`.
- Azure ArgoCD application `voting-azure` is `Synced Healthy`.
- ArgoCD SSO OIDC config is present on both clusters.
- ArgoCD RBAC maps Entra group object IDs to admin and readonly roles.
- PR security gate demo passed on pull request `#28`.
- Production approval workflow_dispatch run passed.
- Redis CloudWatch log group is encrypted with KMS and retains logs for 365 days.

## Intentional Cost-Aware Exceptions

- Azure Container Registry uses Basic SKU to keep the student demo cost-capped.
- ACR public access is kept for GitHub-hosted runners and AKS pulls; production should use private endpoints.
- ACR Premium-only controls such as geo-replication, zone redundancy, retention policy, dedicated data endpoints, and Defender-integrated scanning are documented as production hardening items.
- Cross-cloud database replication is represented by DR seed/restore workflow rather than live replication. Production should add database-native logical replication, AWS DMS, or backup shipping.
- Canary/automated rollback is not enabled; current deployment uses rolling updates, readiness/liveness probes, and GitOps rollback by reverting Git. Production should add Argo Rollouts with Prometheus analysis.

## Demo Commands

```powershell
.\scripts\open-argocd.ps1
.\scripts\open-grafana.ps1
.\scripts\test-policy-rejects.ps1 -Context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster
.\scripts\dr-failover.ps1 -SkipScale
.\scripts\run-production-approval.ps1
```

## Cleanup Command

After recording the demo:

```powershell
.\destroy.ps1 -AutoApprove
```
