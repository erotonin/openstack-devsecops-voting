#!/usr/bin/env pwsh
param(
    [string]$DisplayName = "devsecops-voting-argocd",
    [string]$ArgoCdUrl = "https://argocd.local",
    [string]$AwsEnv = "terraform/environments/aws",
    [string]$AzureEnv = "terraform/environments/azure"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AwsEnvPath = Join-Path $Root $AwsEnv
$AzureEnvPath = Join-Path $Root $AzureEnv
$RedirectUri = "$($ArgoCdUrl.TrimEnd('/'))/auth/callback"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Tfvars {
    param(
        [string]$Path,
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )

    $content = @"
argocd_url               = "$ArgoCdUrl"
argocd_sso_enabled       = true
argocd_sso_tenant_id     = "$TenantId"
argocd_sso_client_id     = "$ClientId"
argocd_sso_client_secret = "$ClientSecret"

# Replace these with Azure Entra security group object IDs for real group-based RBAC.
argocd_sso_admin_groups    = ["devsecops-admins"]
argocd_sso_readonly_groups = ["devsecops-developers"]
"@

    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
}

Write-Step "Checking Azure identity"
az account show --query "{name:name, tenantId:tenantId, subscriptionId:id}" -o table | Out-Host
$tenantId = (az account show --query tenantId -o tsv).Trim()

Write-Step "Creating Azure Entra application registration"
$app = az ad app create `
    --display-name $DisplayName `
    --sign-in-audience AzureADMyOrg `
    --web-redirect-uris $RedirectUri `
    --query "{appId:appId,id:id}" `
    -o json | ConvertFrom-Json

$appPatch = @{
    groupMembershipClaims = "SecurityGroup"
    web                   = @{
        redirectUris           = @($RedirectUri)
        implicitGrantSettings  = @{
            enableIdTokenIssuance     = $true
            enableAccessTokenIssuance = $false
        }
    }
} | ConvertTo-Json -Depth 5

$patchFile = New-TemporaryFile
try {
    [System.IO.File]::WriteAllText($patchFile.FullName, $appPatch, [System.Text.UTF8Encoding]::new($false))
    az rest `
        --method PATCH `
        --uri "https://graph.microsoft.com/v1.0/applications/$($app.id)" `
        --headers "Content-Type=application/json" `
        --body "@$($patchFile.FullName)" | Out-Host
} finally {
    Remove-Item -LiteralPath $patchFile.FullName -ErrorAction SilentlyContinue
}

Write-Step "Creating service principal"
az ad sp create --id $app.appId --only-show-errors | Out-Host

Write-Step "Creating client secret"
$clientSecret = (az ad app credential reset `
    --id $app.appId `
    --append `
    --display-name "argocd-sso" `
    --years 1 `
    --query password `
    -o tsv).Trim()

if (-not $clientSecret) {
    throw "Azure CLI did not return a client secret"
}

Write-Step "Writing local Terraform variable files"
$awsTfvars = Join-Path $AwsEnvPath "argocd-sso.auto.tfvars"
$azureTfvars = Join-Path $AzureEnvPath "argocd-sso.auto.tfvars"
Write-Tfvars -Path $awsTfvars -TenantId $tenantId -ClientId $app.appId -ClientSecret $clientSecret
Write-Tfvars -Path $azureTfvars -TenantId $tenantId -ClientId $app.appId -ClientSecret $clientSecret

Write-Host ""
Write-Host "Created Entra app registration for ArgoCD SSO." -ForegroundColor Green
Write-Host "Client ID: $($app.appId)" -ForegroundColor Green
Write-Host "Redirect URI: $RedirectUri" -ForegroundColor Green
Write-Host ""
Write-Host "Review group mappings in:" -ForegroundColor Yellow
Write-Host "- $awsTfvars" -ForegroundColor Yellow
Write-Host "- $azureTfvars" -ForegroundColor Yellow
Write-Host ""
Write-Host "Then run Terraform apply for the AWS/Azure Helm runtime stage." -ForegroundColor Green
