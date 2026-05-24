#!/usr/bin/env pwsh
param(
    [string]$AwsEnv = "terraform/environments/aws",
    [string]$AzureEnv = "terraform/environments/azure",
    [string]$AwsKubeContext = "arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster",
    [string]$AzureKubeContext = "devsecops-voting-aks",
    [string]$PublicationName = "voting_pub",
    [string]$SubscriptionName = "voting_aws_sub",
    [string]$ReplicationUser = "replicator",
    [string]$ReplicationPassword,
    [switch]$DropExistingSubscription
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AwsEnvPath = Join-Path $Root $AwsEnv
$AzureEnvPath = Join-Path $Root $AzureEnv

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command: $Name"
    }
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

function Get-AwsSecretJson {
    param(
        [string]$SecretName,
        [string]$Region
    )

    $secret = aws secretsmanager get-secret-value `
        --region $Region `
        --secret-id $SecretName `
        --query SecretString `
        --output text

    return $secret | ConvertFrom-Json
}

function Invoke-PsqlInCluster {
    param(
        [string]$Context,
        [string]$HostName,
        [string]$Database,
        [string]$User,
        [string]$Password,
        [string]$Sql
    )

    $podName = "pg-client-$([guid]::NewGuid().ToString('N').Substring(0, 10))"
    $conn = "host=$HostName port=5432 dbname=$Database user=$User sslmode=require"
    $Sql | kubectl --context $Context -n default run $podName `
        --rm `
        -i `
        --restart=Never `
        --image=postgres:15-alpine `
        --env="PGPASSWORD=$Password" `
        --command -- psql $conn -v ON_ERROR_STOP=1
}

function Escape-SqlLiteral {
    param([string]$Value)
    return $Value.Replace("'", "''")
}

Require-Command terraform
Require-Command aws
Require-Command az
Require-Command kubectl

Write-Step "Reading Terraform outputs and secrets"
$awsRegion = Get-TerraformOutput -Path $AwsEnvPath -Name "aws_region"
$awsCluster = Get-TerraformOutput -Path $AwsEnvPath -Name "cluster_name"
$awsRdsHost = (Get-TerraformOutput -Path $AwsEnvPath -Name "rds_endpoint").Split(":")[0]
$awsDbSecretName = Get-TerraformOutput -Path $AwsEnvPath -Name "db_secret_name"
$azureResourceGroup = Get-TerraformOutput -Path $AzureEnvPath -Name "resource_group_name"
$azureCluster = Get-TerraformOutput -Path $AzureEnvPath -Name "aks_cluster_name"
$azurePgHost = Get-TerraformOutput -Path $AzureEnvPath -Name "azure_postgres_host"
$azurePgDatabase = Get-TerraformOutput -Path $AzureEnvPath -Name "azure_postgres_database"
$azurePgUser = Get-TerraformOutput -Path $AzureEnvPath -Name "azure_postgres_user"
$keyVaultUri = Get-TerraformOutput -Path $AzureEnvPath -Name "key_vault_uri"
$keyVaultName = ([Uri]$keyVaultUri).Host.Split(".")[0]

$awsDbSecret = Get-AwsSecretJson -SecretName $awsDbSecretName -Region $awsRegion
$awsDbUser = $awsDbSecret.username
$awsDbPassword = $awsDbSecret.password
$awsDbDatabase = $awsDbSecret.database

$appRuntimeSecret = az keyvault secret show `
    --vault-name $keyVaultName `
    --name "voting-app-runtime" `
    --query value `
    --output tsv | ConvertFrom-Json
$azurePgPassword = $appRuntimeSecret.DB_PASSWORD

if (-not $ReplicationPassword) {
    $ReplicationPassword = "repl-$([guid]::NewGuid().ToString('N'))"
    Write-Warning "Generated an in-memory replication password. Store it securely if you need to recreate the subscription."
}

Write-Step "Updating kubeconfig contexts"
aws eks update-kubeconfig --region $awsRegion --name $awsCluster | Out-Host
az aks get-credentials --resource-group $azureResourceGroup --name $azureCluster --overwrite-existing | Out-Host

$replicationPasswordSql = Escape-SqlLiteral $ReplicationPassword

$publisherSql = @"
CREATE TABLE IF NOT EXISTS votes (
  id VARCHAR(255) PRIMARY KEY,
  vote VARCHAR(255) NOT NULL
);

DO `$`$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.votes'::regclass
      AND contype = 'p'
  ) THEN
    ALTER TABLE public.votes ADD PRIMARY KEY (id);
  END IF;
END
`$`$;

DO `$`$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$ReplicationUser') THEN
    CREATE ROLE $ReplicationUser WITH LOGIN PASSWORD '$replicationPasswordSql';
  ELSE
    ALTER ROLE $ReplicationUser WITH LOGIN PASSWORD '$replicationPasswordSql';
  END IF;
END
`$`$;

GRANT rds_replication TO $ReplicationUser;
GRANT CONNECT ON DATABASE $awsDbDatabase TO $ReplicationUser;
GRANT USAGE ON SCHEMA public TO $ReplicationUser;
GRANT SELECT ON TABLE public.votes TO $ReplicationUser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO $ReplicationUser;

DO `$`$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = '$PublicationName') THEN
    CREATE PUBLICATION $PublicationName FOR TABLE votes;
  ELSIF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = '$PublicationName'
      AND schemaname = 'public'
      AND tablename = 'votes'
  ) THEN
    ALTER PUBLICATION $PublicationName ADD TABLE votes;
  END IF;
END
`$`$;
"@

Write-Step "Configuring AWS RDS publisher"
Invoke-PsqlInCluster `
    -Context $AwsKubeContext `
    -HostName $awsRdsHost `
    -Database $awsDbDatabase `
    -User $awsDbUser `
    -Password $awsDbPassword `
    -Sql $publisherSql | Out-Host

$dropSql = ""
if ($DropExistingSubscription) {
    $dropSql = "DROP SUBSCRIPTION IF EXISTS $SubscriptionName;"
}

$subscriberSql = @"
CREATE TABLE IF NOT EXISTS votes (
  id VARCHAR(255) PRIMARY KEY,
  vote VARCHAR(255) NOT NULL
);

$dropSql

DO `$`$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_subscription WHERE subname = '$SubscriptionName') THEN
    CREATE SUBSCRIPTION $SubscriptionName
    CONNECTION 'host=$awsRdsHost port=5432 dbname=$awsDbDatabase user=$ReplicationUser password=$replicationPasswordSql sslmode=require'
    PUBLICATION $PublicationName
    WITH (copy_data = true, create_slot = true, enabled = true);
  END IF;
END
`$`$;
"@

Write-Step "Configuring Azure PostgreSQL subscriber"
Invoke-PsqlInCluster `
    -Context $AzureKubeContext `
    -HostName $azurePgHost `
    -Database $azurePgDatabase `
    -User $azurePgUser `
    -Password $azurePgPassword `
    -Sql $subscriberSql | Out-Host

Write-Step "Logical replication configured"
Write-Host "Publisher:  $awsRdsHost/$awsDbDatabase"
Write-Host "Subscriber: $azurePgHost/$azurePgDatabase"
Write-Host "Publication: $PublicationName"
Write-Host "Subscription: $SubscriptionName"
