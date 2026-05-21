# Evidence Checklist

Use this checklist while recording the final demo and writing the report.

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
- Backup/seed timestamp used for RPO.
- Azure vote UI working.
- DNS/endpoint switch evidence.
- Azure for Students note: use one AKS user node unless quota is increased.

## Destroy

- Terraform destroy output.
- Post-destroy check for NAT gateways, load balancers, VPN gateways, public IPs, disks, snapshots, RDS, Redis, EKS, and AKS nodes.
