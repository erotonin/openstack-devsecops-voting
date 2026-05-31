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
    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) "voting-$file"
    (Get-Content -LiteralPath $path -Raw).Replace("namespace: voting", "namespace: $Namespace") |
        Set-Content -LiteralPath $tempPath -NoNewline

    Write-Host ""
    Write-Host "Applying $file. This should be denied." -ForegroundColor Yellow
    $kubectlArgs = @("apply", "-f", $tempPath, "--dry-run=server")
    if ($Context) {
        $kubectlArgs += @("--context", $Context)
    }
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = (& kubectl @kubectlArgs 2>&1) -join "`n"
    $kubectlExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($kubectlExitCode -eq 0) {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        throw "$file was accepted, but it should have been denied by admission policy."
    }

    Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    if ($output -notmatch "denied|admission webhook|violat|Image signature verification failed") {
        throw "$file failed before admission policy could evaluate it:`n$output"
    }

    Write-Host $output
    Write-Host "$file denied as expected." -ForegroundColor Green
}

Write-Step "Policy reject tests completed"
