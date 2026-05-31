# DevSecOps Voting App

This repository is a production-inspired DevSecOps capstone for a small voting application. It combines application code, Terraform infrastructure, Kubernetes GitOps deployment, CI/CD security gates, image signing, admission policy, observability, runtime response, and disaster recovery.

The current implementation uses AWS as the active primary site and Azure as the warm standby site. AWS and Azure are connected by a route-based IPsec VPN with BGP. The codebase supports PostgreSQL logical replication from AWS RDS to Azure PostgreSQL Flexible Server; in the cost-capped demo, the Azure database standby can be enabled for a DR drill or left as a restore-required placeholder.

## Current Architecture

```text
Developers
  -> pre-commit hooks
  -> feature pull request into dev
  -> light feature security gate
  -> merge to dev
  -> integration security gate on combined work
  -> release pull request from dev into main
  -> full release gate on final code and deploy config
  -> build images, generate SBOM, push immutable digests
  -> Cosign keyless sign and verify identity plus crypto policy
  -> Trivy image scan by digest
  -> ArgoCD syncs staging from the staging GitOps branch
  -> smoke test and OWASP ZAP DAST against staging
  -> GitOps promotion PR updates production Helm values and image digests
  -> ArgoCD syncs production from main after review
```

```text
AWS primary site
  VPC, EKS, ECR, RDS PostgreSQL, ElastiCache Redis, Secrets Manager
  ArgoCD, External Secrets Operator, Gatekeeper, Sigstore policy-controller
  Prometheus/Grafana, Loki/Promtail, Falco/Falcosidekick

Azure warm standby site
  VNet, AKS, ACR, Azure Key Vault, optional Azure PostgreSQL Flexible Server
  ArgoCD standby controller, External Secrets Operator

Cross-cloud path
  AWS VPN Gateway <-> Azure Virtual Network Gateway
  BGP routes carry private traffic between the two networks
  Optional PostgreSQL logical replication sends WAL deltas from AWS to Azure during a DB standby drill
```

Route53 DNS failover support is implemented in `scripts/configure-route53-failover.ps1`, but it requires a real Route53 hosted zone/domain. The current AWS account has no hosted zone, so public DNS failover is ready as code but not live-configured.

On Azure, only the `vote` service is exposed with a public LoadBalancer by default. The `result` service stays `ClusterIP` to avoid the public IP quota limit in student subscriptions; use `kubectl port-forward` for demo access.

## Implemented Security Controls

| Area | Implementation |
| --- | --- |
| Local pre-commit | `.pre-commit-config.yaml` runs YAML hygiene, Gitleaks, Terraform format/validate, and optional local wrappers for Checkov, Hadolint, yamllint, and Semgrep when those CLIs are installed. CI remains the authoritative security gate. |
| PR security gates | Feature PRs into `dev` run fast feedback checks. Release PRs into `main` run full SAST, IaC, dependency, Helm render, and policy checks before release build is allowed. |
| Build security | Docker build for `vote`, `result`, and `worker`; Syft SPDX SBOM generation; Trivy image scan after signature verification. |
| Signing | Cosign keyless signing through GitHub Actions OIDC/Fulcio. Images are signed by digest, not mutable tag. CI verifies the certificate identity and rejects weak certificate/signature algorithms before scanning and promotion. |
| Registry | Images are pushed to AWS ECR and Azure ACR. ECR tags are immutable and scan-on-push is enabled. |
| GitOps staging | After main build/sign/verify/scan, CI updates the `staging` branch with `k8s/values-staging.yaml`. The AWS ArgoCD staging app tracks that branch and deploys to `voting-staging`. |
| GitOps production | After staging smoke test and ZAP DAST, CI opens a promotion PR that updates `k8s/values-prod.yaml` and `k8s/values-azure.yaml` on `main`. The AWS and Azure production ArgoCD apps deploy only after that PR is reviewed and merged. |
| Admission policy | Gatekeeper rejects unsafe Kubernetes manifests. AWS EKS enforces signed ECR images with Sigstore policy-controller. |
| Secrets | External Secrets Operator syncs AWS Secrets Manager and Azure Key Vault into Kubernetes. Secrets are not committed in Helm values. |
| Runtime security | Falco detects suspicious runtime behavior and can open a GitHub incident workflow. Quarantine is a manual approval workflow. |
| Observability | kube-prometheus-stack, Grafana SLI/SLO dashboard, Loki, Promtail, and PrometheusRule resources. |
| DR | Azure warm standby, ArgoCD sync, optional PostgreSQL logical replication or restore-required DB placeholder, and Route53 failover script when a hosted zone exists. |

## Repository Structure

```text
.github/workflows/        GitHub Actions pipelines and runtime response workflows
docs/                     Demo guides, evidence checklist, scope and presentation notes
healthchecks/             Container health check helpers
k8s/                      Helm chart, values files, and ArgoCD application manifests
observability/            Grafana dashboard JSON
policies/                 Gatekeeper, Conftest, and Sigstore policy definitions
response/                 Quarantine NetworkPolicy for incident response
result/                   Node.js result service
runbooks/                 Apply/destroy, rollback, DR, DNS, and replication runbooks
scripts/                  PowerShell automation for infra, GitHub, DR, SSO, and verification
seed-data/                Demo data generation helpers
terraform/                AWS/Azure Terraform environments and reusable modules
tests/policy/             Admission-policy negative test fixtures
vote/                     Python vote service
worker/                   .NET worker service
```

Personal lecture notes are intentionally ignored through `.gitignore` (`BaiGiang/`, `Mentor/`, `lectures/`, `notes/`) because they are not needed for the runnable project.

## Prerequisites

- PowerShell 7+
- Git
- GitHub CLI authenticated with `repo` and `workflow` scope
- AWS CLI authenticated to account `800557027783`
- Azure CLI authenticated to subscription `007e5e26-e0d0-4389-9cde-5731cdb86639`
- Terraform
- kubectl
- Helm
- Docker, for local image testing
- Python with `pre-commit`

Install and enable pre-commit:

```powershell
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

On Windows, the local Semgrep, Checkov, Hadolint, and yamllint hooks use wrapper scripts under `scripts/`. If a CLI is not installed locally, the hook prints a skip message instead of blocking commits. GitHub Actions still runs the real security gates on Linux.

## Deploy

The main apply wrapper stages Terraform so resources that depend on remote-state outputs and Kubernetes CRDs are created in the right order.

```powershell
.\scripts\infra-up.ps1 -AutoApprove
```

After apply, configure GitHub repository variables/secrets from Terraform outputs:

```powershell
.\scripts\configure-github-repo.ps1 `
  -StagingUrl "<AWS vote LoadBalancer URL>" `
  -ConfigureBranchProtection
```

Apply or verify admission policies:

```powershell
.\scripts\apply-gatekeeper-policies.ps1
.\scripts\apply-sigstore-policy.ps1 -Apply
```

The Sigstore policy is applied to `voting-staging` and `voting-production`. The CI signing sequence is intentionally digest-based:

```text
build image -> push registry -> resolve digest -> cosign sign digest -> cosign verify identity and crypto policy -> trivy scan digest
```

Cosign verifies signature identity and certificate metadata. Trivy scans vulnerabilities; it does not verify signatures.

Configure PostgreSQL logical replication when the cloud databases are up:

```powershell
.\scripts\setup-postgres-logical-replication.ps1
```

## Verify

Run the general stack verifier:

```powershell
.\scripts\verify-stack.ps1
```

Quick AWS app health:

```powershell
$vote = kubectl --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster `
  -n voting-staging get svc vote -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
Invoke-WebRequest -UseBasicParsing "http://$vote/healthz"
```

Expected result: HTTP `200` and a JSON body showing `status: ok`.

Check ArgoCD:

```powershell
kubectl --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster `
  -n argocd get application voting-staging voting-production

kubectl --context devsecops-voting-aks `
  -n argocd get application voting-azure
```

Expected result: AWS staging and production should be `Synced Healthy`; Azure production should be healthy after the warm-standby sync succeeds.

## Demo Entry Points

Use the verified demo runbook:

```text
docs/teacher-aligned-demo-runbook.md
docs/devsecops-phase-model.md
docs/teacher-aligned-architecture.md
docs/architecture-conceptual.md
docs/devsecops-pipeline-diagram.md
docs/pipeline-frameworks.md
docs/demo-checklist.md
```

Useful scripts:

```powershell
.\scripts\test-policy-rejects.ps1 -Context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster
.\scripts\open-argocd.ps1
.\scripts\open-grafana.ps1
.\scripts\run-production-approval.ps1
.\scripts\dr-failover.ps1 -SkipScale
```

## Cleanup

Destroy the full demo to avoid cost:

```powershell
.\destroy.ps1 -AutoApprove
```

Then check for expensive leftovers:

```powershell
aws eks list-clusters --region us-east-1
aws rds describe-db-instances --region us-east-1 --query "DBInstances[].DBInstanceIdentifier"
aws elasticache describe-replication-groups --region us-east-1 --query "ReplicationGroups[].ReplicationGroupId"
az aks list -o table
az network vnet-gateway list -o table
```

## Known Cost-Aware Decisions

- Azure ACR uses Basic SKU. Premium-only controls such as private endpoints, geo-replication, image quarantine, and Defender integration are documented as production hardening items.
- Azure image verification with Kyverno is disabled by default because Kyverno cannot verify private ACR manifests without extra registry credentials. AWS EKS remains the enforced signed-image admission path through Sigstore policy-controller.
- Azure warm standby uses an in-cluster Redis service to avoid extra managed Redis cost. PostgreSQL standby is optional in the cost-capped demo; when disabled, Azure runtime secrets intentionally point at a restore-required database host.
- Route53 failover requires a real hosted zone. The script exists, but no hosted zone is currently present in the AWS account.
- GitHub branch protection is configured, but repository owners/admins can still bypass unless admin bypass is explicitly disabled in GitHub rulesets.
