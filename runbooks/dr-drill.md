# DR Drill Runbook

## Goal

Recover the voting app on Azure warm standby and measure RTO/RPO.

Target:

- RTO: less than 30 minutes for the student demo.
- RPO: latest available seed, backup, or snapshot restore point.

## Architecture Assumption

AWS is the hot site. Azure is the warm standby site.

Azure now has its own standby ArgoCD controller. This avoids depending on the AWS ArgoCD hub during an AWS-region failure.

## Before The Drill

Confirm:

- Terraform state is healthy for both clouds.
- AKS exists and has a small standby node pool.
- Azure Key Vault contains `voting-app-runtime`.
- Images exist in Azure ACR.
- `k8s/values-azure.yaml` points to the Azure image registry and Azure secret store.

## Failover Procedure

Run:

```powershell
.\scripts\dr-failover.ps1 -UserNodeCount 2
```

The script:

1. Reads AKS resource group and cluster name from Terraform output.
2. Gets AKS kubeconfig.
3. Scales the AKS user node pool.
4. Waits for nodes and ArgoCD.
5. Refreshes the Azure ArgoCD application.
6. Waits for `vote`, `result`, and `worker`.
7. Prints RTO in minutes.

For a local UI check:

```powershell
.\scripts\dr-failover.ps1 -UserNodeCount 2 -OpenPortForward
```

Then open:

```text
http://localhost:8080
```

## Data Restore / Seed Options

For this student scope, cross-cloud live database replication is not required.

Allowed demo options:

- Restore database from a prepared dump or cloud snapshot.
- Seed a small known dataset after app recovery.
- Use the latest copied backup artifact and record the timestamp as RPO.

Record:

- Source backup timestamp.
- Restore start time.
- Restore finish time.
- First successful vote on Azure.

## Endpoint / DNS Switch

For the full demo, switch traffic after Azure is healthy:

- Manual: update the demo endpoint shown to the assessor.
- DNS: update Route53 failover record or weighted record to point to Azure ingress.

Keep the old AWS endpoint unchanged until rollback is decided.

## Rollback

After AWS is healthy again:

1. Verify AWS EKS, RDS, Redis, and ingress.
2. Sync the AWS ArgoCD app.
3. Switch endpoint/DNS back to AWS.
4. Scale Azure user node pool down.

```powershell
az aks nodepool scale `
  --resource-group <resource-group> `
  --cluster-name <aks-cluster> `
  --name <user-nodepool> `
  --node-count 1
```

## Evidence Checklist

- Command output showing script start and ready timestamps.
- `kubectl -n voting get pods,svc`.
- Azure vote UI screenshot or successful curl.
- ArgoCD Azure application health/sync status.
- RTO/RPO values.
- Notes on whether data was restored or seeded.
