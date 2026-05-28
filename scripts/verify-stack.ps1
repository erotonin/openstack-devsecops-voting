param(
    [string]$AwsEnv = "terraform/environments/aws",
    [string]$AzureEnv = "terraform/environments/azure",
    [switch]$SkipAzure
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

function Invoke-Check {
    param([string]$Command)
    Write-Host ""
    Write-Host $Command -ForegroundColor DarkGray
    Invoke-Expression $Command
}

Require-Command terraform
Require-Command aws
Require-Command az
Require-Command kubectl

Write-Step "Loading AWS kubeconfig from Terraform output"
Push-Location $AwsEnv
try {
    $awsRegion = terraform output -raw aws_region 2>$null
    if (-not $awsRegion) { $awsRegion = "us-east-1" }
    $eksCluster = terraform output -raw cluster_name
    aws eks update-kubeconfig --region $awsRegion --name $eksCluster | Out-Host
}
finally {
    Pop-Location
}

Write-Step "AWS primary cluster checks"
Invoke-Check "kubectl get nodes -o wide"
Invoke-Check "kubectl get ns"
Invoke-Check "kubectl -n argocd get pods,applications.argoproj.io"
Invoke-Check "kubectl -n external-secrets get pods,clustersecretstore"
Invoke-Check "kubectl -n voting-staging get pods,svc,externalsecret,secret"
Invoke-Check "kubectl -n voting-production get pods,svc,externalsecret,secret"
Invoke-Check "kubectl -n monitoring get pods"
Invoke-Check "kubectl -n logging get pods"
Invoke-Check "kubectl -n falco get pods"
Invoke-Check "kubectl -n gatekeeper-system get pods"
Invoke-Check "kubectl get constrainttemplates"
Invoke-Check "kubectl get k8sdisallowlatesttag,k8srequiredcontainersecurity,k8srequiredresources"

Write-Step "AWS application health checks"
Invoke-Check "kubectl -n voting-staging rollout status deploy/vote --timeout=2m"
Invoke-Check "kubectl -n voting-staging rollout status deploy/result --timeout=2m"
Invoke-Check "kubectl -n voting-staging rollout status deploy/worker --timeout=2m"
Invoke-Check "kubectl -n voting-production rollout status deploy/vote --timeout=2m"
Invoke-Check "kubectl -n voting-production rollout status deploy/result --timeout=2m"
Invoke-Check "kubectl -n voting-production rollout status deploy/worker --timeout=2m"

if (-not $SkipAzure) {
    Write-Step "Loading Azure kubeconfig from Terraform output"
    Push-Location $AzureEnv
    try {
        $rgName = terraform output -raw resource_group_name
        $aksName = terraform output -raw aks_cluster_name
        az aks get-credentials --resource-group $rgName --name $aksName --overwrite-existing | Out-Host
    }
    finally {
        Pop-Location
    }

    Write-Step "Azure warm standby cluster checks"
    Invoke-Check "kubectl get nodes -o wide"
    Invoke-Check "kubectl -n argocd get pods,applications.argoproj.io"
    Invoke-Check "kubectl -n external-secrets get pods,clustersecretstore"
    Invoke-Check "kubectl -n voting-production get pods,svc,externalsecret,secret"
}

Write-Step "Verification completed"
Write-Host "Collect screenshots from ArgoCD, Grafana, Loki, Falco/GitHub issue, and DR output for the report."
