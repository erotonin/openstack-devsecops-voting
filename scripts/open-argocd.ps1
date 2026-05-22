#!/usr/bin/env pwsh
param(
    [string]$Context = "arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster",
    [string]$Namespace = "argocd",
    [int]$LocalPort = 8080
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

Write-Step "Checking ArgoCD server"
kubectl --context $Context -n $Namespace get svc argocd-server | Out-Host

Write-Step "Reading ArgoCD SSO configuration"
kubectl --context $Context -n $Namespace get cm argocd-cm -o jsonpath="{.data.oidc\.config}" | Out-Host

Write-Host ""
Write-Host "ArgoCD URL: http://localhost:$LocalPort" -ForegroundColor Green
Write-Host "SSO redirect URI: http://localhost:$LocalPort/auth/callback" -ForegroundColor Green
Write-Host ""
Write-Host "Keep this terminal open while using ArgoCD. Press Ctrl+C to stop port-forward." -ForegroundColor Yellow
Write-Host "The browser may warn about the ArgoCD self-signed certificate; accept it for the local demo." -ForegroundColor Yellow

kubectl --context $Context -n $Namespace port-forward svc/argocd-server "${LocalPort}:443"
