# Cloud Architecture Diagram

Use this diagram in slides or report to explain the deployed cloud architecture. It is intentionally infrastructure-focused, while the pipeline diagram should stay CI/CD-focused.

```mermaid
flowchart LR
  Dev["Developer"] --> GH["GitHub repository"]
  GH --> Actions["GitHub Actions CI/CD\nGitleaks, Semgrep, Checkov, tfsec, Trivy, Syft, Cosign, ZAP"]
  Actions --> ECR["AWS ECR\nsigned images"]
  Actions --> ACR["Azure ACR\nsigned images"]
  Actions --> PR["GitOps promotion PR\nupdates Helm values and digests"]
  PR --> ArgoAWS["ArgoCD on AWS EKS"]
  PR --> ArgoAzure["ArgoCD on Azure AKS"]

  subgraph AWS["AWS primary site"]
    VPC["VPC 10.0.0.0/16"]
    EKS["EKS voting-app-cluster"]
    AppAWS["vote, result, worker\n3 replicas"]
    RDS["RDS PostgreSQL\npublisher"]
    Redis["ElastiCache Redis"]
    SM["AWS Secrets Manager"]
    ESOAWS["External Secrets Operator"]
    Gatekeeper["OPA Gatekeeper"]
    Sigstore["Sigstore policy-controller"]
    Obs["Prometheus, Grafana,\nLoki, Promtail, Falco"]
    VGW["AWS VPN Gateway"]
    EKS --> AppAWS
    AppAWS --> RDS
    AppAWS --> Redis
    SM --> ESOAWS --> AppAWS
    Gatekeeper --> EKS
    Sigstore --> EKS
    Obs --> EKS
    VPC --> EKS
    VPC --> RDS
    VPC --> Redis
    VPC --> VGW
  end

  subgraph Azure["Azure warm standby site"]
    VNet["VNet 10.1.0.0/16"]
    AKS["AKS devsecops-voting-aks"]
    AppAzure["vote, result, worker\nstandby"]
    PG["Azure PostgreSQL Flexible Server\nsubscriber"]
    KV["Azure Key Vault"]
    ESOAzure["External Secrets Operator"]
    VNG["Azure Virtual Network Gateway"]
    AKS --> AppAzure
    AppAzure --> PG
    KV --> ESOAzure --> AppAzure
    VNet --> AKS
    VNet --> PG
    VNet --> VNG
  end

  ECR --> ArgoAWS
  ACR --> ArgoAzure
  ArgoAWS --> EKS
  ArgoAzure --> AKS
  VGW <-->|"IPsec VPN + BGP"| VNG
  RDS -->|"PostgreSQL logical replication\nWAL deltas over private VPN"| PG
  DNS["Route53 failover\nrequires hosted zone"] -.-> AppAWS
  DNS -.-> AppAzure
```

## Notes For Drawing This Manually

1. Draw GitHub and GitHub Actions on the left.
2. Draw two large boxes: `AWS primary` and `Azure warm standby`.
3. Inside AWS, include EKS, ECR, RDS, ElastiCache, Secrets Manager, VPN Gateway, and security/observability controllers.
4. Inside Azure, include AKS, ACR, Azure PostgreSQL, Key Vault, and Virtual Network Gateway.
5. Connect AWS VPN Gateway to Azure Virtual Network Gateway with `IPsec VPN + BGP`.
6. Connect AWS RDS to Azure PostgreSQL with `native logical replication`.
7. Put Route53 DNS failover as dashed/optional unless a hosted zone is actually configured.
