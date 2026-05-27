#!/usr/bin/env pwsh
param(
    [string]$Context = "arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster",
    [string[]]$Namespace = @("voting-staging", "voting-production"),
    [string]$PolicyPath = "policies/sigstore/clusterimagepolicy-ecr-keyless.yaml",
    [string]$SmokeImage = "800557027783.dkr.ecr.us-east-1.amazonaws.com/voting-app-vote:c858f7d60a063c5ad076915c706e33c48fb2decd",
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-Kubectl {
    param([string[]]$Arguments)

    $args = @()
    if ($Context) {
        $args += @("--context", $Context)
    }
    $args += $Arguments
    & kubectl @args
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl failed with exit code $($LASTEXITCODE): kubectl $($args -join ' ')"
    }
}

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw "Missing required command: kubectl"
}

if (-not (Test-Path -LiteralPath $PolicyPath)) {
    throw "Policy file not found: $PolicyPath"
}

Write-Step "Checking policy-controller CRDs"
Invoke-Kubectl @("get", "crd", "clusterimagepolicies.policy.sigstore.dev") | Out-Host

Write-Step "Validating ClusterImagePolicy manifest"
Invoke-Kubectl @("apply", "--dry-run=server", "-f", $PolicyPath) | Out-Host

if (-not $Apply) {
    Write-Step "Dry-run completed"
    Write-Host "Run with -Apply to enforce the policy in namespace(s): $($Namespace -join ', ')."
    exit 0
}

$labelApplied = $false
try {
    Write-Step "Applying ClusterImagePolicy"
    Invoke-Kubectl @("apply", "-f", $PolicyPath) | Out-Host

    Write-Step "Opting namespaces into policy-controller"
    foreach ($ns in $Namespace) {
        Invoke-Kubectl @("label", "namespace", $ns, "policy.sigstore.dev/include=true", "--overwrite") | Out-Host
    }
    $labelApplied = $true

    Write-Step "Sigstore enforcement is active"
    Write-Host "Namespaces: $($Namespace -join ', ')"
    Write-Host "Policy:    voting-ecr-keyless-github-actions"
}
catch {
    if ($labelApplied) {
        Write-Step "Admission smoke test failed, removing namespace opt-in label"
        foreach ($ns in $Namespace) {
            Invoke-Kubectl @("label", "namespace", $ns, "policy.sigstore.dev/include-") | Out-Host
        }
    }
    throw
}
