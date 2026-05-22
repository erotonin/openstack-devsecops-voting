#!/usr/bin/env pwsh
param(
    [string]$Repo = "erotonin/devsecops-voting",
    [string]$Ref = "main"
)

$ErrorActionPreference = "Stop"
$Gh = "gh"

if (Test-Path "C:\Program Files\GitHub CLI\gh.exe") {
    $Gh = "C:\Program Files\GitHub CLI\gh.exe"
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

Write-Step "Checking GitHub CLI authentication"
& $Gh auth status | Out-Host

Write-Step "Triggering production approval workflow"
& $Gh workflow run "ci-pipeline.yml" `
    --repo $Repo `
    --ref $Ref `
    -f promote_production=true | Out-Host

Write-Host ""
Write-Host "Open Actions, select the new DevSecOps CI/CD run, then approve the production environment when prompted." -ForegroundColor Green
Write-Host "This job only proves the human approval boundary; production deployment remains GitOps-driven through ArgoCD." -ForegroundColor Green
