param(
    [string]$AzureEnv = "terraform/environments/azure",
    [Parameter(Mandatory = $true)]
    [string]$DbHost,
    [Parameter(Mandatory = $true)]
    [string]$DbPassword,
    [Parameter(Mandatory = $true)]
    [string]$RedisHost,
    [string]$RedisPassword = "",
    [string]$DbUser = "postgres",
    [string]$DbName = "voting",
    [string]$SecretName = "voting-app-runtime"
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command: $Name"
    }
}

Require-Command terraform
Require-Command az

Push-Location $AzureEnv
try {
    $VaultUri = terraform output -raw key_vault_uri
}
finally {
    Pop-Location
}

$VaultName = ([System.Uri]$VaultUri).Host.Split(".")[0]

$RuntimeConfig = [ordered]@{
    REDIS_HOST     = $RedisHost
    REDIS_PORT     = "6379"
    REDIS_PASSWORD = $RedisPassword
    REDIS_SSL      = "true"
    DB_HOST        = $DbHost
    DB_PORT        = "5432"
    DB_USER        = $DbUser
    DB_PASSWORD    = $DbPassword
    DB_NAME        = $DbName
    DB_SSL         = "true"
    DB_SSL_MODE    = "Require"
    DB_SSL_REJECT_UNAUTHORIZED = "false"
    DATABASE_URL   = "postgres://${DbUser}:${DbPassword}@${DbHost}:5432/${DbName}?sslmode=require"
    COOKIE_SECURE  = "false"
    COOKIE_SAMESITE = "Lax"
}

$SecretValue = $RuntimeConfig | ConvertTo-Json -Compress

az keyvault secret set `
    --vault-name $VaultName `
    --name $SecretName `
    --value $SecretValue | Out-Host

Write-Host "Updated Azure Key Vault secret '$SecretName' in vault '$VaultName'."
