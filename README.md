# 🚀 DevSecOps Enterprise Voting App (Multi-Cloud)

![Architecture: Multi-Cloud](https://img.shields.io/badge/Architecture-Multi--Cloud-blue)
![CI/CD: GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=github-actions&logoColor=white)
![GitOps: ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo&logoColor=white)
![Security: Sigstore+Falco](https://img.shields.io/badge/Security-Sigstore_%7C_Falco_%7C_Gatekeeper-success)

A **Production-grade, Multi-Cloud DevSecOps Reference Architecture**. This project deploys a microservices application across **AWS EKS** (Primary) and **Azure AKS** (Standby), connected via an IPsec VPN, featuring a fully automated DevSecOps CI/CD pipeline, Hub-and-Spoke GitOps, Keyless Image Signing, and Automated Incident Response (SOAR).

## 🌟 Core Architecture

```text
                        [Internet / Users]
                               │
                (Route53 / Cloudflare DNS Failover)
                 ┌─────────────┴─────────────┐
                 ▼ (Primary)                 ▼ (Warm-Standby)
        ┌──────────────────┐        ┌──────────────────┐
        │     AWS EKS      │        │    Azure AKS     │
        │  [Voting App]    │◄──────►│  [Voting App]    │
        │  [ArgoCD Hub]────┼─(VPN)──┼─►[ArgoCD Spoke]  │
        └───────┬──────────┘  BGP   └──────────┬───────┘
                │                              │
     (ESO) ◄────┘                              └────► (ESO)
        ▼                                              ▼
[AWS Secrets Manager]                         [Azure Key Vault]
[AWS RDS Postgres]                            [Azure Database]
[AWS ElastiCache]                                     
```

## 🔥 Enterprise DevSecOps Features

This repository is built following industry best practices and is divided into 6 distinct phases of maturity:

1. **Multi-Cloud Foundation & VPN:** AWS (Primary) and Azure (Warm-Standby) peered via BGP IPsec VPN. Uses **IRSA** (AWS) and **Workload Identity** (Azure) for passwordless cloud API access.
2. **Platform & GitOps (Hub-and-Spoke):** 
   - **ArgoCD** on AWS acts as the central Hub, deploying workloads to both EKS and AKS. 
   - **Azure Entra ID SSO** provides Role-Based Access Control (RBAC).
   - **External Secrets Operator (ESO)** bridges cloud secret managers (AWS Secrets Manager / Azure Key Vault) directly to Kubernetes.
3. **Stateful Managed Services:** Decoupled architecture. The Kubernetes cluster is completely stateless. State is offloaded to managed **AWS RDS (PostgreSQL)** and **AWS ElastiCache (Redis)**. Containers are locked down with `runAsNonRoot` and `capabilities: drop: ALL`.
4. **Supply Chain Security & Defense-in-Depth:**
   - **Shift-Left:** `Conftest` checks YAML syntax in Pull Requests.
   - **Shift-Right:** `OPA Gatekeeper` prevents malicious configurations at the cluster door (e.g., denying `latest` tags, requiring `runAsNonRoot`).
   - **Sigstore Cosign:** Keyless signature validation. The cluster will *deny* any image that was not built and signed by the official CI/CD pipeline.
5. **6-Stage Security CI/CD Pipeline:** 
   - Code Push -> `Gitleaks` (Secret Scan) -> `Semgrep` (SAST) -> `Checkov/tfsec` (IaC Scan) -> `Trivy` (Image Scan) -> `Anchore` (SBOM) -> `OWASP ZAP` (DAST on Staging) -> Human Approval -> Production.
   - Pushes Docker Images and signatures to **BOTH** AWS ECR and Azure ACR simultaneously using OIDC.
6. **Observability, SOAR & Disaster Recovery:**
   - **Observability:** Prometheus, Grafana (with custom SLI/SLO dashboards), Promtail, and Loki.
   - **SOAR (Automated Response):** `Falco` eBPF detects anomalous container behavior -> Slack Webhook -> GitHub Actions Approval -> Kubernetes `NetworkPolicy` isolates the compromised Pod without killing it (preserving forensics).
   - **Disaster Recovery:** Automated PowerShell scripts to trigger DNS failover and promote the Azure AKS cluster in case of an AWS region outage.

## 🛠️ Tech Stack

| Layer | Technologies |
|-------|--------------|
| **Infrastructure** | Terraform, AWS (VPC, EKS, RDS, ElastiCache), Azure (VNet, AKS) |
| **Compute / Platform** | Kubernetes, Helm, External Secrets Operator (ESO) |
| **CI/CD** | GitHub Actions, Multi-Architecture Docker Builds, ArgoCD |
| **Code Security (SAST)** | Gitleaks, Semgrep, Checkov, tfsec |
| **Supply Chain Security**| Trivy, Syft (SBOM), Sigstore (Cosign), OPA Gatekeeper, Conftest |
| **Runtime Security** | Falco (eBPF), Kubernetes Network Policies, Pod Security Context |
| **Observability** | Prometheus, Grafana, Loki, Promtail |

## 📁 Repository Structure

```text
DevSecOps-Voting-App/
├── .github/workflows/          # CI/CD, SOAR Incident Response, Quarantine Workflows
├── app/                        # Source code (Vote, Result, Worker)
├── k8s/                        # Helm charts & K8s Manifests for ArgoCD
├── Mentor/                     # Deep-dive architectural documentation (Phase 1 to 7)
├── observability/              # Custom Grafana Dashboards (SLI/SLO)
├── policies/                   # OPA Gatekeeper constraints, Conftest rules, Sigstore config
├── response/                   # SOAR Kubernetes isolation NetworkPolicies
├── runbooks/                   # Disaster Recovery & Failover procedures
├── scripts/                    # Automation (infra-up, dr-failover, sso-config)
└── terraform/                  # Multi-cloud IaC
    ├── environments/aws/       # EKS, RDS, VPN, ArgoCD Hub
    ├── environments/azure/     # AKS, Key Vault, VPN
    └── modules/                # Reusable Terraform components
```

## 🚀 Quick Start

### 1. Prerequisites
- AWS CLI & Azure CLI configured.
- Terraform >= 1.5.0
- PowerShell 7+
- A GitHub repository to host this code (for GitHub Actions OIDC).

### 2. Configure Repositories & SSO
Run the automated configuration scripts to set up GitHub Secrets (OIDC) and Azure Entra ID App Registrations:
```powershell
.\scripts\configure-github-repo.ps1
.\scripts\configure-argocd-entra-sso.ps1
```

### 3. Deploy Multi-Cloud Infrastructure (~30-40 mins)
Use the automated wrapper script to deploy AWS, Azure, and the BGP VPN Tunnel sequentially:
```powershell
.\scripts\infra-up.ps1
```

### 4. Apply Security Policies (Gatekeeper & Sigstore)
```powershell
.\scripts\apply-gatekeeper-policies.ps1
.\scripts\apply-sigstore-policy.ps1
```

### 5. Trigger the Pipeline
Commit code to `main`. Watch the GitHub Actions pipeline perform the 6-stage security scan, build, sign, and push to ECR/ACR. ArgoCD will automatically sync the new version to the cluster.

## 💣 Disaster Recovery Drill

To simulate an AWS Outage and failover to Azure:
1. Review `runbooks/dr-drill.md`.
2. Execute the failover script:
   ```powershell
   .\scripts\dr-failover.ps1
   ```
3. The script will sync the RDS password to Azure and promote the AKS cluster to Primary.

## 🧹 Cleanup

To destroy all resources on both clouds and prevent unexpected billing:
```powershell
.\scripts\infra-down.ps1 -AutoApprove
```

---
*For a complete, in-depth architectural walkthrough of every component in this repository, please read the documentation in the `Mentor/` directory.*
