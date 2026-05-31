param(
    [string]$AzureEnv = "terraform/environments/azure",
    [int]$UserNodeCount = 1,
    [string]$Namespace = "voting",
    [switch]$SkipScale,
    [switch]$OpenPortForward
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command: $Name"
    }
}

Require-Command terraform
Require-Command az
Require-Command kubectl

$StartedAt = Get-Date
Write-Step "DR drill started at $($StartedAt.ToString("o"))"

Push-Location $AzureEnv
try {
    $ResourceGroup = terraform output -raw resource_group_name
    $AksCluster = terraform output -raw aks_cluster_name
}
finally {
    Pop-Location
}

Write-Step "Connecting kubectl to AKS standby cluster"
az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing | Out-Host

if (-not $SkipScale) {
    Write-Step "Scaling AKS user node pool to $UserNodeCount node(s)"
    $UserPool = az aks nodepool list `
        --resource-group $ResourceGroup `
        --cluster-name $AksCluster `
        --query "[?mode=='User'].name | [0]" `
        --output tsv

    if (-not $UserPool) {
        throw "Could not find an AKS user node pool to scale."
    }

    az aks nodepool scale `
        --resource-group $ResourceGroup `
        --cluster-name $AksCluster `
        --name $UserPool `
        --node-count $UserNodeCount | Out-Host
}

Write-Step "Waiting for AKS nodes"
kubectl wait --for=condition=Ready nodes --all --timeout=10m | Out-Host

Write-Step "Waiting for ArgoCD standby controller"
kubectl -n argocd rollout status deploy/argocd-server --timeout=5m | Out-Host
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=5m | Out-Host

Write-Step "Refreshing Azure standby application"
kubectl -n argocd annotate application voting-azure argocd.argoproj.io/refresh=hard --overwrite | Out-Host

Write-Step "Waiting for voting workloads"
kubectl -n $Namespace rollout status deploy/vote --timeout=10m | Out-Host
kubectl -n $Namespace rollout status deploy/result --timeout=10m | Out-Host
kubectl -n $Namespace rollout status deploy/worker --timeout=10m | Out-Host

$ReadyAt = Get-Date
$Rto = [Math]::Round(($ReadyAt - $StartedAt).TotalMinutes, 2)

Write-Step "DR drill workload recovery completed"
Write-Host "Started: $($StartedAt.ToString("o"))"
Write-Host "Ready:   $($ReadyAt.ToString("o"))"
Write-Host "RTO:     $Rto minutes"

Write-Step "Useful verification commands"
Write-Host "kubectl -n $Namespace get pods,svc"
Write-Host "kubectl -n argocd get application voting-azure"

if ($OpenPortForward) {
    Write-Step "Opening local port-forward to Azure vote service"
    Write-Host "Vote UI: http://localhost:8080"
    kubectl -n $Namespace port-forward svc/vote 8080:80
}
