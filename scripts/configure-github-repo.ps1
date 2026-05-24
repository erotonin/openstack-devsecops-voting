#!/usr/bin/env pwsh
param(
    [string]$Repo = "erotonin/devsecops-voting",
    [string]$StagingUrl,
    [switch]$ConfigureBranchProtection,
    [switch]$ConfigurePromotionToken
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

if ($ConfigurePromotionToken) {
    Write-Step "Configuring promotion PR token"
    $promotionToken = (& $Gh auth token).Trim()
    if (-not $promotionToken) {
        throw "Could not read GitHub CLI token for ACTIONS_PR_TOKEN."
    }
    & $Gh secret set ACTIONS_PR_TOKEN --repo $Repo --body $promotionToken | Out-Host
}

Write-Step "Configuring GitHub Actions workflow permissions"
& $Gh api `
    --method PUT `
    -H "Accept: application/vnd.github+json" `
    -H "X-GitHub-Api-Version: 2022-11-28" `
    "/repos/$Repo/actions/permissions/workflow" `
    -f default_workflow_permissions=write `
    -F can_approve_pull_request_reviews=true | Out-Host

if ($ConfigureBranchProtection) {
    Write-Step "Configuring main branch protection"
    $payload = @{
        required_status_checks        = @{
            strict   = $true
            contexts = @("PR security gates")
        }
        enforce_admins                = $true
        required_pull_request_reviews = @{
            required_approving_review_count = 1
            dismiss_stale_reviews           = $true
        }
        restrictions                  = $null
    } | ConvertTo-Json -Depth 6

    $payloadFile = New-TemporaryFile
    try {
        [System.IO.File]::WriteAllText($payloadFile.FullName, $payload, [System.Text.UTF8Encoding]::new($false))
        & $Gh api `
            --method PUT `
            -H "Accept: application/vnd.github+json" `
            -H "X-GitHub-Api-Version: 2022-11-28" `
            "/repos/$Repo/branches/main/protection" `
            --input $payloadFile.FullName | Out-Host
    } finally {
        Remove-Item -LiteralPath $payloadFile -ErrorAction SilentlyContinue
    }
}

Write-Step "Repository configuration completed"
