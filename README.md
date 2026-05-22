# DevSecOps Voting App on AWS EKS

## Current Project Docs

- Final demo script: `docs/demo-script.md`
- Live demo evidence: `docs/demo-evidence-2026-05-22.md`
- Scope lock: `docs/scope-lock.md`
- Implementation map: `docs/implementation-map.md`
- Evidence checklist: `docs/evidence-checklist.md`

A production-grade microservices application deployed on **AWS EKS** with a fully automated **DevSecOps CI/CD pipeline**, **GitOps** continuous delivery, and **real-time monitoring**.

## Architecture

```
Developer Push Code
        │
        ▼
┌───────────────────────────────────────────────┐
│        GitHub Actions (CI - Parallel)         │
│                                               │
│  ┌─────────────┐    ┌──────────────────────┐  │
│  │ OWASP (SCA) │    │ SonarQube (SAST)     │  │
│  │ Dependency   │    │ Python + C# Scanner  │  │
│  │ Check        │    │                      │  │
│  └──────┬──────┘    └──────────┬───────────┘  │
│         └──────────┬───────────┘              │
│                    ▼                          │
│  Docker Build → Trivy Scan → Push to ECR      │
│                    │                          │
│         Auto-update values.yaml               │
└───────────────────┬───────────────────────────┘
                    │ git push
                    ▼
┌───────────────────────────────────────────────┐
│              Argo CD (GitOps)                 │
│  Detect changes → Pull image → Rolling Update │
└───────────────────┬───────────────────────────┘
                    ▼
┌───────────────────────────────────────────────┐
│              AWS EKS Cluster                  │
│  Vote │ Result │ Worker │ Redis │ PostgreSQL  │
│                                               │
│         Prometheus → Grafana (Monitoring)     │
└───────────────────────────────────────────────┘
```

## Tech Stack

| Category | Tools |
|----------|-------|
| **Application** | Python (Flask), Node.js, .NET 7, Redis, PostgreSQL |
| **Containerization** | Docker (Multi-stage builds) |
| **Infrastructure** | Terraform, AWS VPC, EKS, ECR, IAM, OIDC |
| **CI/CD** | GitHub Actions (parallel jobs) |
| **Security** | OWASP Dependency-Check, SonarQube (SAST), Trivy (Container Scan) |
| **GitOps** | Argo CD (auto-sync, self-heal, cascading delete) |
| **Monitoring** | Prometheus, Grafana (kube-prometheus-stack) |
| **Authentication** | OIDC (GitHub ↔ AWS, no Access Keys) |

## Project Structure

```
DevSecOps-Voting-App/
├── .github/workflows/
│   └── ci-pipeline.yml         # CI/CD pipeline (3 parallel jobs)
├── vote/                       # Python/Flask - voting frontend
│   └── Dockerfile
├── result/                     # Node.js - results frontend
│   └── Dockerfile
├── worker/                     # .NET 7 - vote processor
│   ├── Dockerfile
│   └── .dockerignore
├── k8s/                        # Kubernetes Helm Chart
│   ├── Chart.yaml
│   ├── values.yaml             # Auto-updated by CI pipeline
│   ├── argocd-app.yaml         # ArgoCD Application (with finalizer)
│   └── templates/
│       ├── vote.yaml
│       ├── result.yaml
│       ├── worker.yaml
│       ├── redis.yaml
│       └── db.yaml
├── terraform/                  # Infrastructure as Code
│   ├── provider.tf             # AWS, Helm, Kubernetes providers
│   ├── variables.tf            # Centralized configuration
│   ├── vpc.tf                  # VPC, 4 Subnets, NAT Gateway
│   ├── iam.tf                  # IAM Roles (Least Privilege)
│   ├── eks.tf                  # EKS Cluster + Node Group
│   ├── ecr.tf                  # 3 ECR Repositories
│   ├── oidc.tf                 # GitHub Actions OIDC Federation
│   ├── helm.tf                 # ArgoCD, SonarQube, Prometheus
│   └── outputs.tf
├── docker-compose.yml          # Local development
├── suppression.xml             # OWASP false-positive suppressions
└── .gitignore
```

## Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker](https://www.docker.com/get-started)

## Quick Start

### 1. Deploy Infrastructure (~15-20 min)
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

### 2. Connect to EKS
```bash
aws eks update-kubeconfig --region us-east-1 --name voting-app-cluster
```

### 3. Configure SonarQube Token
```bash
# Get SonarQube URL
kubectl get svc -n sonarqube

# Login (admin/admin) → Create Token → Add to GitHub Secrets:
# - SONAR_TOKEN
# - SONAR_HOST_URL
```

### 4. Configure GitHub Secrets
| Secret Name | Value |
|-------------|-------|
| `AWS_ROLE_ARN` | Output from `terraform output github_actions_role_arn` |
| `SONAR_TOKEN` | Generated from SonarQube UI |
| `SONAR_HOST_URL` | SonarQube LoadBalancer URL |

### 5. Trigger Pipeline
```bash
git add . && git commit -m "Deploy" && git push
```

### 6. Access Applications
```bash
# Voting App
kubectl get svc vote result

# ArgoCD (admin / admin123)
kubectl get svc -n argocd argocd-server

# Grafana (admin / admin123)
kubectl get svc -n monitoring prometheus-grafana

# SonarQube (admin / admin)
kubectl get svc -n sonarqube
```

## CI/CD Pipeline Flow

The pipeline runs **3 parallel jobs** for maximum speed:

```
Push to main
    ├── Job 1: OWASP Scan ──────────┐
    ├── Job 2: SonarQube Scan ──────┤ (parallel)
    │                                │
    │    Both PASS?                  │
    │        │                       │
    │        ▼                       │
    └── Job 3: Build & Deploy ──────┘
             │
             ├── Docker Build (vote, result, worker)
             ├── Trivy Container Scan
             ├── Push to ECR
             └── Update values.yaml → ArgoCD auto-sync
```

## Cleanup

```bash
cd terraform
terraform destroy -auto-approve
```

## Network Architecture

```
                     Internet
                        │
                 Internet Gateway
                        │
          ┌─────────────┴─────────────┐
     Public Subnet 1a            Public Subnet 1b
     (10.0.1.0/24)              (10.0.2.0/24)
     [NAT Gateway]              [Load Balancers]
          │
          └─────────────┬─────────────┐
     Private Subnet 1a           Private Subnet 1b
     (10.0.11.0/24)             (10.0.12.0/24)
     [EKS Node 1]               [EKS Node 2]
```

## Security Features

- **OIDC Federation**: No hardcoded AWS credentials in CI/CD
- **Multi-stage Docker Builds**: Minimal attack surface
- **3-Layer Security Scanning**: SCA + SAST + Container Scan
- **Private Subnets**: EKS nodes not exposed to internet
- **ECR Scan on Push**: Automatic vulnerability detection
- **ArgoCD Self-Heal**: Auto-reverts unauthorized changes on cluster
- **Least Privilege IAM**: Separate roles for cluster and nodes
