# Teacher-Aligned Demo Runbook

Runbook này dùng để quay demo theo đúng nhận xét của thầy: trình bày phase, target, kết quả, failure path, audit và recovery. Không demo theo kiểu đọc tên tool từ trái sang phải.

## 0. Preflight

```powershell
git status --short
gh auth status
aws sts get-caller-identity
az account show --output table
kubectl config get-contexts
```

Expected:

- Git không có thay đổi bất ngờ ngoài commit demo đang chuẩn bị.
- GitHub CLI đã login đúng account.
- AWS account là `800557027783`.
- Azure subscription là `007e5e26-e0d0-4389-9cde-5731cdb86639`.

## 1. Mở Đầu Bằng Logic Pipeline

Nói ngắn:

```text
Em không thiết kế pipeline theo danh sách tool. Em thiết kế theo vòng DevSecOps:
Plan -> Code -> Build -> Test -> Release -> Deploy -> Operate -> Monitor.
Mỗi phase có một target kiểm tra riêng, tool chỉ là cách triển khai target đó.
```

Mở file:

```powershell
code docs/devsecops-phase-model.md
```

Điểm cần nói:

- Feature nhỏ vào `dev` chỉ chạy fast feedback.
- Sau khi nhiều feature merge vào `dev`, phải integration scan lại vì unit đúng chưa chắc tổng thể đúng.
- PR `dev -> main` là release candidate, phải full gate trước khi build.
- DAST chỉ chạy sau staging healthy.
- Production không deploy trực tiếp từ build job; production đi qua GitOps promotion PR.

## 2. Demo Branch/Approval Boundary

```powershell
gh api /repos/erotonin/devsecops-voting/branches/dev/protection --jq ".required_status_checks.contexts"
gh api /repos/erotonin/devsecops-voting/branches/main/protection --jq ".required_status_checks.contexts"
```

Expected:

```text
dev  -> Feature PR light security gates
main -> Release PR full security gates
```

Giải thích:

```text
dev là integration branch. main là release branch. Production chỉ thay đổi khi main nhận GitOps promotion PR đã review.
```

## 3. Demo Static Gates

Local smoke cho Helm/config:

```powershell
helm lint k8s
helm template voting-app k8s -f k8s/values-staging.yaml > $env:TEMP\voting-staging.yaml
helm template voting-app k8s -f k8s/values-prod.yaml > $env:TEMP\voting-prod.yaml
helm template voting-app k8s -f k8s/values-azure.yaml > $env:TEMP\voting-azure.yaml
```

Expected:

```text
1 chart(s) linted, 0 chart(s) failed
```

Nếu có Conftest:

```powershell
conftest test --policy policies/conftest $env:TEMP\voting-staging.yaml
conftest test --policy policies/conftest $env:TEMP\voting-prod.yaml
conftest test --policy policies/conftest $env:TEMP\voting-azure.yaml
```

Expected:

```text
0 tests, 0 failures
```

Giải thích:

```text
Helm render kiểm tra deploy config có render được thành Kubernetes YAML hợp lệ.
Conftest kiểm tra policy tổ chức trên YAML đã render.
Hai bước này thuộc kiểm tra static config, không phải DAST.
```

## 4. Demo Supply Chain: Sign, Verify, Crypto Policy

Mở workflow:

```powershell
code .github/workflows/ci-pipeline.yml
code scripts/verify-cosign-signature-policy.sh
```

Nói:

```text
Sau khi build, image được push để có immutable digest.
CI ký digest bằng Cosign keyless qua GitHub OIDC.
Sau đó CI verify certificate identity và chạy crypto policy check.
Nếu certificate dùng sha1/md5 hoặc RSA key quá yếu thì fail trước khi scan/promote.
```

Expected trong GitHub Actions:

```text
Cosign keyless sign ECR digest
Verify ECR signature identity and crypto policy
Cosign signature crypto policy passed
Trivy image scan after signature verification
```

## 5. Demo Staging Deploy Và DAST

Sau khi CI main pass và staging branch được cập nhật:

```powershell
$ctx = "arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster"
kubectl --context $ctx -n argocd get application voting-staging
kubectl --context $ctx -n voting-staging get deploy,pods,svc,externalsecret
```

Expected:

```text
voting-staging   Synced   Healthy
deploy/vote      Available
deploy/result    Available
deploy/worker    Available
externalsecret/voting-app-runtime SecretSynced True
```

Health check:

```powershell
$voteHost = kubectl --context $ctx -n voting-staging get svc vote -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
Invoke-WebRequest -UseBasicParsing "http://$voteHost/healthz"
```

Expected:

```text
StatusCode: 200
```

Giải thích:

```text
Smoke test chỉ chứng minh app sống và route được.
ZAP DAST chạy sau đó vì nó cần endpoint thật để gửi request giống attacker.
```

## 6. Demo Production Promotion

Mở PR do CI tạo:

```powershell
gh pr list --label gitops --label promotion
```

Expected:

```text
chore: promote images for <sha>
```

Nói:

```text
PR này chỉ đổi desired state production: image tag/digest trong values-prod và values-azure.
Production deploy xảy ra khi PR được review và merge vào main.
```

Sau khi merge PR:

```powershell
kubectl --context $ctx -n argocd get application voting-production
kubectl --context $ctx -n voting-production get deploy,pods,svc
```

Expected:

```text
voting-production   Synced   Healthy
pods                Running
```

## 7. Demo Admission Policy Reject

```powershell
.\scripts\test-policy-rejects.ps1 -Context $ctx -Namespace voting-staging
```

Expected:

```text
deny-latest.yaml denied as expected.
deny-privileged.yaml denied as expected.
deny-missing-resources.yaml denied as expected.
```

Giải thích:

```text
Đây là policy gate ở Kubernetes admission layer. Nếu CI lọt lỗi config thì cluster vẫn có lớp chặn cuối.
```

## 8. Demo Runtime Detect/Respond

Tạo Falco alert trong staging:

```powershell
$pod = kubectl --context $ctx -n voting-staging get pod -l app=vote -o jsonpath="{.items[0].metadata.name}"
kubectl --context $ctx -n voting-staging exec $pod -- sh -c "id"
kubectl --context $ctx -n falco logs -l app.kubernetes.io/name=falco -c falco --tail=200 | Select-String "Shell Spawned"
```

Expected:

```text
Shell Spawned In Voting Namespace
```

Manual incident issue if webhook is not configured:

```powershell
gh workflow run runtime-incident.yml `
  -f severity=warning `
  -f title="Falco shell detected in staging pod" `
  -f namespace=voting-staging `
  -f pod=$pod `
  -f details="Demo alert generated by kubectl exec"
```

Optional quarantine, only if you want to demo response:

```powershell
gh workflow run quarantine-pod.yml `
  -f namespace=voting-staging `
  -f pod_name=$pod
```

Expected:

```text
Workflow waits for security-response environment approval.
After approval, pod gets label security.devsecops/quarantine=true and NetworkPolicy blocks egress.
```

Revert quarantine:

```powershell
kubectl --context $ctx -n voting-staging label pod $pod security.devsecops/quarantine-
kubectl --context $ctx -n voting-staging delete networkpolicy quarantine-deny-egress --ignore-not-found
```

## 9. Demo Observability/Audit

```powershell
kubectl --context $ctx -n argocd get application voting-staging voting-production -o wide
kubectl --context $ctx -n voting-staging get events --sort-by=.lastTimestamp
kubectl --context $ctx -n monitoring get pods
kubectl --context $ctx -n logging get pods
```

Nói:

```text
Audit deploy gồm Git PR, GitHub Actions run, Cosign cert identity, ArgoCD sync history,
Kubernetes events, CloudTrail/EKS audit logs, Loki/Falco runtime logs.
```

## 10. DR/Warm Standby Demo

```powershell
.\scripts\dr-failover.ps1 -SkipScale
```

Expected:

```text
DR drill workload recovery completed
RTO: <number> minutes
```

Nếu Azure public IP quota gây hạn chế, demo bằng port-forward:

```powershell
kubectl --context devsecops-voting-aks -n voting-production port-forward svc/vote 8080:80
```

Open:

```text
http://localhost:8080
```
