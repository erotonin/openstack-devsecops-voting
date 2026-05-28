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
- EKS upgrade path documented and Terraform target prepared for Kubernetes `1.31`.

## Verified Evidence

- AWS ArgoCD application `voting-staging` is `Synced Healthy`.
- AWS ArgoCD application `voting-production` is `Synced Healthy`.
- Azure ArgoCD application `voting-azure` is `Synced Healthy`.
- ArgoCD SSO OIDC config is present on both clusters.
- ArgoCD RBAC maps Entra group object IDs to admin and readonly roles.
- PR security gate demo passed on pull request `#28`.
- Production approval workflow_dispatch run passed.
- Full main release pipeline `26556068376` passed build, SBOM, Cosign sign/verify, Trivy image scan, staging GitOps, smoke test, OWASP ZAP DAST, and promotion PR creation.
- GitOps promotion run `26556732195` passed after promotion PR `#72` was merged.
- AWS staging, AWS production, and Azure warm standby `/healthz` endpoints returned HTTP 200.
- Redis CloudWatch log group is encrypted with KMS and retains logs for 365 days.
- Live AWS EKS was observed at Kubernetes `1.30`; AKS was observed at `1.34.7`.

## Intentional Cost-Aware Exceptions

- Azure Container Registry uses Basic SKU to keep the student demo cost-capped.
- ACR public access is kept for GitHub-hosted runners and AKS pulls; production should use private endpoints.
- ACR Premium-only controls such as geo-replication, zone redundancy, retention policy, dedicated data endpoints, and Defender-integrated scanning are documented as production hardening items.
- Checkov still runs in CI, but enterprise/cost-heavy controls are listed as accepted lab exceptions in `.github/workflows/ci-pipeline.yml`. The project continues to block high-signal failures through Gitleaks, Semgrep, tfsec, Trivy, Helm validation, Conftest, Gatekeeper, Kyverno, and Cosign verification.
- Cross-cloud database replication is enabled with native PostgreSQL logical replication from AWS RDS to Azure PostgreSQL Flexible Server. It creates extra paid database resources, so destroy the stack after recording.
- Canary/automated rollback is not enabled; current deployment uses rolling updates, readiness/liveness probes, and GitOps rollback by reverting Git. Production should add Argo Rollouts with Prometheus analysis.
- AWS EKS should be upgraded from `1.30` to `1.31` before the demo handoff window if time allows, then advanced one minor version at a time. See `docs/eks-upgrade-runbook.md`.

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
