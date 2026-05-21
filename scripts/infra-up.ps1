#!/usr/bin/env pwsh
param(
    [ValidateSet("full-demo")]
    [string]$Environment = "full-demo",
    [switch]$AutoApprove,
    [switch]$SkipValidate
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

function Assert-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Invoke-TerraformApply {
    param(
        [string]$Path,
        [string]$Label,
        [string[]]$Targets = @()
    )

    Push-Location $Path
    try {
        Write-Step "$Label terraform init"
        terraform init

        if (-not $SkipValidate) {
            Write-Step "$Label terraform fmt/check"
            terraform fmt -check -recursive

            Write-Step "$Label terraform validate"
            terraform validate
        }

        $targetArgs = @()
        foreach ($target in $Targets) {
            $targetArgs += "-target=$target"
        }

        Write-Step "$Label terraform plan"
        terraform plan @targetArgs -out=tfplan

        Write-Step "$Label terraform apply"
        if ($AutoApprove) {
            terraform apply -auto-approve tfplan
        } else {
            terraform apply tfplan
        }
    } finally {
        Pop-Location
    }
}

Write-Step "Checking local prerequisites"
@("terraform", "aws", "az", "kubectl", "helm") | ForEach-Object { Assert-Command $_ }

Write-Step "Checking AWS identity"
aws sts get-caller-identity | Out-Host

Write-Step "Checking Azure identity"
az account show --output table | Out-Host

# First create Azure networking and VPN gateway so AWS can read the Azure VPN public IP.
Invoke-TerraformApply -Path $AzureEnv -Label "Azure VPN gateway bootstrap" -Targets @(
    "module.azure_networking",
    "azurerm_public_ip.vpn_ip",
    "azurerm_virtual_network_gateway.vng"
)

Invoke-TerraformApply -Path $AwsEnv -Label "AWS primary"

# Finish Azure after AWS has written tunnel details to remote state.
Invoke-TerraformApply -Path $AzureEnv -Label "Azure warm standby"

Write-Step "Updating kubeconfig files"
Push-Location $AwsEnv
try {
    $awsRegion = terraform output -raw aws_region 2>$null
    if (-not $awsRegion) { $awsRegion = "us-east-1" }
    $eksCluster = terraform output -raw cluster_name
    aws eks update-kubeconfig --region $awsRegion --name $eksCluster
} finally {
    Pop-Location
}

Push-Location $AzureEnv
try {
    $rgName = terraform output -raw resource_group_name 2>$null
    $aksName = terraform output -raw aks_cluster_name 2>$null
    if ($rgName -and $aksName) {
        az aks get-credentials --resource-group $rgName --name $aksName --overwrite-existing
    }
} finally {
    Pop-Location
}

Write-Step "Infrastructure apply completed"
Write-Host "Next: verify ArgoCD, ESO, Gatekeeper, monitoring, logging, and Falco once their modules are added." -ForegroundColor Green
