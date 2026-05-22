# Final Demo Script

Use this order for the final presentation. Keep the terminal commands ready before recording or presenting.

## 1. Architecture

Show:

- `architecture.excalidraw.png`
- `docs/scope-lock.md`
- `docs/implementation-map.md`

Talk track:

- AWS is the hot primary site.
- Azure is the warm standby site.
- Terraform provisions both clouds.
- AWS and Azure are connected with route-based IPSec VPN and BGP.
- GitHub Actions uses OIDC, not static cloud keys.
- ArgoCD owns application deployment through GitOps.

## 2. Infrastructure Health

Commands:

```powershell
kubectl -n argocd get application voting-aws --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster
kubectl -n argocd get application voting-azure --context devsecops-voting-aks
kubectl -n voting get pods,svc,externalsecret --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster
kubectl -n voting get pods,svc,externalsecret --context devsecops-voting-aks
```

Expected:

- AWS app: `Synced Healthy`
- Azure app: `Synced Healthy`
- ExternalSecret: `SecretSynced`
- AWS vote endpoint: HTTP 200
- Azure vote/result: HTTP 200 through port-forward

## 3. CI/CD And Branch Protection

Show:

- latest successful CI run
- PR checks
- branch protection settings
- repository secrets/variables page

Evidence:

- `docs/demo-evidence-2026-05-22.md`
- `docs/evidence-checklist.md`

Talk track:

- Pull requests run security gates.
- Direct production-style changes require PR review and required status checks.
- Merging to `main` builds, scans, generates SBOM, signs images, pushes to ECR/ACR, and runs DAST.
- Production promotion is modeled as a manual approval gate.

## 4. Security Gates

Show in CI:

- Gitleaks
- Semgrep
- Checkov/tfsec report
- Trivy filesystem and image scans
- Syft SBOM artifacts
- Cosign signing
- OWASP ZAP DAST

Explain:

- Checkov and tfsec are report-only in this student demo because some cost-conscious exceptions are intentional.
- The project still records those findings and explains the tradeoff.
- Trivy, Gitleaks, Semgrep, Helm, and Conftest remain blocking.

## 5. Admission Policy

Commands:

```powershell
.\scripts\test-policy-rejects.ps1 -Context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster
kubectl get clusterimagepolicy voting-ecr-keyless-github-actions --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster
kubectl get ns voting --show-labels --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster
```

Talk track:

- Gatekeeper blocks unsafe Kubernetes manifests.
- Sigstore Policy Controller enforces keyless GitHub Actions signatures for ECR app images.
- Policy Controller is scoped to the `voting` namespace.

## 6. Observability

Commands:

```powershell
kubectl -n monitoring get pods,servicemonitor,prometheusrule --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster
kubectl -n logging get pods --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster
kubectl -n falco get pods --context arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster
```

Show:

- Grafana SLI/SLO dashboard
- Loki/Promtail pods
- Falco/Falcosidekick pods
- `/metrics` endpoints for vote and result

Talk track:

- SLIs: HTTP success rate, p95 latency, availability, error rate.
- SLO demo targets are in `docs/slo.md`.

## 7. Runtime Response

Show:

- Runtime Incident workflow run
- GitHub issue #27
- `runbooks/runtime-response.md`
- `response/k8s/quarantine-networkpolicy.yaml`

Talk track:

- Default response is alert-first and human triage.
- Quarantine is optional demo mode because false positives can damage real production workloads.

## 8. DR Drill

Command:

```powershell
.\scripts\dr-failover.ps1 -SkipScale
```

Evidence:

- RTO: `1.09 minutes`
- Azure app: `Synced Healthy`
- Azure vote/result HTTP checks passed through port-forward.

Talk track:

- AWS is primary.
- Azure is warm standby.
- DR uses ArgoCD sync plus seed/restore data for student scope.
- Cross-cloud live DB replication is documented as future work.

## 9. Cost Cleanup

When demo is finished:

```powershell
.\destroy.ps1 -AutoApprove
```

Then verify no expensive resources remain:

- EKS/AKS nodes
- NAT gateways
- Load balancers
- VPN gateways
- RDS
- ElastiCache
- public IPs
- disks/snapshots
