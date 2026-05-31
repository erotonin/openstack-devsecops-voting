# Full Pipeline Voi Framework Va Tool Cu The

File nay trinh bay implementation cu the cua kien truc DevSecOps. Neu `docs/architecture-conceptual.md` noi ve ban chat, file nay noi ro framework, tool va moi truong dang dung.

## 1. Source Control Va Branch Model

| Thanh phan | Framework / tool | Vai tro |
| --- | --- | --- |
| Repository | GitHub | Luu source code, IaC, Helm chart, workflow, scripts va docs |
| Branch feature | Git branch | Noi developer lam tung thay doi rieng |
| Pull request | GitHub Pull Request | Review code va kich hoat security gate |
| Integration branch | `dev` | Gom feature da pass gate de kiem tra tong hop |
| Release branch | `main` | Nguon release va desired state production |
| Branch protection | GitHub branch protection | Bat required checks va approving review |

Hien tai:

- `dev` yeu cau check `Feature PR light security gates` va 1 review.
- `main` yeu cau check `Release PR full security gates` va 1 review.

## 2. Feature PR Gate

Khi developer tao PR vao `dev`, GitHub Actions chay fast gate.

| Muc kiem tra | Tool / framework | Muc dich |
| --- | --- | --- |
| Secret scanning | Gitleaks | Chan token, password, private key bi hardcode |
| Static application security | Semgrep | Bat bug va mau code co lo hong |
| SCA / dependency scan | Trivy FS, npm audit | Quet CVE trong dependency manifest/lockfile va third-party libraries |
| Code quality | SonarCloud | Phat hien bug, smell, duplication |
| Local hygiene | pre-commit | Chuan hoa format, newline, whitespace, secret check |

Ket qua dung: PR feature chi duoc merge vao `dev` khi gate nhanh pass va co review.

## 3. Integration Gate Tren `dev`

Sau khi merge vao `dev`, pipeline chay bo kiem tra rong hon.

| Muc kiem tra | Tool / framework | Muc dich |
| --- | --- | --- |
| Secret scanning | Gitleaks | Dam bao `dev` khong chua secret |
| SAST | Semgrep | Quet loi code theo rule bao mat |
| IaC security | Checkov, tfsec | Kiem tra Terraform AWS/Azure |
| SCA / filesystem scan | Trivy FS | Kiem tra dependency manifest, lockfile, filesystem va config |
| Kubernetes manifest | Helm lint, Helm template | Dam bao chart render hop le |
| Policy as code | Conftest/OPA | Chan manifest vi pham policy |

Ket qua dung: `dev` tro thanh release candidate sach hon, co the tao PR sang `main`.

## 4. Release PR Gate Vao `main`

Khi tao PR `dev -> main`, GitHub Actions chay `Release PR full security gates`.

| Muc kiem tra | Tool / framework | Muc dich |
| --- | --- | --- |
| Secret | Gitleaks | Khong cho secret vao release branch |
| SAST | Semgrep | Chan loi bao mat trong code |
| IaC | Checkov, tfsec | Chan cau hinh cloud nguy hiem |
| K8s/Helm | Helm lint/template | Dam bao manifest render duoc cho staging/prod/Azure |
| Policy | Conftest | Dam bao manifest hop policy |

Ket qua dung: PR vao `main` chi merge khi full gate pass va co review.

Ghi chu: Trivy FS va `npm audit` la source-level SCA. Chung bat CVE trong dependency manifest/lockfile som o PR/integration/release gate. Trivy image scan o buoc artifact la lop khac, dung de quet image that sau khi build, bao gom base image va package da cai trong container.

## 5. Build, SBOM, Signing Va Scan Image

Khi code vao `main`, GitHub Actions build ba service:

- `vote`: Python/Flask.
- `result`: Node.js/Express.
- `worker`: .NET/C#.

Pipeline build container image bang Docker va day len:

- AWS ECR cho AWS EKS.
- Azure ACR cho Azure AKS.

| Buoc | Tool / framework | Ket qua |
| --- | --- | --- |
| Build image | Docker | Tao image cho `vote`, `result`, `worker` |
| Generate SBOM | Syft | Tao SBOM SPDX cho image |
| Sign image | Cosign keyless | Ky image digest bang GitHub OIDC/Fulcio/Rekor |
| Verify signature | Cosign + policy script | Xac minh identity, issuer, Rekor bundle/certificate |
| Image CVE scan | Trivy image | Chan image co CVE nghiem trong |

Ket qua dung: chi image da co SBOM, da ky, da verify va scan pass moi duoc dung cho staging.

## 6. Staging Deployment Va DAST

| Thanh phan | Framework / tool | Gia tri hien tai |
| --- | --- | --- |
| GitOps branch | Git branch `staging` | Luu desired state staging |
| Deployment engine | ArgoCD | Sync tu Git vao EKS |
| Cluster | AWS EKS | Primary Kubernetes cluster |
| Namespace | `voting-staging` | Moi truong staging |
| Helm values | `k8s/values-staging.yaml` | Cau hinh staging |
| Smoke test | HTTP `/healthz` | Xac nhan app song |
| DAST | OWASP ZAP baseline | Quet web app khi dang chay |

Ket qua dung:

- ArgoCD app `voting-staging` `Synced Healthy`.
- `/healthz` staging HTTP 200.
- OWASP ZAP baseline pass.

## 7. Production Promotion

Neu staging va DAST pass, pipeline tao promotion PR cap nhat:

- `k8s/values-prod.yaml`
- `k8s/values-azure.yaml`

Promotion PR thay doi image digest cua production/Azure sang digest da duoc build, sign, verify va test o staging.

| Thanh phan | Framework / tool | Vai tro |
| --- | --- | --- |
| Promotion PR | GitHub Pull Request | Review thay doi desired state production |
| GitOps desired state | Helm values | Ghi image digest production/Azure |
| Required gate | Release PR full security gates | Kiem tra promotion PR truoc merge |

## 8. Production Va Azure Deployment

| Moi truong | Cloud | Cluster | ArgoCD app | Namespace | Helm values |
| --- | --- | --- | --- | --- | --- |
| AWS staging | AWS | EKS | `voting-staging` | `voting-staging` | `k8s/values-staging.yaml` |
| AWS production | AWS | EKS | `voting-production` | `voting-production` | `k8s/values-prod.yaml` |
| Azure warm standby | Azure | AKS | `voting-azure` | `voting` | `k8s/values-azure.yaml` |

Ket qua dung:

- `voting-production` `Synced Healthy`.
- `voting-azure` `Synced Healthy`.
- `/healthz` production va Azure HTTP 200.

## 9. Runtime Security

| Lop bao ve | Framework / tool | Muc dich |
| --- | --- | --- |
| Image admission | Sigstore policy-controller | Chi chap nhan image co chu ky hop le |
| Policy as code | Gatekeeper/OPA | Chan workload/cau hinh vi pham policy |
| Secret sync | External Secrets Operator | Lay secret tu secret manager, khong hardcode trong manifest |
| AWS secrets | AWS Secrets Manager | Luu secret phia AWS |
| Azure secrets | Azure Key Vault | Luu secret phia Azure |
| Monitoring | Prometheus, Grafana | Metric va dashboard |
| Logging | Loki, Promtail | Tap trung log |
| Runtime detection | Falco | Phat hien hanh vi bat thuong trong cluster |

## 10. Infrastructure Va Multi-Cloud

| Thanh phan | Framework / tool | Vai tro |
| --- | --- | --- |
| IaC | Terraform | Tao va quan ly AWS/Azure infrastructure |
| AWS compute | EKS | Kubernetes primary |
| Azure compute | AKS | Kubernetes warm standby |
| AWS database | RDS PostgreSQL | Primary database |
| Azure database | Azure PostgreSQL | Logical subscriber |
| AWS cache | ElastiCache Redis | Cache/queue primary |
| Azure standby cache | In-cluster Redis | Standby cost-aware |
| Network DR | AWS VPN Gateway, Azure VNet Gateway, BGP | Ket noi hai cloud |
| Failover | Route53 failover script | Chuyen traffic khi primary loi |

## 11. Evidence Gan Nhat

| Evidence | Trang thai |
| --- | --- |
| Main release run `26565822002` | Success |
| Promotion GitOps run `26566117530` | Success |
| PR tai lieu `#73` | Merged |
| Promotion PR `#74` | Merged |
| AWS `voting-staging` | Synced Healthy |
| AWS `voting-production` | Synced Healthy |
| Azure `voting-azure` | Synced Healthy |
| Staging `/healthz` | HTTP 200 |
| Production `/healthz` | HTTP 200 |
| Azure `/healthz` | HTTP 200 |
