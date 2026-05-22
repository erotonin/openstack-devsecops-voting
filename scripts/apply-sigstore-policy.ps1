#!/usr/bin/env pwsh
param(
    [string]$Context = "arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster",
    [string]$Namespace = "voting",
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
    Write-Host "Run with -Apply to enforce the policy in namespace '$Namespace'."
    exit 0
}

$labelApplied = $false
try {
    Write-Step "Applying ClusterImagePolicy"
    Invoke-Kubectl @("apply", "-f", $PolicyPath) | Out-Host

    Write-Step "Opting namespace into policy-controller"
    Invoke-Kubectl @("label", "namespace", $Namespace, "policy.sigstore.dev/include=true", "--overwrite") | Out-Host
    $labelApplied = $true

    Write-Step "Running signed image admission smoke test"
    $smokeManifest = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sigstore-signed-smoke
  namespace: $Namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sigstore-signed-smoke
  template:
    metadata:
      labels:
        app: sigstore-signed-smoke
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: vote
          image: $SmokeImage
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 250m
              memory: 256Mi
          securityContext:
            allowPrivilegeEscalation: false
            runAsNonRoot: true
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
"@
    $smokeFile = New-TemporaryFile
    try {
        [System.IO.File]::WriteAllText($smokeFile.FullName, $smokeManifest, [System.Text.UTF8Encoding]::new($false))
        Invoke-Kubectl @("apply", "--dry-run=server", "-f", $smokeFile.FullName) | Out-Null
    }
    finally {
        Remove-Item -LiteralPath $smokeFile -ErrorAction SilentlyContinue
    }

    Write-Step "Sigstore enforcement is active"
    Write-Host "Namespace: $Namespace"
    Write-Host "Policy:    voting-ecr-keyless-github-actions"
}
catch {
    if ($labelApplied) {
        Write-Step "Admission smoke test failed, removing namespace opt-in label"
        Invoke-Kubectl @("label", "namespace", $Namespace, "policy.sigstore.dev/include-") | Out-Host
    }
    throw
}
