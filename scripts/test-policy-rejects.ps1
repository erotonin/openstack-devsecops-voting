param(
    [string]$Namespace = "voting-staging",
    [string]$Context = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$PolicyDir = Join-Path $Root "tests/policy"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw "Missing required command: kubectl"
}

Write-Step "Testing Gatekeeper admission rejects"
$files = @(
    "deny-latest.yaml",
    "deny-privileged.yaml",
    "deny-missing-resources.yaml"
)

foreach ($file in $files) {
    $path = Join-Path $PolicyDir $file
    Write-Host ""
    Write-Host "Applying $file. This should be denied." -ForegroundColor Yellow
    $kubectlArgs = @("apply", "-f", $path, "-n", $Namespace, "--dry-run=server")
    if ($Context) {
        $kubectlArgs += @("--context", $Context)
    }
    & kubectl @kubectlArgs
    if ($LASTEXITCODE -eq 0) {
        throw "$file was accepted, but it should have been denied by admission policy."
    }
    Write-Host "$file denied as expected." -ForegroundColor Green
}

Write-Step "Policy reject tests completed"
