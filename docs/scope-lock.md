# Scope Lock - DevSecOps Voting App

This project implements a production-like student capstone for a multi-cloud DevSecOps voting application.

## Locked Architecture

- AWS is the primary hot site.
- Azure is the warm standby site.
- Infrastructure is provisioned with Terraform.
- AWS and Azure are connected with route-based IPSec VPN and BGP.
- GitHub Actions uses OIDC federation, not static cloud access keys.
- ArgoCD deploys the application with GitOps.
- AWS runs the primary ArgoCD hub, while AKS has a small standby ArgoCD controller for DR.
- External Secrets Operator syncs secrets from AWS Secrets Manager and Azure Key Vault.
- Kubernetes admission policies block unsafe workloads.
- Runtime operations include monitoring, logging, detection, and response.
- DR is demonstrated by recovering the application on Azure and measuring RTO/RPO.

## Production-Like Release Flow

Production is not deployed by pushing directly to `main`.

```text
feature branch
  -> pull request
  -> required security checks
  -> code review
  -> merge to main
  -> build, scan, SBOM, sign
  -> staging deploy
  -> OWASP ZAP DAST
  -> production environment approval
  -> ArgoCD production sync
```

## Core Security Gates

- Gitleaks secret scan.
- Semgrep SAST.
- Checkov and tfsec IaC scan.
- Trivy filesystem and image scan.
- Syft SBOM generation.
- Cosign image signing.
- OWASP ZAP DAST.
- Conftest and Gatekeeper policy checks.
- Cosign signing in CI, with Policy Controller installed as the cluster-side verification baseline.
- Strict unsigned-image enforcement is enabled only after the demo images are signed and promoted through CI, otherwise it would block the current manually built student-demo images.

## Runtime Operations

### Monitoring

- Prometheus.
- Grafana.
- Alertmanager.
- SLI/SLO dashboards.

### Logging

- Loki.
- Promtail.
- Cloud audit logs where available.

### Detecting

- Falco runtime rules.
- CI security scanners.

### Responding

Default response is alert-first:

```text
Falco -> Falcosidekick -> Slack/GitHub Issue -> human triage
```

Auto-quarantine is optional demo mode only:

```text
Falco -> Falcosidekick -> webhook/Lambda -> quarantine voting namespace
```

Guardrails:

- Disabled by default.
- Only acts when `enable_auto_quarantine=true`.
- Only targets the `voting` namespace.
- Never targets `kube-system`, `argocd`, `monitoring`, or security namespaces.

## SLI/SLO Demo Targets

SLIs:

- HTTP success rate.
- p95 latency.
- Availability.
- Error rate.

SLO demo targets:

- Availability during normal operation >= 99% in the test window.
- p95 latency < 500 ms under demo load.
- Alert fires within 1 minute of simulated failure.
- Falco runtime alert fires within 1 minute of simulated suspicious behavior.

## Explicit Limitations

- Cross-cloud DB replication is not core scope.
- DR data recovery is backup/restore or seed-restore based.
- Continuous DB replication is future work.
- Auto-quarantine is not enabled by default because false positives can harm production workloads.
