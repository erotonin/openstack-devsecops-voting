# Demo Evidence - 2026-05-22

This file records verified evidence from the live demo environment.

## CI/CD And Release Control

- Latest main CI/CD run succeeded:
  https://github.com/erotonin/devsecops-voting/actions/runs/26268143585
- Latest merged dependency PR CI succeeded:
  https://github.com/erotonin/devsecops-voting/actions/runs/26268048524
- Manual OWASP ZAP DAST succeeded against AWS staging:
  https://github.com/erotonin/devsecops-voting/actions/runs/26267394350
- `main` branch protection is enabled with:
  - one required pull request review
  - required status check: `PR security gates`
- GitHub repository variables/secrets were configured through:
  `scripts/configure-github-repo.ps1`

## Dependency Management

Dependabot is enabled for GitHub Actions, Python, npm, NuGet, Terraform, and Docker.

Merged low-risk dependency updates:

- `zaproxy/action-baseline` 0.14.0 to 0.15.0
- `express` 4.18.2 to 4.22.2
- `Npgsql` 7.0.7 to 7.0.10

Major updates are intentionally ignored in Dependabot configuration and should be handled as planned upgrade work, not auto-merged.

## AWS Primary Site

- ArgoCD application: `voting-aws`
- Sync status: `Synced`
- Health status: `Healthy`
- External Secrets status: `SecretSynced`
- Vote service public endpoint returned HTTP 200:
  `http://a4bdf43777192482cb1c20c79adafff8-2084416586.us-east-1.elb.amazonaws.com`
- Result service is exposed through AWS LoadBalancer:
  `a19a085a6969d46e8808901cd82167a6-1708925558.us-east-1.elb.amazonaws.com`

## Azure Warm Standby Site

- ArgoCD application: `voting-azure`
- Sync status: `Synced`
- Health status: `Healthy`
- External Secrets status: `SecretSynced`
- Azure vote service returned HTTP 200 through port-forward.
- Azure result service returned HTTP 200 through port-forward.

## DR Drill

Command:

```powershell
.\scripts\dr-failover.ps1 -SkipScale
```

Measured output:

- Started: `2026-05-22T12:59:27.0162828+07:00`
- Ready: `2026-05-22T13:00:32.2870970+07:00`
- RTO: `1.09 minutes`
- RPO: seed/restore based for student scope; live cross-cloud database replication is documented as future work.

## Runtime Response

Runtime incident workflow run succeeded:

https://github.com/erotonin/devsecops-voting/actions/runs/26271279740

Generated GitHub incident issue:

https://github.com/erotonin/devsecops-voting/issues/27

Response model:

- default: alert and human triage
- optional demo: scoped quarantine using `response/k8s/quarantine-networkpolicy.yaml`

## Signed Image Enforcement

Sigstore Policy Controller is installed in the AWS primary cluster.

Verified enforcement state:

- CRD exists: `clusterimagepolicies.policy.sigstore.dev`
- Policy exists: `voting-ecr-keyless-github-actions`
- Policy mode: `enforce`
- Policy status: `Ready`
- Namespace opt-in label:
  `policy.sigstore.dev/include=true`
- Signed image admission smoke test passed through:
  `scripts/apply-sigstore-policy.ps1 -Apply`

The policy matches the three ECR application repositories and verifies keyless GitHub Actions signatures issued by Fulcio.

## Current Gate Policy

Blocking PR gates:

- Gitleaks
- Semgrep
- Trivy filesystem scan
- Helm template validation
- Conftest Kubernetes policy scan

Report-only baseline scans:

- Checkov
- tfsec

Reason: the current student demo intentionally keeps some cost-conscious exceptions, such as short log retention and Basic ACR. These findings are still visible in CI output for discussion.
