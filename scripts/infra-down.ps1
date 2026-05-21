#!/usr/bin/env pwsh
param(
    [ValidateSet("full-demo")]
    [string]$Environment = "full-demo",
    [switch]$AutoApprove,
    [switch]$SkipKubernetesCleanup
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AwsEnv = Join-Path $Root "terraform/environments/aws"
$AzureEnv = Join-Path $Root "terraform/environments/azure"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-TerraformDestroy {
    param(
        [string]$Path,
        [string]$Label
    )

    Push-Location $Path
    try {
        Write-Step "$Label terraform init"
        terraform init

        Write-Step "$Label terraform destroy"
        if ($AutoApprove) {
            terraform destroy -auto-approve
        } else {
            terraform destroy
        }
    } finally {
        Pop-Location
    }
}

function Remove-KubernetesResources {
    if ($SkipKubernetesCleanup) {
        Write-Step "Skipping Kubernetes cleanup"
        return
    }

    Write-Step "Pre-destroy Kubernetes cleanup"
    $namespaces = @("voting", "argocd", "monitoring", "logging", "falco", "external-secrets", "gatekeeper-system")

    foreach ($ns in $namespaces) {
        kubectl delete applications.argoproj.io --all -n $ns --ignore-not-found=true 2>$null
        kubectl delete ingress --all -n $ns --ignore-not-found=true 2>$null
        kubectl delete svc --all -n $ns --ignore-not-found=true 2>$null
    }

    foreach ($ns in $namespaces) {
        kubectl delete namespace $ns --ignore-not-found=true --timeout=90s 2>$null
    }
}

function Remove-EcrImages {
    Write-Step "Cleaning ECR images before Terraform destroy"
    $repos = @("voting-app-vote", "voting-app-result", "voting-app-worker")

    foreach ($repo in $repos) {
        $images = aws ecr list-images --repository-name $repo --query 'imageIds' --output json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $images -or $images -eq "[]") {
            continue
        }

        $tmp = New-TemporaryFile
        try {
            Set-Content -LiteralPath $tmp -Value $images
            aws ecr batch-delete-image --repository-name $repo --image-ids "file://$tmp" | Out-Host
        } finally {
            Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
        }
    }
}

Write-Step "Destroy safety check"
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "This will destroy the full demo infrastructure managed by Terraform." -ForegroundColor Yellow

if (-not $AutoApprove) {
    $answer = Read-Host "Type DESTROY to continue"
    if ($answer -ne "DESTROY") {
        throw "Destroy cancelled."
    }
}

Remove-KubernetesResources
Remove-EcrImages

Invoke-TerraformDestroy -Path $AwsEnv -Label "AWS primary"
Invoke-TerraformDestroy -Path $AzureEnv -Label "Azure warm standby"

Write-Step "Post-destroy reminder"
Write-Host "Check for remaining cost-bearing resources: Load Balancers, NAT Gateways, EKS/AKS nodes, RDS, ElastiCache, VPN Gateways, public IPs, disks, snapshots." -ForegroundColor Green
