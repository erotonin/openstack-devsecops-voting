#!/usr/bin/env pwsh
param(
    [string]$Context = "arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster",
    [string]$Namespace = "monitoring",
    [string]$Service = "kube-prometheus-stack-grafana",
    [int]$LocalPort = 3000,
    [int]$RemotePort = 80
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

Write-Step "Checking Grafana service"
kubectl --context $Context -n $Namespace get svc $Service | Out-Host

Write-Step "Reading Grafana admin password"
$password = kubectl --context $Context -n $Namespace get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}"
if (-not $password) {
    throw "Could not read Grafana admin password from secret kube-prometheus-stack-grafana"
}

$plainPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))

Write-Host ""
Write-Host "Grafana URL: http://localhost:$LocalPort" -ForegroundColor Green
Write-Host "Username: admin" -ForegroundColor Green
Write-Host "Password: $plainPassword" -ForegroundColor Green
Write-Host ""
Write-Host "Keep this terminal open while using Grafana. Press Ctrl+C to stop port-forward." -ForegroundColor Yellow

kubectl --context $Context -n $Namespace port-forward "svc/$Service" "${LocalPort}:${RemotePort}"
