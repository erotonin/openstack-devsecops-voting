# Verified Demo Runbook

This runbook is written for the final capstone recording. It uses commands that were checked against the current repository and cluster state.

Do not reveal secret values during recording. If a command prints a secret, do not run it on camera.

## 0. Prepare The Terminal

```powershell
cd C:\Users\Admin\Desktop\Devops\DevSecOps-Voting-App
git status --short
git log --oneline -5
```

Expected:

- `git status --short` is empty before you start demo changes.
- Recent commits include CI/GitOps and replication work.

If you create a demo branch later, return to main after the demo:

```powershell
git checkout main
git pull --ff-only
```

## 1. Explain The Pipeline Diagram

The attached pipeline image is mostly correct. Use this corrected explanation:

- Pre-commit runs locally before code leaves the developer machine.
- PR security gates run on pull requests: Gitleaks, Semgrep, Checkov, tfsec, Trivy filesystem scan, Helm template/lint, and Conftest.
- Merge to `main` triggers build for `vote`, `result`, and `worker`.
- CI builds Docker images, scans them with Trivy, generates SBOM with Syft, pushes to ECR/ACR, and signs by digest with Cosign.
- DAST runs OWASP ZAP against `STAGING_URL`.
- CI opens a GitOps promotion PR that updates Helm values with image tags and digests.
- ArgoCD pulls Git changes and deploys to Kubernetes.
- AWS EKS enforces signed ECR images with Sigstore policy-controller.
- Falco detects runtime behavior and opens incident/response workflows.

Two corrections to the image:

- The SBOM step is Syft, not Anchore Engine. It is fine to label the logo as `Syft SBOM`.
- Kyverno verify-image is not the main AWS enforcement path. AWS uses Sigstore policy-controller. Kyverno on Azure is disabled by default because private ACR verification requires additional registry credentials.

## 2. Show Cloud Architecture

Open:

```text
docs/cloud-architecture.svg
docs/cloud-architecture.md
```

Talk track:

- AWS is the hot primary site.
- Azure is the warm standby site.
- The two clouds are connected with IPsec VPN and BGP.
- AWS RDS publishes PostgreSQL WAL deltas through logical replication.
- Azure PostgreSQL subscribes to the publication.
- Route53 failover is script-ready but needs a real hosted zone/domain.

## 3. Verify Infrastructure State

```powershell
terraform -chdir=terraform/environments/aws validate -no-color
terraform -chdir=terraform/environments/azure validate -no-color
```

Expected:

```text
Success! The configuration is valid.
```

Check Terraform drift without refreshing every cloud object:

```powershell
terraform -chdir=terraform/environments/aws plan -refresh=false -no-color -detailed-exitcode
terraform -chdir=terraform/environments/azure plan -refresh=false -no-color -detailed-exitcode
```

Expected:

```text
No changes. Your infrastructure matches the configuration.
```

Exit code `0` means no diff. Exit code `2` means Terraform found changes; pause and inspect before demo.

## 4. Verify AWS Primary Application

```powershell
$awsCtx = "arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster"
kubectl --context $awsCtx -n argocd get application voting-aws
kubectl --context $awsCtx -n voting get deploy,pods,svc,externalsecret
```

Expected:

- `voting-aws` shows `Synced` and `Healthy`.
- `vote`, `result`, and `worker` deployments are ready.
- `voting-app-runtime` ExternalSecret is `SecretSynced`.

Health endpoint:

```powershell
$voteHost = kubectl --context $awsCtx -n voting get svc vote -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
Invoke-WebRequest -UseBasicParsing "http://$voteHost/healthz" | Select-Object StatusCode,Content
```

Expected:

```text
StatusCode: 200
Content: {"service":"vote","status":"ok"}
```

Revert:

- No revert needed; these are read-only checks.

## 5. Verify Azure Warm Standby

```powershell
$azCtx = "devsecops-voting-aks"
kubectl --context $azCtx -n argocd get application voting-azure
kubectl --context $azCtx -n voting get deploy,pods,svc,externalsecret
```

Expected after the current fix:

- `voting-azure` should become `Synced Healthy`.
- App pods should be running.
- The vote service should have an external IP or be reachable by port-forward.
- The result service is intentionally `ClusterIP` on Azure to avoid student subscription public IP quota. Use port-forward if you need to open it.

Port-forward fallback:

```powershell
kubectl --context $azCtx -n voting port-forward svc/vote 8080:80
```

Open:

```text
http://localhost:8080/healthz
```

Expected:

```text
{"service":"vote","status":"ok"}
```

Revert:

- Stop port-forward with `Ctrl+C`.

## 6. Verify PostgreSQL Logical Replication

AWS publisher check:

```powershell
$awsCtx = "arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster"
$pod = "psql-repl-check"
$secretRaw = (aws secretsmanager get-secret-value --region us-east-1 --secret-id devsecops-voting/db | ConvertFrom-Json).SecretString
$secret = $secretRaw | ConvertFrom-Json
$dbPass = $secret.password
kubectl --context $awsCtx -n default delete pod $pod --ignore-not-found=true --wait=false
@'
apiVersion: v1
kind: Pod
metadata:
  name: psql-repl-check
  namespace: default
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: psql-repl-check
      image: postgres:15-alpine
      command: ["sleep", "300"]
      securityContext:
        runAsUser: 70
        runAsGroup: 70
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
'@ | kubectl --context $awsCtx apply -f -
kubectl --context $awsCtx -n default wait --for=condition=Ready pod/$pod --timeout=90s
kubectl --context $awsCtx -n default exec $pod -- env PGPASSWORD=$dbPass psql -h devsecops-voting-postgres.co9qq4o8ek6z.us-east-1.rds.amazonaws.com -U postgres -d voting -tAc "select slot_name, active, plugin from pg_replication_slots;"
kubectl --context $awsCtx -n default delete pod $pod --wait=false
```

Expected:

```text
voting_aws_sub|t|pgoutput
```

Azure subscriber check:

```powershell
$azCtx = "devsecops-voting-aks"
$runtimeJson = az keyvault secret show --vault-name devsecopsvotingkv --name voting-app-runtime --query value -o tsv
$runtime = $runtimeJson | ConvertFrom-Json
$pod = "psql-azure-repl-check"
kubectl --context $azCtx -n default delete pod $pod --ignore-not-found=true --wait=false
@'
apiVersion: v1
kind: Pod
metadata:
  name: psql-azure-repl-check
  namespace: default
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: psql-azure-repl-check
      image: postgres:15-alpine
      command: ["sleep", "300"]
      securityContext:
        runAsUser: 70
        runAsGroup: 70
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
'@ | kubectl --context $azCtx apply -f -
kubectl --context $azCtx -n default wait --for=condition=Ready pod/$pod --timeout=120s
kubectl --context $azCtx -n default exec $pod -- env PGPASSWORD=$($runtime.DB_PASSWORD) psql -h $($runtime.DB_HOST) -U $($runtime.DB_USER) -d $($runtime.DB_NAME) -tAc "select subname, subenabled from pg_subscription; select subname, received_lsn is not null as receiving, latest_end_lsn is not null as replayed from pg_stat_subscription;"
kubectl --context $azCtx -n default delete pod $pod --wait=false
```

Expected:

```text
voting_aws_sub|t
voting_aws_sub|t|t
```

Revert:

- The temporary pods are deleted at the end.
- If interrupted, clean up:

```powershell
kubectl --context $awsCtx -n default delete pod psql-repl-check --ignore-not-found=true
kubectl --context $azCtx -n default delete pod psql-azure-repl-check --ignore-not-found=true
```

## 7. Demo Pre-Commit

Install hook once:

```powershell
pre-commit install
```

Run lightweight hooks against the current tree:

```powershell
pre-commit run trailing-whitespace --all-files
pre-commit run check-yaml --all-files
pre-commit run gitleaks --all-files
```

Expected:

```text
Passed
```

Full run:

```powershell
pre-commit run --all-files
```

Expected:

- Hooks pass.
- On Windows, optional CLI wrappers may print skip messages for tools that are not installed locally. This is acceptable for the local demo because GitHub Actions enforces Semgrep, Checkov, tfsec, Trivy, Helm, and Conftest.
- If Terraform validate says an environment is not initialized, run:

```powershell
terraform -chdir=terraform/environments/aws init
terraform -chdir=terraform/environments/azure init
```

Revert:

- If pre-commit auto-formats files during demo and you do not want to keep them:

```powershell
git diff
git restore <file>
```

## 8. Demo PR Security Gate

Create a harmless docs-only branch:

```powershell
git checkout -b demo/pr-security-gate
Add-Content docs/demo-pr-note.md "PR security gate demo"
git add docs/demo-pr-note.md
git commit -m "docs: add pr security gate demo"
git push -u origin demo/pr-security-gate
```

Open a PR to `main` on GitHub.

Expected:

- `PR security gates` runs and passes.
- `ZAP baseline scan` runs if `STAGING_URL` is configured.
- Merge may be blocked by review requirement.

Revert:

```powershell
git checkout main
git branch -D demo/pr-security-gate
git push origin --delete demo/pr-security-gate
```

Close the PR in GitHub without merging.

## 9. Demo Admission Policy Rejects

```powershell
.\scripts\test-policy-rejects.ps1 -Context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster
```

Expected:

- `deny-latest.yaml denied as expected`
- `deny-privileged.yaml denied as expected`
- `deny-missing-resources.yaml denied as expected`

Reason:

- Gatekeeper and Sigstore admission stop unsafe manifests before they become running pods.

Revert:

- No revert needed; the script uses server-side dry-run.

## 10. Demo ArgoCD

```powershell
.\scripts\open-argocd.ps1
```

Open:

```text
http://localhost:8080
```

Expected:

- `voting-aws` is `Synced Healthy`.
- SSO/OIDC config is visible in ArgoCD config.

Revert:

- Stop port-forward with `Ctrl+C`.

## 11. Demo Grafana

```powershell
.\scripts\open-grafana.ps1
```

Open:

```text
http://localhost:3000
```

Expected:

- Grafana login appears.
- Use the printed admin password.
- Open the voting SLI/SLO dashboard.

Reason:

- Grafana is `ClusterIP`, intentionally not public. `kubectl port-forward` creates a local tunnel only for the demo.

Revert:

- Stop port-forward with `Ctrl+C`.

## 12. Demo Runtime Incident

Trigger a manual incident issue:

```powershell
gh workflow run runtime-incident.yml `
  -f severity=warning `
  -f title="Demo Falco runtime alert" `
  -f namespace=voting `
  -f pod=demo-pod `
  -f details="Demo alert for capstone recording"
```

Expected:

- GitHub Actions workflow runs.
- A GitHub issue is created with labels `incident` and `runtime-security`.

Revert:

- Close the demo issue after recording.

Optional quarantine demo:

- Only run this against a known disposable pod.
- Do not quarantine a live production pod during the main demo unless you are intentionally demonstrating containment.

## 13. Demo DR Failover

```powershell
.\scripts\dr-failover.ps1 -SkipScale
```

Expected:

- AKS credentials are loaded.
- ArgoCD `voting-azure` refreshes.
- `vote`, `result`, and `worker` rollouts become ready if Azure sync is healthy.
- Script prints RTO.

Revert:

- This command does not switch real DNS.
- If port-forward was opened, stop it with `Ctrl+C`.
- To return to AWS primary in the story, show AWS app remains `Synced Healthy`.

## 14. Production Approval Gate

```powershell
.\scripts\run-production-approval.ps1
```

Expected:

- A `workflow_dispatch` run starts.
- GitHub Environment `production` requires approval if configured.
- After approval, job prints that promotion is approved.

Revert:

- No infra change is made by this workflow. It demonstrates the approval boundary.

## 15. Cleanup After Recording

Only run this when the demo is finished:

```powershell
.\destroy.ps1 -AutoApprove
```

Expected:

- Kubernetes cleanup runs.
- Terraform destroys Azure and AWS resources.
- ECR images and project Secrets Manager secrets are cleaned up.

Post-destroy checks:

```powershell
aws eks list-clusters --region us-east-1
aws rds describe-db-instances --region us-east-1 --query "DBInstances[].DBInstanceIdentifier"
aws elasticache describe-replication-groups --region us-east-1 --query "ReplicationGroups[].ReplicationGroupId"
az aks list -o table
az network vnet-gateway list -o table
```

Expected:

- No expensive demo resources remain.
