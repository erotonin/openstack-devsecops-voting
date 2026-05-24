#!/usr/bin/env pwsh
param(
    [ValidateSet("full-demo")]
    [string]$Environment = "full-demo",
    [switch]$AutoApprove,
    [switch]$SkipValidate,
    [switch]$SkipGitHubConfig,
    [switch]$EnableAzurePostgresStandby,
    [switch]$EnablePostgresLogicalReplication,
    [string]$GitHubRepo = "erotonin/devsecops-voting"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AwsEnv = Join-Path $Root "terraform/environments/aws"
$AzureEnv = Join-Path $Root "terraform/environments/azure"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Invoke-Native {
    param(
        [scriptblock]$Command,
        [string]$ErrorMessage
    )

    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw $ErrorMessage
    }
}

function Get-TerraformOutputRaw {
    param(
        [string]$Name,
        [string]$Default = ""
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $value = terraform output -raw $Name 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $value) {
            return $Default
        }
        return $value
    } catch {
        return $Default
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Invoke-TerraformApply {
    param(
        [string]$Path,
        [string]$Label,
        [string[]]$Targets = @()
    )

    Push-Location $Path
    try {
        Write-Step "$Label terraform init"
        Invoke-Native { terraform init } "$Label terraform init failed"

        if (-not $SkipValidate) {
            Write-Step "$Label terraform fmt/check"
            Invoke-Native { terraform fmt -check -recursive } "$Label terraform fmt failed"

            Write-Step "$Label terraform validate"
            Invoke-Native { terraform validate } "$Label terraform validate failed"
        }

        $targetArgs = @()
        foreach ($target in $Targets) {
            $targetArgs += "-target=$target"
        }

        Write-Step "$Label terraform plan"
        Invoke-Native { terraform plan @targetArgs -out=tfplan } "$Label terraform plan failed"

        Write-Step "$Label terraform apply"
        if ($AutoApprove) {
            Invoke-Native { terraform apply -auto-approve tfplan } "$Label terraform apply failed"
        } else {
            Invoke-Native { terraform apply tfplan } "$Label terraform apply failed"
        }
    } finally {
        Pop-Location
    }
}

function Remove-FailedEksNodeGroup {
    param(
        [string]$ClusterName,
        [string]$NodeGroupName,
        [string]$Region
    )

    $status = aws eks describe-nodegroup `
        --cluster-name $ClusterName `
        --nodegroup-name $NodeGroupName `
        --region $Region `
        --query "nodegroup.status" `
        --output text 2>$null

    if ($LASTEXITCODE -ne 0 -or -not $status) {
        return
    }

    if ($status -ne "CREATE_FAILED") {
        Write-Host "EKS node group $NodeGroupName status is $status; no cleanup needed."
        return
    }

    Write-Step "Deleting failed EKS node group $NodeGroupName before retry"
    Invoke-Native {
        aws eks delete-nodegroup `
            --cluster-name $ClusterName `
            --nodegroup-name $NodeGroupName `
            --region $Region
    } "Failed to request failed EKS node group deletion"

    Invoke-Native {
        aws eks wait nodegroup-deleted `
            --cluster-name $ClusterName `
            --nodegroup-name $NodeGroupName `
            --region $Region
    } "Failed while waiting for failed EKS node group deletion"
}

function Update-EksKubeconfig {
    param(
        [string]$Path
    )

    Push-Location $Path
    try {
        $awsRegion = Get-TerraformOutputRaw -Name "aws_region" -Default "us-east-1"
        $eksCluster = Get-TerraformOutputRaw -Name "cluster_name"
        if (-not $eksCluster) {
            throw "Missing Terraform output: cluster_name"
        }
        Invoke-Native { aws eks update-kubeconfig --region $awsRegion --name $eksCluster } "Failed to update EKS kubeconfig"
    } finally {
        Pop-Location
    }
}

function Update-AksKubeconfig {
    param(
        [string]$Path
    )

    Push-Location $Path
    try {
        $rgName = Get-TerraformOutputRaw -Name "resource_group_name"
        $aksName = Get-TerraformOutputRaw -Name "aks_cluster_name"
        if ($rgName -and $aksName) {
            Invoke-Native { az aks get-credentials --resource-group $rgName --name $aksName --overwrite-existing } "Failed to update AKS kubeconfig"
        }
    } finally {
        Pop-Location
    }
}

function Wait-KubernetesServiceHostname {
    param(
        [string]$Namespace,
        [string]$Service,
        [int]$TimeoutSeconds = 600
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $hostname = kubectl -n $Namespace get svc $Service -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 2>$null
        if ($LASTEXITCODE -eq 0 -and $hostname) {
            return $hostname
        }

        $ip = kubectl -n $Namespace get svc $Service -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>$null
        if ($LASTEXITCODE -eq 0 -and $ip) {
            return $ip
        }

        Start-Sleep -Seconds 10
    } while ((Get-Date) -lt $deadline)

    throw "Timed out waiting for $Namespace/$Service LoadBalancer hostname"
}

function Update-GitHubRepositoryConfig {
    if ($SkipGitHubConfig) {
        Write-Step "Skipping GitHub repository configuration"
        return
    }

    if (-not (Get-Command gh -ErrorAction SilentlyContinue) -and -not (Test-Path "C:\Program Files\GitHub CLI\gh.exe")) {
        Write-Warning "GitHub CLI is not installed; skipping GitHub repository configuration."
        return
    }

    Write-Step "Configuring GitHub repository secrets and staging URL"
    Update-EksKubeconfig -Path $AwsEnv
    $voteHostname = Wait-KubernetesServiceHostname -Namespace "voting" -Service "vote"
    $stagingUrl = "http://$voteHostname"

    Invoke-Native {
        & (Join-Path $Root "scripts/configure-github-repo.ps1") `
            -Repo $GitHubRepo `
            -StagingUrl $stagingUrl
    } "Failed to configure GitHub repository variables and secrets"
}

Write-Step "Checking local prerequisites"
@("terraform", "aws", "az", "kubectl", "helm") | ForEach-Object { Assert-Command $_ }

Write-Step "Checking AWS identity"
aws sts get-caller-identity | Out-Host

Write-Step "Checking Azure identity"
az account show --output table | Out-Host

if ($EnableAzurePostgresStandby) {
    Write-Step "Enabling Azure PostgreSQL standby Terraform resources"
    $env:TF_VAR_enable_azure_postgres_standby = "true"
}

if ($EnablePostgresLogicalReplication) {
    Write-Step "Enabling AWS RDS logical replication Terraform parameters"
    $env:TF_VAR_enable_postgres_logical_replication = "true"
}

# First create Azure networking and VPN gateway so AWS can read the Azure VPN public IP.
Invoke-TerraformApply -Path $AzureEnv -Label "Azure VPN gateway bootstrap" -Targets @(
    "module.azure_networking",
    "azurerm_public_ip.vpn_ip",
    "azurerm_virtual_network_gateway.vng"
)

Remove-FailedEksNodeGroup -ClusterName "voting-app-cluster" -NodeGroupName "voting-app-cluster-ng" -Region "us-east-1"

Invoke-TerraformApply -Path $AwsEnv -Label "AWS primary foundation" -Targets @(
    "module.networking",
    "module.security_groups",
    "module.eks",
    "module.ecr",
    "module.db_secret",
    "module.redis_secret",
    "module.rds",
    "aws_cloudwatch_log_group.redis",
    "module.elasticache",
    "module.app_runtime_secret",
    "module.external_secrets_irsa",
    "aws_iam_openid_connect_provider.github",
    "aws_iam_role.github_actions",
    "aws_iam_role_policy.github_actions_ecr",
    "aws_customer_gateway.cgw",
    "aws_vpn_gateway.vgw",
    "aws_vpn_connection.vpn",
    "aws_vpn_gateway_route_propagation.private",
    "aws_vpn_gateway_route_propagation.database"
)

Update-EksKubeconfig -Path $AwsEnv

Invoke-TerraformApply -Path $AwsEnv -Label "AWS primary controllers" -Targets @(
    "kubernetes_namespace.voting",
    "helm_release.argocd",
    "helm_release.external_secrets",
    "helm_release.gatekeeper",
    "helm_release.policy_controller",
    "helm_release.metrics_server",
    "helm_release.kube_prometheus_stack",
    "helm_release.loki",
    "helm_release.promtail",
    "helm_release.falco"
)

Write-Step "Applying AWS Gatekeeper policies"
Invoke-Native { & (Join-Path $Root "scripts/apply-gatekeeper-policies.ps1") } "Failed to apply AWS Gatekeeper policies"

Invoke-TerraformApply -Path $AwsEnv -Label "AWS primary manifests"

# Finish Azure after AWS has written tunnel details to remote state.
$azureWarmStandbyTargets = @(
    "module.azure_networking",
    "azurerm_public_ip.vpn_ip",
    "azurerm_virtual_network_gateway.vng",
    "azurerm_local_network_gateway.lng",
    "azurerm_virtual_network_gateway_connection.vpn_conn",
    "module.aks",
    "azurerm_container_registry.acr",
    "random_string.acr_suffix",
    "azurerm_role_assignment.aks_acr_pull",
    "azurerm_key_vault.app",
    "azurerm_role_assignment.current_key_vault_admin",
    "random_password.azure_db_password",
    "random_password.azure_redis_password",
    "azurerm_key_vault_secret.app_runtime",
    "module.external_secrets_workload_identity"
)

if ($EnableAzurePostgresStandby) {
    $azureWarmStandbyTargets += @(
        "azurerm_private_dns_zone.postgres[0]",
        "azurerm_private_dns_zone_virtual_network_link.postgres[0]",
        "azurerm_postgresql_flexible_server.standby[0]",
        "azurerm_postgresql_flexible_server_database.voting[0]",
        "azurerm_postgresql_flexible_server_configuration.wal_level[0]"
    )
}

Invoke-TerraformApply -Path $AzureEnv -Label "Azure warm standby foundation" -Targets $azureWarmStandbyTargets

Update-AksKubeconfig -Path $AzureEnv

Invoke-TerraformApply -Path $AzureEnv -Label "Azure warm standby controllers" -Targets @(
    "kubernetes_namespace.voting",
    "helm_release.argocd",
    "helm_release.external_secrets"
)

Invoke-TerraformApply -Path $AzureEnv -Label "Azure warm standby manifests"

Write-Step "Updating kubeconfig files"
Update-EksKubeconfig -Path $AwsEnv
Update-AksKubeconfig -Path $AzureEnv

Update-GitHubRepositoryConfig

Write-Step "Infrastructure apply completed"
Write-Host "Next: verify ArgoCD, ESO, Gatekeeper, monitoring, logging, Falco, and the GitHub Actions staging URL." -ForegroundColor Green
