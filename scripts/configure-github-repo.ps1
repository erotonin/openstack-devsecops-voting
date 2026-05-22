#!/usr/bin/env pwsh
param(
    [string]$Repo = "erotonin/devsecops-voting",
    [string]$StagingUrl,
    [switch]$ConfigureBranchProtection
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AwsEnv = Join-Path $Root "terraform/environments/aws"
$AzureEnv = Join-Path $Root "terraform/environments/azure"
$Gh = "gh"

if (Test-Path "C:\Program Files\GitHub CLI\gh.exe") {
    $Gh = "C:\Program Files\GitHub CLI\gh.exe"
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-TerraformOutput {
    param(
        [string]$Path,
        [string]$Name
    )

    Push-Location $Path
    try {
        return (terraform output -raw $Name).Trim()
    } finally {
        Pop-Location
    }
}

Write-Step "Checking GitHub CLI authentication"
& $Gh auth status | Out-Host

Write-Step "Reading Terraform outputs"
$awsRoleArn = Get-TerraformOutput -Path $AwsEnv -Name "github_actions_role_arn"
$awsRegion = Get-TerraformOutput -Path $AwsEnv -Name "aws_region"
$acrLoginServer = Get-TerraformOutput -Path $AzureEnv -Name "acr_login_server"
$azureClientId = Get-TerraformOutput -Path $AzureEnv -Name "github_actions_azure_client_id"
$azureSubscriptionId = (az account show --query id -o tsv).Trim()
$azureTenantId = (az account show --query tenantId -o tsv).Trim()

Write-Step "Configuring repository variables"
& $Gh variable set AWS_REGION --repo $Repo --body $awsRegion | Out-Host
& $Gh variable set ACR_LOGIN_SERVER --repo $Repo --body $acrLoginServer | Out-Host
if ($StagingUrl) {
    & $Gh variable set STAGING_URL --repo $Repo --body $StagingUrl | Out-Host
}

Write-Step "Configuring repository secrets"
& $Gh secret set AWS_ROLE_ARN --repo $Repo --body $awsRoleArn | Out-Host
& $Gh secret set AZURE_CLIENT_ID --repo $Repo --body $azureClientId | Out-Host
& $Gh secret set AZURE_SUBSCRIPTION_ID --repo $Repo --body $azureSubscriptionId | Out-Host
& $Gh secret set AZURE_TENANT_ID --repo $Repo --body $azureTenantId | Out-Host

if ($ConfigureBranchProtection) {
    Write-Step "Configuring main branch protection"
    $payload = @{
        required_status_checks        = @{
            strict   = $true
            contexts = @("PR security gates")
        }
        enforce_admins                = $false
        required_pull_request_reviews = @{
            required_approving_review_count = 1
            dismiss_stale_reviews           = $true
        }
        restrictions                  = $null
        required_linear_history       = $false
        allow_force_pushes            = $false
        allow_deletions               = $false
        block_creations               = $false
        required_conversation_resolution = $true
        lock_branch                   = $false
        allow_fork_syncing            = $true
    } | ConvertTo-Json -Depth 6

    $payloadFile = New-TemporaryFile
    try {
        Set-Content -LiteralPath $payloadFile -Value $payload -Encoding utf8
        & $Gh api `
            --method PUT `
            -H "Accept: application/vnd.github+json" `
            -H "X-GitHub-Api-Version: 2022-11-28" `
            "/repos/$Repo/branches/main/protection" `
            --input $payloadFile | Out-Host
    } finally {
        Remove-Item -LiteralPath $payloadFile -ErrorAction SilentlyContinue
    }
}

Write-Step "Repository configuration completed"
