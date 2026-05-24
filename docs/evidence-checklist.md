# Evidence Checklist

Use this checklist while recording the final demo and writing the report.

## Current Verified Evidence

- Main CI/CD succeeded after the latest dependency PR merge: https://github.com/erotonin/devsecops-voting/actions/runs/26268048524
- Manual OWASP ZAP DAST succeeded against AWS staging: https://github.com/erotonin/devsecops-voting/actions/runs/26267394350
- Branch protection is enabled on `main` with PR review and required status check `PR security gates`.
- GitHub repository configuration script completed successfully: `scripts/configure-github-repo.ps1`.
- AWS ArgoCD app `voting-aws` is `Synced Healthy`.
- Azure ArgoCD app `voting-azure` is `Synced Healthy`.
- AWS public staging vote endpoint returned HTTP 200:
  `http://a4bdf43777192482cb1c20c79adafff8-2084416586.us-east-1.elb.amazonaws.com`
- DR drill recovered Azure warm standby with RTO `1.09 minutes`.
- Runtime incident workflow succeeded and created issue #27:
  https://github.com/erotonin/devsecops-voting/issues/27
- Sigstore Policy Controller enforces keyless GitHub Actions signatures for AWS ECR voting app images.
- Admission reject tests passed for unsafe policy fixtures.
- Prometheus/Grafana, Loki/Promtail, and Falco/Falcosidekick pods are running.
- Vote and result services expose Prometheus metrics for SLI/SLO queries.
- Checkov and tfsec currently run as report-only baseline scans. Trivy, Semgrep, Gitleaks, Helm, and Conftest remain blocking PR gates.
- Detailed evidence is recorded in `docs/demo-evidence-2026-05-22.md`.

## Infrastructure

- Terraform apply output for AWS and Azure.
- AWS EKS nodes and namespaces.
- Azure AKS nodes and namespaces.
- VPN tunnel/BGP status from AWS and Azure.
- ECR and ACR repositories.

## CI/CD

- Pull request checks passing.
- Gitleaks, Semgrep, Checkov/tfsec, Trivy, Syft, Cosign, and ZAP job results.
- SBOM artifact.
- Signed image evidence.
- Production promotion approval screenshot.

## GitOps And Secrets

- AWS ArgoCD `voting-aws` app healthy/synced.
- Azure ArgoCD `voting-azure` app healthy/synced.
- ExternalSecret synced in AWS and Azure.
- No plaintext production database password in Helm values.
- HTTP smoke test through `scripts/check-app-http.ps1` for AWS and Azure.

## Policy

- `deny-latest.yaml` rejected.
- `deny-privileged.yaml` rejected.
- `deny-missing-resources.yaml` rejected.
- Gatekeeper audit status.
- Policy Controller status for signed image policy.

## Monitoring, Logging, Detecting, Responding

- Grafana SLI/SLO dashboard.
- Prometheus targets for `vote` and `result`.
- Loki query for voting app logs.
- Falco alert for shell execution in `voting`.
- GitHub runtime incident issue or webhook destination.
- Optional quarantine demo output, if used.

## DR

- DR start timestamp.
- Azure app ready timestamp.
- RTO calculation.
- PostgreSQL logical replication status or fallback backup/seed timestamp used for RPO.
- Azure vote UI working.
- DNS/endpoint switch evidence.
- Azure for Students note: use one AKS user node unless quota is increased.

## Destroy

- Terraform destroy output.
- Post-destroy check for NAT gateways, load balancers, VPN gateways, public IPs, disks, snapshots, RDS, Redis, EKS, and AKS nodes.
