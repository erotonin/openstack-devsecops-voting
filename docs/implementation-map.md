# Implementation Map

This map links the project scope to the implementation files.

## Multi-Cloud Foundation

| Requirement | Implementation |
| --- | --- |
| AWS primary site | `terraform/environments/aws`, `terraform/modules/networking`, `eks`, `rds`, `elasticache`, `ecr`, `secrets` |
| Azure warm standby | `terraform/environments/azure`, `terraform/modules/azure_networking`, `aks`, `azure_workload_identity` |
| Route-based IPSec VPN + BGP | `terraform/environments/aws/vpn.tf`, `terraform/environments/azure/vpn.tf` |
| Automated apply/destroy | `scripts/infra-up.ps1`, `scripts/infra-down.ps1`, `destroy.ps1` |
| Quota pre-check | `scripts/check-quota.ps1` |
| Post-apply verification | `scripts/verify-stack.ps1` |

## DevSecOps Pipeline

| Requirement | Implementation |
| --- | --- |
| OIDC cloud auth | `.github/workflows/ci-pipeline.yml`, `terraform/environments/aws/oidc.tf` |
| Secret scanning | Gitleaks in `.github/workflows/ci-pipeline.yml` and `.pre-commit-config.yaml` |
| SAST | Semgrep in CI and pre-commit |
| IaC scan | Checkov, tfsec, Conftest |
| Image scan | Trivy image scan |
| SBOM | Syft SPDX/CycloneDX output |
| Signing | Cosign keyless signing |
| DAST | OWASP ZAP baseline in CI |
| Production trigger | `workflow_dispatch` promotion with GitHub Environment approval |

## GitOps And Secrets

| Requirement | Implementation |
| --- | --- |
| AWS ArgoCD hub | `terraform/environments/aws/helm.tf` |
| Azure standby ArgoCD | `terraform/environments/azure/helm.tf` |
| AWS secret sync | External Secrets + AWS Secrets Manager in `terraform/environments/aws/helm.tf` |
| Azure secret sync | External Secrets + Azure Key Vault in `terraform/environments/azure/helm.tf`, `secrets.tf` |
| App Helm chart | `k8s/templates`, `k8s/values-prod.yaml`, `k8s/values-azure.yaml` |

## Policy And Runtime Security

| Requirement | Implementation |
| --- | --- |
| Signed image artifacts | Cosign keyless signing in `.github/workflows/ci-pipeline.yml` |
| Unsigned image enforcement | Sigstore policy-controller installed in `terraform/environments/aws/helm.tf`; `policies/sigstore/clusterimagepolicy-ecr-keyless.yaml`; `scripts/apply-sigstore-policy.ps1` |
| Deny latest / privileged / missing resources | `policies/gatekeeper`, `scripts/apply-gatekeeper-policies.ps1`, `policies/conftest` |
| Policy reject demo | `tests/policy`, `scripts/test-policy-rejects.ps1` |
| Pod hardening | `k8s/templates/*`, namespace PSS labels |
| Detecting | Falco rules in `terraform/environments/aws/helm.tf` |
| Responding | `.github/workflows/runtime-incident.yml`, `runbooks/runtime-response.md`, `response/k8s/quarantine-networkpolicy.yaml` |

## Monitoring, Logging, SLO

| Requirement | Implementation |
| --- | --- |
| Monitoring | kube-prometheus-stack in `terraform/environments/aws/helm.tf` |
| Logging | Loki + Promtail in `terraform/environments/aws/helm.tf` |
| SLI/SLO metrics | `/metrics` in `vote/app.py`, `result/server.js` |
| Alerts | `k8s/templates/prometheusrule.yaml` |
| Dashboard | `observability/grafana-dashboards/voting-slo.json` |
| SLO definition | `docs/slo.md` |

## DR Demo

| Requirement | Implementation |
| --- | --- |
| Scale AKS | `scripts/dr-failover.ps1` |
| Sync Azure app | Azure standby ArgoCD application in `terraform/environments/azure/helm.tf` |
| Restore/seed data config | `scripts/dr-update-azure-runtime-secret.ps1` |
| Measure RTO/RPO | `runbooks/dr-drill.md` |
| Rollback plan | `runbooks/rollback.md`, `runbooks/dr-drill.md` |
| DNS/endpoint switch | `runbooks/dns-failover.md` |
| Demo evidence | `docs/evidence-checklist.md` |

## Known Limits

- Cross-cloud live database replication is implemented as an opt-in native PostgreSQL logical replication path. The cost-capped fallback remains restore or seed data.
- Auto-quarantine is optional demo mode; default response is alert and human triage.
- Full enterprise SSO is not implemented yet; ArgoCD RBAC groups are prepared as a baseline.
