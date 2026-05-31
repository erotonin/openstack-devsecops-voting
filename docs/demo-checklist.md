# Demo Can Trinh Bay Nhung Gi

Tai lieu nay la checklist de quay hoac trinh bay demo. Muc tieu la chung minh ban chat he thong, khong chi mo tung tool len cho thay xem.

## 1. Mo Dau: Noi Kien Truc Trong 1 Phut

Noi ngan gon:

```text
Do an cua em la mot DevSecOps platform cho voting app. Developer khong deploy truc tiep len production. Moi thay doi di qua repository, pull request, security gate, build artifact, signing, staging test, promotion PR va GitOps deployment. AWS la primary site, Azure la warm standby site. Sau khi deploy, cluster van co runtime policy, secret management, monitoring va DR.
```

Can mo:

- `docs/architecture-conceptual.md`
- `docs/devsecops-pipeline-diagram.md`
- So do tong the trong file do neu can.

## 2. Demo Repository Va Branch Boundary

Muc tieu: chung minh code di qua pull request va branch protection.

Can demo:

- Repository co source code, IaC, Helm, workflow, docs.
- Branch `dev` la integration branch.
- Branch `main` la release/production desired state.
- `dev` va `main` co required checks va review.

Lenh:

```powershell
gh api /repos/erotonin/devsecops-voting/branches/dev/protection --jq ".required_status_checks.contexts"
gh api /repos/erotonin/devsecops-voting/branches/main/protection --jq ".required_status_checks.contexts"
```

## 3. Demo PR Security Gate

Muc tieu: chung minh code moi khong duoc merge neu chua qua kiem tra.

Can demo:

- Mo mot PR da pass gate gan day.
- Chi vao required check.
- Giai thich gate so bo gom secret scanning, SAST, dependency/config scan.

Noi voi thay:

```text
O buoc nay em muon bat loi som. Vi du secret hardcode phai bi chan ngay khi tao PR, khong doi den luc deploy.
```

## 4. Demo Release Pipeline

Muc tieu: chung minh full pipeline tu `main` build ra artifact that.

Can demo GitHub Actions run:

- Main release run `26565822002`.
- Cac job build `vote`, `result`, `worker`.
- SBOM artifact.
- Cosign signing va verification.
- Trivy image scan.
- Deploy staging.
- DAST staging.
- Open promotion PR.

Noi voi thay:

```text
Sau khi vao `dev`, pipeline tao artifact. Image duoc build, sinh SBOM, ky so, verify chu ky va scan CVE. Artifact nao khong qua cac buoc nay thi khong duoc dua vao staging.
```

## 5. Demo Staging Va DAST

Muc tieu: chung minh ung dung da chay that truoc khi promotion.

Can demo:

- ArgoCD app `voting-staging` la `Synced Healthy`.
- Endpoint `/healthz` staging HTTP 200.
- OWASP ZAP baseline pass.

Lenh:

```powershell
kubectl --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster `
  -n argocd get applications.argoproj.io voting-staging

$h=(kubectl --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster `
  -n voting-staging get svc vote -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
Invoke-WebRequest -UseBasicParsing -Uri "http://$h/healthz"
```

## 6. Demo Promotion PR

Muc tieu: chung minh production khong deploy truc tiep.

Can demo:

- Promotion PR `#74`.
- File thay doi: `k8s/values-prod.yaml`, `k8s/values-azure.yaml`.
- Noi dung thay doi la image digest production/Azure.

Lenh:

```powershell
gh pr view 74 --json url,state,mergedAt,mergeCommit
gh pr diff 74 --name-only
```

Noi voi thay:

```text
CI khong day thang len production. CI chi tao PR thay doi desired state. Khi PR nay merge, ArgoCD moi dong bo production tu Git.
```

## 7. Demo Production Va Azure Warm Standby

Muc tieu: chung minh release da vao hai moi truong.

Can demo:

- AWS production `Synced Healthy`.
- Azure warm standby `Synced Healthy`.
- Pod production/Azure running.
- `/healthz` cua production va Azure HTTP 200.

Lenh:

```powershell
kubectl --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster `
  -n argocd get applications.argoproj.io voting-production

kubectl --context devsecops-voting-aks `
  -n argocd get applications.argoproj.io voting-azure

$prod=(kubectl --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster `
  -n voting-production get svc vote -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
Invoke-WebRequest -UseBasicParsing -Uri "http://$prod/healthz"

$az=(kubectl --context devsecops-voting-aks `
  -n voting get svc vote -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
Invoke-WebRequest -UseBasicParsing -Uri "http://$az/healthz"
```

## 8. Demo Runtime Security

Muc tieu: chung minh bao mat khong dung lai o CI/CD.

Can demo:

- Policy admission trong cluster.
- External Secrets Operator.
- Monitoring/logging/runtime detection neu can.

Lenh goi y:

```powershell
kubectl --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster get clusterimagepolicy
kubectl --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster get constrainttemplates
kubectl --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster get externalsecrets -A
kubectl --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster -n monitoring get pods
kubectl --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster -n logging get pods
kubectl --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster -n falco get pods
.\scripts\test-policy-rejects.ps1 -Context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster -Namespace voting-staging
```

Ghi chu: trong namespace co Sigstore policy, mot so manifest xau co the bi policy-controller chan truoc Gatekeeper. Diem can noi la admission layer da reject workload khong hop policy.

## 9. Demo DR Neu Co Thoi Gian

Muc tieu: chung minh co ke hoach recover.

Can demo:

- So do AWS primary va Azure standby.
- VPN/BGP giua hai cloud.
- PostgreSQL logical replication.
- Script failover/Route53 neu co hosted zone.

Lenh an toan de demo warm standby ma khong scale lai node pool:

```powershell
.\scripts\dr-failover.ps1 -SkipScale
```

Noi voi thay:

```text
DR khong chi la co them mot cluster. No can network path, data replication va cach chuyen traffic. Trong do an nay AWS la primary, Azure la warm standby.
```

## 10. Thu Tu Demo De Khong Bi Roi

1. Mo `docs/architecture-conceptual.md` va noi ban chat kien truc.
2. Mo `docs/devsecops-pipeline-diagram.md` de nguoi xem nhin duoc toan bo pipeline.
3. Mo GitHub branch protection de chung minh boundary.
4. Mo PR/check de chung minh gate.
5. Mo Actions run `26565822002` de chung minh build/sign/scan/staging/DAST.
6. Mo promotion PR `#74` de chung minh production qua GitOps.
7. Mo terminal kiem tra ArgoCD AWS/Azure `Synced Healthy`.
8. Goi `/healthz` staging, production, Azure.
9. Neu con thoi gian, noi runtime security va DR.

## 11. Cau Tra Loi Nhanh Khi Thay Hoi

**Tai sao khong deploy thang tu CI vao production?**

Vi production can audit va rollback ro rang. Neu deploy bang GitOps, moi thay doi production la mot commit/PR trong Git.

**Tai sao can staging?**

Vi nhieu loi chi xuat hien khi app chay that voi service, secret, network va database.

**Tai sao can SBOM va signing?**

SBOM cho biet image gom thanh phan nao. Signing chung minh image do do pipeline hop le tao ra va chua bi thay the.

**Tai sao can Azure neu da co AWS?**

AWS la primary. Azure la warm standby de co duong recover khi primary site gap su co.

**Tool nao quan trong nhat?**

Khong co mot tool quan trong nhat. Quan trong la cac lop kiem soat: source control, security gate, artifact integrity, GitOps deployment, runtime policy va recovery.
