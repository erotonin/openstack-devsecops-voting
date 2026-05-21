#!/usr/bin/env pwsh
param(
    [string]$Context = "",
    [string]$PolicyRoot = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $PolicyRoot) {
    $PolicyRoot = Join-Path $Root "policies/gatekeeper"
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-Kubectl {
    param([string[]]$Arguments)
    if ($Context) {
        $Arguments += @("--context", $Context)
    }
    & kubectl @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl $($Arguments -join ' ') failed"
    }
}

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw "Missing required command: kubectl"
}

$templateDir = Join-Path $PolicyRoot "templates"
$constraintDir = Join-Path $PolicyRoot "constraints"

Write-Step "Applying Gatekeeper ConstraintTemplates"
Invoke-Kubectl @("apply", "-f", $templateDir)

Write-Step "Waiting for Gatekeeper CRDs"
Start-Sleep -Seconds 20

Write-Step "Applying Gatekeeper Constraints"
Invoke-Kubectl @("apply", "-f", $constraintDir)

Write-Step "Gatekeeper policies applied"
Invoke-Kubectl @("get", "constrainttemplates")
Invoke-Kubectl @("get", "k8sdisallowlatesttag,k8srequiredcontainersecurity,k8srequiredresources")
