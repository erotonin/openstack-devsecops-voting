# Capstone Presentation Guide

## Slide Deck Nen Co Nhung Gi

### 1. Title

- Ten de tai: Secure CI/CD Pipeline for DevSecOps Voting App.
- Nhom/sinh vien, mon hoc, ngay bao cao.
- Mot cau mo ta ngan: pipeline chan loi bao mat tu PR den runtime tren Kubernetes multi-cloud.

### 2. Problem Statement

Noi van de theo cach that:

- Secrets, vulnerable dependencies, Docker image CVE va IaC misconfiguration co the vao production qua CI/CD.
- Neu chi scan thu cong cuoi ky thi phat hien muon, sua kho va de miss.
- Muc tieu la tao feedback som tren PR, chi build/sign/deploy khi da qua gate.

### 3. Architecture Overview

Nen dung mot so do gom 4 lane:

- Developer/GitHub: PR, review, branch protection, Dependabot.
- CI/CD: gitleaks, Semgrep, Checkov, tfsec, Trivy, Syft SBOM, Cosign, ZAP.
- Cloud/Runtime: AWS EKS primary, Azure AKS standby, RDS, ElastiCache, Azure PostgreSQL standby optional.
- Security/Observability: Gatekeeper, Sigstore policy-controller, Kyverno, Falco, Prometheus/Grafana, Loki.

### 4. Pipeline Flow

Giai thich theo dung thu tu:

1. Developer mo PR vao `main`.
2. PR security gates chay secret scan, SAST, IaC scan, dependency/filesystem scan, Helm validation va Conftest.
3. Neu fail, workflow tao GitHub issue de triage.
4. Khi PR duoc merge vao `main`, workflow build 3 images `vote`, `result`, `worker`.
5. Image duoc scan bang Trivy, tao SBOM bang Anchore/Syft action, push len ECR/ACR, sign bang Cosign keyless.
6. DAST scan staging endpoint bang OWASP ZAP.
7. Workflow tao GitOps promotion PR cap nhat `k8s/values-prod.yaml` va `k8s/values-azure.yaml`.
8. ArgoCD sync theo Git, khong deploy truc tiep tu CI.

### 5. Security Gates

Nen chia thanh bang:

| Risk | Control |
| --- | --- |
| Secret leaked | Gitleaks pre-commit va GitHub Action |
| Code bug/security smell | Semgrep |
| Terraform/K8s misconfig | Checkov, tfsec, Conftest |
| Vulnerable image/dependency | Trivy |
| Supply chain tampering | SBOM + Cosign keyless signing |
| Unsigned image runtime | Sigstore policy-controller / Kyverno |
| Insecure pod config | Pod Security + Gatekeeper |
| Runtime suspicious shell | Falco + incident workflow |

### 6. Infrastructure

- AWS primary: VPC, EKS, RDS PostgreSQL, ElastiCache Redis, ECR, Secrets Manager.
- Azure standby: VNet, AKS, ACR, Key Vault, optional PostgreSQL Flexible Server.
- Site-to-site VPN: AWS VGW <-> Azure VNG, BGP route exchange.
- EKS node group uses 4 worker nodes to fit observability, policy, GitOps and runtime controllers.

### 7. Disaster Recovery

Noi ro 2 muc:

- Compute failover: `scripts/dr-failover.ps1` scale AKS, refresh ArgoCD, wait workloads.
- Data failover optional: native PostgreSQL logical replication from AWS RDS to Azure PostgreSQL.
- DNS failover: `scripts/configure-route53-failover.ps1` tao Route53 active-passive record khi co hosted zone.

Quan trong: tai khoan hien tai chua co Route53 hosted zone, nen DNS failover public can them domain/hosted zone truoc khi chay that.

### 8. Monitoring And Runtime Response

- Prometheus/Grafana: SLI/SLO dashboard, latency, error rate, target availability.
- Loki/Promtail: log aggregation.
- Falco: detect shell spawned in voting namespace.
- Runtime incident workflow: tao issue tu alert.
- Quarantine workflow: manual approval qua `security-response` environment roi label pod de NetworkPolicy isolate.

### 9. Evidence

Can chup/quay:

- GitHub Actions main run success.
- PR fail demo co annotations va issue triage.
- Promotion PR duoc tao tu GitOps.
- ArgoCD app `voting-aws` Synced Healthy.
- Kubernetes policy reject demo.
- Grafana dashboard.
- Falco/runtime incident workflow.
- DR failover script output RTO.

### 10. Lessons Learned

Nen noi dung "co kinh nghiem that":

- Khong phai moi security control deu nen auto-fix/auto-merge; production approval va GitOps PR la approval boundary.
- Cloud managed services co nhieu loi thuc te: KMS policy, Helm timeout, pod density, provider CRD ordering.
- Cost-aware design quan trong: mot so feature bat opt-in de tranh ton tien khi demo.
- Terraform target chi dung de bootstrap/recover, sau do luon chay full plan de kiem tra drift.

## Demo Script 8-12 Phut

### Demo 1: PR Security Gate

1. Mo PR demo co loi.
2. Chi vao GitHub Actions `PR security gates`.
3. Giai thich annotation: Checkov/Semgrep/Trivy tim loi o file nao.
4. Chi vao issue duoc tao tu workflow failure.

Noi: "Day la shift-left. Loi bi chan o PR, chua vao image, chua vao cluster."

### Demo 2: Main Pipeline

1. Mo run success tren `main`.
2. Show 3 matrix jobs build image.
3. Show artifact SBOM.
4. Show Cosign sign image by digest.
5. Show DAST staging success.
6. Show GitOps promotion PR.

Noi: "CI build va sign artifact; deployment state van di qua GitOps PR."

### Demo 3: Runtime Policy

Chay:

```powershell
.\scripts\test-policy-rejects.ps1 -Context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster
```

Giai thich:

- Pod latest tag bi reject.
- Pod thieu resources bi reject.
- Privileged container bi reject.

### Demo 4: Observability

Chay:

```powershell
.\scripts\open-grafana.ps1
```

Show:

- HTTP success rate.
- p95 latency.
- error rate.
- availability targets.

### Demo 5: DR

Chay:

```powershell
.\scripts\dr-failover.ps1 -UserNodeCount 1
```

Neu can UI:

```powershell
.\scripts\dr-failover.ps1 -UserNodeCount 1 -OpenPortForward
```

Noi:

- AWS la primary.
- Azure la warm standby.
- Script do RTO bang timestamp.
- Logical replication la opt-in path de dong bo bang `votes`.

## Architecture Image Prompt

Dung prompt nay cho GPT/image model:

```text
Create a clean professional cloud architecture diagram for a DevSecOps capstone project.

Style: modern technical diagram, white background, crisp icons, readable labels, no decorative gradients.

Show four horizontal lanes:
1. Developer and GitHub:
   Developer -> Pull Request -> Branch Protection -> GitHub Actions.
   Include Dependabot and GitHub Issues triage.
2. Secure CI/CD Pipeline:
   PR gates: Gitleaks, Semgrep SAST, Checkov/tfsec IaC scan, Trivy filesystem scan, Helm lint, Conftest OPA.
   Main pipeline: Docker build for vote/result/worker, Trivy image scan, SBOM generation, Cosign keyless signing, push to AWS ECR and Azure ACR, OWASP ZAP DAST, GitOps promotion PR.
3. Runtime and GitOps:
   ArgoCD syncs Kubernetes manifests to AWS EKS primary and Azure AKS warm standby.
   Admission controls: OPA Gatekeeper, Sigstore policy-controller, Kyverno image verification, Pod Security.
4. Multi-cloud Infrastructure and DR:
   AWS: VPC, EKS, RDS PostgreSQL primary, ElastiCache Redis, Secrets Manager, ECR, Route53 health check.
   Azure: VNet, AKS standby, Azure PostgreSQL Flexible Server subscriber, Key Vault, ACR.
   Connect AWS and Azure through IPsec Site-to-Site VPN with BGP.
   Show PostgreSQL logical replication from AWS RDS to Azure PostgreSQL over VPN.
   Show Route53 DNS failover from AWS endpoint to Azure endpoint.

Add observability and runtime security side panel:
Prometheus/Grafana, Loki/Promtail, Falco, Runtime Incident GitHub workflow, Quarantine workflow with manual approval.

Use arrows to show:
PR security gate blocks unsafe code.
Main branch builds signed images.
GitOps PR updates image tags.
ArgoCD deploys from Git.
Health check triggers DNS failover.
Logical replication sends WAL deltas over VPN.
```

## Cau Tra Loi Van Dap Nen Nho

- "Tai sao GitOps promotion dung PR, khong auto merge?"
  De giu approval boundary. CI co the build/sign/scan tu dong, nhung production state nen duoc review qua Git.

- "Tai sao logical replication cost-effective?"
  Vi no gui WAL delta cua thay doi, khong copy ca database. Traffic chay qua VPN private path.

- "Tai sao DNS failover chua chay that neu chua co domain?"
  Route53 can hosted zone co quyen quan ly DNS. Account hien tai khong co hosted zone, nen script san sang nhung can them domain/zone.

- "Tai sao them node thu 4?"
  EKS node bi gioi han so pod theo instance/IP capacity. Observability + GitOps + policy controllers can pod slots, nen 4 node giup cluster on dinh hon.
