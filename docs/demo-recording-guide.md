# Final Demo Recording Guide

This guide is the step-by-step video plan for the capstone demo. Record it in this order so the story is clear: architecture first, then provisioning, CI/CD, GitOps, security, observability, runtime response, DR, and cleanup.

Target length: 25-35 minutes.

## Before recording

Open these tabs and terminals first:

- GitHub repository: `https://github.com/erotonin/devsecops-voting`
- GitHub Actions: `https://github.com/erotonin/devsecops-voting/actions`
- GitHub Pull Requests: `https://github.com/erotonin/devsecops-voting/pulls`
- AWS console: EKS, VPC, VPN, RDS, ElastiCache, ECR.
- Azure portal: AKS, Virtual Network Gateway, ACR, Key Vault.
- PowerShell at repo root:

```powershell
cd C:\Users\Admin\Desktop\Devops\DevSecOps-Voting-App
```

Run one final health check before pressing record:

```powershell
.\scripts\verify-stack.ps1
```

If you destroyed infrastructure, recreate it before recording:

```powershell
.\scripts\infra-up.ps1 -AutoApprove
.\scripts\verify-stack.ps1
```

## Important note about main branch protection

The production workflow is not "push directly to main". The intended flow is:

1. Developer opens a feature branch.
2. Pull request runs `PR security gates`.
3. At least one review is required.
4. Merge to `main` triggers build, scan, SBOM, signing, push, DAST.
5. Production promotion uses manual approval.

If the repository owner can still push directly to `main`, that means GitHub allows admin/owner bypass. For the demo, show branch protection and explain that production should disable bypass for administrators. Re-run this after installing GitHub CLI if needed:

```powershell
.\scripts\configure-github-repo.ps1 `
  -StagingUrl "<AWS vote load balancer URL>" `
  -ConfigureBranchProtection
```

Then check in GitHub:

- Settings -> Branches -> `main`
- Required PR review: enabled.
- Required status check: `PR security gates`.
- Enforce for administrators: enabled.

If GitHub still shows "bypass rules", say clearly: "This owner account can bypass for demo administration; real production disables bypass."

## Part 1 - Project goal and architecture

Show:

- [docs/scope-lock.md](./scope-lock.md)
- [docs/implementation-map.md](./implementation-map.md)
- architecture diagram if available in the repo or report.

Say:

- "This is a multi-cloud DevSecOps voting application."
- "AWS is the active primary site; Azure is warm standby."
- "Infrastructure is provisioned by Terraform."
- "AWS and Azure are connected by route-based IPSec VPN with BGP."
- "Application delivery is GitOps through ArgoCD."
- "CI/CD uses GitHub Actions OIDC, so no static AWS or Azure cloud keys are stored in GitHub."

Quick command:

```powershell
git log --oneline -5
```

Expected evidence:

- Recent commits show normal engineering changes, for example `fix:`, `feat:`, `chore:`.

## Part 2 - Cloud infrastructure evidence

Show AWS resources:

- EKS cluster `voting-app-cluster`.
- VPC and subnets.
- Site-to-site VPN connection.
- RDS PostgreSQL.
- ElastiCache Redis.
- ECR repositories.

Show Azure resources:

- AKS cluster `devsecops-voting-aks`.
- Virtual Network Gateway.
- ACR.
- Key Vault.

Run:

```powershell
aws eks describe-cluster `
  --region us-east-1 `
  --name voting-app-cluster `
  --query "cluster.{name:name,version:version,platform:platformVersion,status:status}" `
  --output table

az aks show `
  --resource-group devsecops-voting-rg `
  --name devsecops-voting-aks `
  --query "{name:name,kubernetesVersion:kubernetesVersion,currentKubernetesVersion:currentKubernetesVersion,provisioningState:provisioningState}" `
  -o table
```

Say:

- "AWS EKS currently runs the primary workload."
- "Azure AKS is the warm standby."
- "AWS Health reported EKS `1.30` end of support, so Terraform is prepared to upgrade EKS to `1.31` one minor version at a time."
- "This is documented in `docs/eks-upgrade-runbook.md`."

## Part 3 - Terraform automation

Show folders:

- `terraform/environments/aws`
- `terraform/environments/azure`
- `terraform/modules`

Run:

```powershell
terraform -chdir=terraform/environments/aws validate
terraform -chdir=terraform/environments/azure validate
```

Say:

- "I do not click-create infrastructure in the cloud console."
- "The project has reusable Terraform modules for networking, EKS, AKS, RDS, Redis, secrets, IAM/OIDC, and controllers."
- "Apply and destroy are wrapped by scripts so the student demo can recreate and remove the whole stack to control cost."

Show:

- [scripts/infra-up.ps1](../scripts/infra-up.ps1)
- [scripts/infra-down.ps1](../scripts/infra-down.ps1)
- [destroy.ps1](../destroy.ps1)

Do not run destroy until the end.

## Part 4 - CI/CD workflow

Open:

- `.github/workflows/ci-pipeline.yml`
- GitHub Actions latest successful run.

Explain the workflow:

- Pull request event runs `PR security gates`.
- Push to `main` builds signed staging artifacts for `vote`, `result`, and `worker`.
- Build job performs dependency/image scanning, SBOM, Cosign signing, and registry push.
- DAST runs against the staging URL.
- Production approval is a separate manual gate.

Show the latest successful run and artifacts:

- SBOM artifacts.
- Scan reports.
- Signed image build jobs.
- DAST staging job.

Say:

- "This is closer to production than push-to-main-only. In production, developers work through PRs; direct main push should be blocked for everyone, including admins."

## Part 5 - PR security gate demo

Show pull request `#28` if still visible, or create a small demo PR:

```powershell
git checkout -b demo/pr-security-gate
Add-Content docs/demo-pr-note.md "PR gate demo"
git add docs/demo-pr-note.md
git commit -m "docs: add pr security gate demo"
git push -u origin demo/pr-security-gate
```

Then open a PR from `demo/pr-security-gate` to `main`.

Show:

- `PR security gates` check passed.
- Merge blocked until review, if branch protection is fully enforced.

After recording, close the PR and delete the branch:

```powershell
git checkout main
git branch -D demo/pr-security-gate
git push origin --delete demo/pr-security-gate
```

Say:

- "This demonstrates secret scanning, SAST, IaC scanning, dependency scanning, Helm rendering, and policy checks before code enters main."

## Part 6 - Production approval gate

Run:

```powershell
.\scripts\run-production-approval.ps1
```

Or manually open:

- GitHub Actions -> DevSecOps CI/CD -> Run workflow.

Show:

- `Production approval gate`.
- The job waits for manual approval if the GitHub Environment requires reviewers.
- The run succeeds after approval.

Say:

- "Production deployment is separated from build. A human approval gate prevents automatic promotion of every successful build."

## Part 7 - GitOps with ArgoCD

Open ArgoCD:

```powershell
.\scripts\open-argocd.ps1
```

If the browser does not open automatically, use:

```powershell
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

Open:

```text
http://localhost:8080
```

Show:

- `voting-aws` is `Synced Healthy`.
- `voting-azure` is `Synced Healthy`, if showing Azure standby ArgoCD.
- ArgoCD SSO button or OIDC configuration.

Run:

```powershell
kubectl -n argocd get applications.argoproj.io
kubectl -n argocd get cm argocd-cm -o yaml | Select-String "oidc.config" -Context 0,20
kubectl -n argocd get cm argocd-rbac-cm -o yaml
```

Say:

- "ArgoCD is the deployment controller. The cluster state follows Git, not manual kubectl apply."
- "SSO/RBAC is integrated with Azure Entra ID groups."

## Part 8 - Secrets through External Secrets Operator

Run:

```powershell
kubectl -n external-secrets get pods,clustersecretstore
kubectl -n voting get externalsecret,secret
kubectl -n voting describe externalsecret voting-db
```

Show:

- AWS Secrets Manager names.
- Azure Key Vault secret.

Say:

- "Application secrets are not stored as plaintext in Kubernetes manifests."
- "External Secrets Operator syncs secrets from cloud secret managers into Kubernetes."

Do not reveal secret values on video.

## Part 9 - Application runtime

Show AWS endpoint:

```powershell
kubectl -n voting get svc
```

If the service has an external load balancer, open the vote URL in browser.

For local testing through port-forward:

```powershell
kubectl -n voting port-forward svc/vote 5000:80
kubectl -n voting port-forward svc/result 5001:80
```

Open:

```text
http://localhost:5000
http://localhost:5001
```

Say:

- "Vote writes to Redis/PostgreSQL path depending on the component."
- "Worker processes votes."
- "Result reads and displays aggregated results."

## Part 10 - Kubernetes admission policy

Run:

```powershell
.\scripts\test-policy-rejects.ps1 -Context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster
```

Then:

```powershell
kubectl get constrainttemplates
kubectl get k8sdisallowlatesttag,k8srequiredcontainersecurity,k8srequiredresources
kubectl get clusterimagepolicy
```

Say:

- "Gatekeeper blocks unsafe workloads such as latest tags, missing resources, or insecure security contexts."
- "Sigstore Policy Controller checks signed container images."
- "This shifts security left into admission control."

## Part 11 - Monitoring and SLO

Open Grafana:

```powershell
.\scripts\open-grafana.ps1
```

If needed, run manually:

```powershell
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Open:

```text
http://localhost:3000
```

Show:

- Voting App SLI/SLO dashboard.
- Prometheus targets.
- `ServiceMonitor` and `PrometheusRule`.

Run:

```powershell
kubectl -n monitoring get pods,servicemonitor,prometheusrule
kubectl -n voting port-forward svc/vote 5000:80
```

Say:

- "SLIs are HTTP success rate, p95 latency, availability, and error rate."
- "Demo SLOs are documented in `docs/slo.md`: availability, p95 latency, and alert timing."
- "Port-forward is used because Grafana is intentionally ClusterIP, not public internet."

Important explanation:

- Helm cannot itself keep a port-forward running. Helm installs Kubernetes resources.
- Port-forward is a local `kubectl` tunnel from your laptop to an internal service.
- Production would expose Grafana through private ingress, VPN, SSO, or an internal load balancer.

## Part 12 - Logging with Loki/Promtail

Run:

```powershell
kubectl -n logging get pods
kubectl -n voting logs deploy/vote --tail=50
kubectl -n voting logs deploy/result --tail=50
```

In Grafana, open Explore and choose Loki.

Example query:

```logql
{namespace="voting"}
```

Say:

- "Promtail collects Kubernetes pod logs."
- "Loki stores and queries logs."
- "Logs are useful for incident triage and DR validation."

## Part 13 - Runtime detection and response

Run:

```powershell
kubectl -n falco get pods
kubectl -n falco logs deploy/falco-falcosidekick --tail=50
```

Optional shell alert demo:

```powershell
kubectl -n voting exec deploy/vote -- sh -c "echo falco-demo"
```

Show:

- Falco/Falcosidekick pod.
- GitHub runtime incident issue or workflow run if configured.
- [runbooks/runtime-response.md](../runbooks/runtime-response.md), if present.

Say:

- "Default response is alert-first."
- "Auto quarantine is optional because false positives can isolate production workloads incorrectly."
- "The safer enterprise pattern is alert, triage, approval, then containment."

## Part 14 - Disaster recovery to Azure

Run:

```powershell
.\scripts\dr-failover.ps1 -SkipScale
```

Show:

- Azure ArgoCD app `Synced Healthy`.
- Azure voting pods ready.
- Vote/result endpoint works through port-forward.
- RTO output from script.

Run:

```powershell
kubectl -n voting get pods,svc,externalsecret
```

Say:

- "AWS is primary."
- "Azure is warm standby."
- "DR flow: scale/sync AKS, verify PostgreSQL logical replication, switch endpoint/DNS when a hosted zone exists, measure RTO/RPO."
- "The current build uses native PostgreSQL logical replication from AWS RDS to Azure PostgreSQL. Backup/seed remains a fallback path for cost-capped rebuilds."

## Part 15 - EKS upgrade readiness

Show:

- [docs/eks-upgrade-runbook.md](./eks-upgrade-runbook.md)

Run:

```powershell
terraform -chdir=terraform/environments/aws plan `
  -target=module.eks.aws_eks_cluster.main `
  -target=module.eks.aws_eks_node_group.main `
  -var "eks_kubernetes_version=1.31"
```

Say:

- "AWS Health warned that EKS `1.30` support is ending."
- "The repo is prepared to upgrade to `1.31` through Terraform."
- "EKS upgrades must be done one minor version at a time, so jumping straight from `1.30` to `1.34` is not the right process."

Do not apply this during a short recording unless you have time to monitor it.

## Part 16 - Cost cleanup

After recording everything:

```powershell
.\destroy.ps1 -AutoApprove
```

Verify expensive resources are gone:

```powershell
aws eks list-clusters --region us-east-1
aws rds describe-db-instances --region us-east-1 --query "DBInstances[].DBInstanceIdentifier"
aws elasticache describe-replication-groups --region us-east-1 --query "ReplicationGroups[].ReplicationGroupId"
az aks list -o table
az network vnet-gateway list -o table
```

Say:

- "Because this is a student project, full apply/destroy automation is part of the design to control cost."

## Suggested final video structure

1. 2 minutes - Problem and architecture.
2. 4 minutes - Terraform and cloud infrastructure.
3. 5 minutes - CI/CD, PR gates, production approval.
4. 4 minutes - GitOps, SSO/RBAC, secrets.
5. 5 minutes - Policy, monitoring, logging, runtime security.
6. 5 minutes - DR failover.
7. 2 minutes - EKS upgrade readiness and cost cleanup.

## What to emphasize in the report

- The project is production-inspired, not a toy deployment.
- Cost-aware exceptions are documented instead of hidden.
- CI/CD does not rely on long-lived cloud credentials.
- Security exists in multiple layers: pipeline, admission, runtime, and response.
- DR is measurable with RTO/RPO, even if live database replication is out of student scope.
