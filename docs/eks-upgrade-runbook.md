# EKS Upgrade Runbook

## Why this exists

AWS Health reported that the live EKS cluster `voting-app-cluster` is running Kubernetes `1.30`. EKS extended support for `1.30` ends on July 23, 2026, so the production-grade target is to move the cluster to a supported version before that date.

AWS only allows EKS control plane upgrades one minor version at a time. Because the current live version is `1.30`, the next safe step is `1.31`; after that, repeat the same process for `1.32`, `1.33`, and `1.34` if the demo window allows it.

Reference: https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html

## Current target

Terraform is configured with:

- AWS EKS target: `1.31`
- AKS target/live version: `1.34`

The AWS target is intentionally `1.31` because live EKS is currently `1.30`.

## Pre-checks

```powershell
aws eks describe-cluster `
  --region us-east-1 `
  --name voting-app-cluster `
  --query "cluster.{name:name,version:version,platform:platformVersion,status:status}" `
  --output table

kubectl config use-context aws
kubectl get nodes -o wide
kubectl get pods -A
```

Do not start an upgrade if the cluster is already unhealthy.

## Upgrade to 1.31

Run from the AWS Terraform environment:

```powershell
cd C:\Users\Admin\Desktop\Devops\DevSecOps-Voting-App\terraform\environments\aws
terraform init
terraform plan -var "eks_kubernetes_version=1.31" -out tfplan-eks-131
terraform apply tfplan-eks-131
```

Expected behavior:

- EKS control plane moves from `1.30` to `1.31`.
- Managed node group rolls to `1.31`.
- EKS add-ons stay managed by Terraform and should reconcile to compatible versions.

## Post-checks

```powershell
aws eks describe-cluster `
  --region us-east-1 `
  --name voting-app-cluster `
  --query "cluster.{name:name,version:version,platform:platformVersion,status:status}" `
  --output table

aws eks update-kubeconfig --region us-east-1 --name voting-app-cluster --alias aws
kubectl config use-context aws
kubectl get nodes
kubectl -n voting rollout status deploy/vote --timeout=180s
kubectl -n voting rollout status deploy/result --timeout=180s
kubectl -n voting rollout status deploy/worker --timeout=180s

cd C:\Users\Admin\Desktop\Devops\DevSecOps-Voting-App
.\scripts\verify-stack.ps1
```

## Repeat for later versions

After `1.31` is healthy, repeat with the next minor version:

```powershell
terraform plan -var "eks_kubernetes_version=1.32" -out tfplan-eks-132
terraform apply tfplan-eks-132
```

Continue one minor version at a time until the desired version is reached.

## Demo explanation

For the capstone demo, explain this as operational maturity:

- AWS Health generated an end-of-support finding for EKS `1.30`.
- The team did not click around in the console.
- The desired Kubernetes version is controlled by Terraform.
- The upgrade path is documented and repeatable.
- Verification uses both cloud APIs and Kubernetes workload health checks.
