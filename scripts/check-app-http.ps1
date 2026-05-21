#!/usr/bin/env pwsh
param(
    [string]$Context = "",
    [string]$Namespace = "voting",
    [int]$VotePort = 18080,
    [int]$ResultPort = 18081
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Start-PortForward {
    param(
        [string]$ServiceName,
        [int]$LocalPort,
        [int]$RemotePort
    )

    $args = @(
        "port-forward",
        "-n", $Namespace,
        "svc/$ServiceName",
        "${LocalPort}:${RemotePort}"
    )
    if ($Context) {
        $args += @("--context", $Context)
    }

    $process = Start-Process -FilePath "kubectl" `
        -ArgumentList $args `
        -PassThru `
        -WindowStyle Hidden `
        -RedirectStandardOutput "$env:TEMP\kubectl-$ServiceName-port-forward.out" `
        -RedirectStandardError "$env:TEMP\kubectl-$ServiceName-port-forward.err"

    Start-Sleep -Seconds 3
    if ($process.HasExited) {
        $errorText = Get-Content "$env:TEMP\kubectl-$ServiceName-port-forward.err" -ErrorAction SilentlyContinue
        throw "port-forward for $ServiceName exited early: $errorText"
    }

    return $process
}

function Test-Url {
    param([string]$Url)

    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 20
    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 400) {
        throw "$Url returned HTTP $($response.StatusCode)"
    }
    Write-Host "$Url -> HTTP $($response.StatusCode)" -ForegroundColor Green
}

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw "Missing required command: kubectl"
}

$processes = @()
try {
    Write-Step "Starting port-forward to vote and result services"
    $processes += Start-PortForward -ServiceName "vote" -LocalPort $VotePort -RemotePort 80
    $processes += Start-PortForward -ServiceName "result" -LocalPort $ResultPort -RemotePort 80

    Write-Step "Checking HTTP endpoints"
    Test-Url "http://127.0.0.1:$VotePort/"
    Test-Url "http://127.0.0.1:$ResultPort/"

    Write-Step "Application HTTP checks passed"
}
finally {
    foreach ($process in $processes) {
        if ($process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
    }
}
