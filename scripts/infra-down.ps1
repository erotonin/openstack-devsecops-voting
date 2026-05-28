#!/usr/bin/env pwsh
param(
    [ValidateSet("full-demo")]
    [string]$Environment = "full-demo",
    [switch]$AutoApprove,
    [switch]$SkipKubernetesCleanup
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AwsEnv = Join-Path $Root "terraform/environments/aws"
$AzureEnv = Join-Path $Root "terraform/environments/azure"
$AwsRegion = "us-east-1"
$ProjectTagValue = "devsecops-voting"
$RdsInstanceIdentifier = "devsecops-voting-postgres"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-TerraformDestroy {
    param(
        [string]$Path,
        [string]$Label,
        [switch]$RemoveRuntimeState
    )

    Push-Location $Path
    try {
        Write-Step "$Label terraform init"
        terraform init

        if ($RemoveRuntimeState) {
            Remove-TerraformRuntimeState -Path $Path -Label $Label
        }

        Write-Step "$Label terraform destroy"
        if ($AutoApprove) {
            terraform destroy -refresh=false -auto-approve
        } else {
            terraform destroy -refresh=false
        }
    } finally {
        Pop-Location
    }
}

function Remove-KubernetesResources {
    if ($SkipKubernetesCleanup) {
        Write-Step "Skipping Kubernetes cleanup"
        return
    }

    Write-Step "Pre-destroy Kubernetes cleanup"
    $namespaces = @("voting-staging", "voting-production", "voting", "argocd", "monitoring", "logging", "falco", "external-secrets", "gatekeeper-system", "cosign-system", "kyverno")

    function Invoke-KubectlBestEffort {
        param(
            [string[]]$Arguments,
            [string]$WarningMessage
        )

        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & kubectl @Arguments 2>$null | Out-Host
            if ($LASTEXITCODE -ne 0) {
                Write-Warning $WarningMessage
            }
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
    }

    foreach ($ns in $namespaces) {
        Invoke-KubectlBestEffort -Arguments @("delete", "applications.argoproj.io", "--all", "-n", $ns, "--ignore-not-found=true") -WarningMessage "Could not delete ArgoCD applications in namespace $ns; continuing."
        Invoke-KubectlBestEffort -Arguments @("delete", "ingress", "--all", "-n", $ns, "--ignore-not-found=true") -WarningMessage "Could not delete ingresses in namespace $ns; continuing."
        Invoke-KubectlBestEffort -Arguments @("delete", "svc", "--all", "-n", $ns, "--ignore-not-found=true") -WarningMessage "Could not delete services in namespace $ns; continuing."
    }

    foreach ($ns in $namespaces) {
        Invoke-KubectlBestEffort -Arguments @("delete", "namespace", $ns, "--ignore-not-found=true", "--timeout=90s") -WarningMessage "Namespace $ns was not fully deleted within 90s; Terraform destroy will continue."
    }
}

function Remove-TerraformRuntimeState {
    param(
        [string]$Path,
        [string]$Label
    )

    Write-Step "$Label remove Kubernetes/Helm runtime state entries"
    $stateEntries = terraform state list 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $stateEntries) {
        Write-Host "No Terraform state entries found for $Label."
        return
    }

    $runtimeEntries = $stateEntries | Where-Object {
        $_ -match '^helm_release\.' -or
        $_ -match '^kubernetes_' -or
        $_ -match '^module\..*\.helm_release\.' -or
        $_ -match '^module\..*\.kubernetes_'
    }

    foreach ($entry in $runtimeEntries) {
        Write-Host "Removing Terraform state entry: $entry"
        terraform state rm $entry | Out-Host
    }
}

function Remove-EcrImages {
    Write-Step "Cleaning ECR images before Terraform destroy"
    $repos = @("voting-app-vote", "voting-app-result", "voting-app-worker")

    foreach ($repo in $repos) {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $images = & aws ecr list-images --repository-name $repo --query 'imageIds' --output json 2>$null
            $listExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        if ($listExitCode -ne 0 -or -not $images -or $images -eq "[]") {
            Write-Host "No ECR images to delete for $repo, or repository already removed."
            continue
        }

        $tmp = New-TemporaryFile
        try {
            Set-Content -LiteralPath $tmp -Value $images
            $previousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                & aws ecr batch-delete-image --repository-name $repo --image-ids "file://$tmp" 2>$null | Out-Host
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Could not delete ECR images for $repo; continuing."
                }
            } finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }
        } finally {
            Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
        }
    }
}

function Remove-RetainedRdsBackups {
    Write-Step "Cleaning retained RDS automated backups"

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $backupResourceIds = & aws rds describe-db-instance-automated-backups `
            --region $AwsRegion `
            --db-instance-identifier $RdsInstanceIdentifier `
            --query "DBInstanceAutomatedBackups[].DbiResourceId" `
            --output text 2>$null
        $describeExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($describeExitCode -ne 0 -or -not $backupResourceIds -or $backupResourceIds -eq "None") {
        Write-Host "No retained RDS automated backups found."
        return
    }

    foreach ($resourceId in ($backupResourceIds -split "\s+")) {
        if (-not $resourceId) {
            continue
        }

        Write-Host "Deleting retained RDS automated backup: $resourceId"
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & aws rds delete-db-instance-automated-backup `
                --region $AwsRegion `
                --dbi-resource-id $resourceId 2>$null | Out-Host
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Could not delete retained RDS automated backup $resourceId; continuing."
            }
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
    }
}

function Remove-ProjectSecrets {
    Write-Step "Force deleting project Secrets Manager secrets"

    $secretNames = @(
        "devsecops-voting/app-runtime",
        "devsecops-voting/db",
        "devsecops-voting/redis",
        "devsecops-voting/postgres-replication"
    )

    foreach ($secretName in $secretNames) {
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & aws secretsmanager delete-secret `
                --region $AwsRegion `
                --secret-id $secretName `
                --force-delete-without-recovery 2>$null | Out-Host

            if ($LASTEXITCODE -ne 0) {
                Write-Host "Secret $secretName is already deleted or not found."
            }
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
    }
}

function Set-ProjectKmsDeletionWindow {
    Write-Step "Shortening pending KMS deletion windows"

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $keyArns = & aws resourcegroupstaggingapi get-resources `
            --region $AwsRegion `
            --resource-type-filters kms:key `
            --tag-filters "Key=Project,Values=$ProjectTagValue" `
            --query "ResourceTagMappingList[].ResourceARN" `
            --output text 2>$null
        $listExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($listExitCode -ne 0 -or -not $keyArns -or $keyArns -eq "None") {
        Write-Host "No project KMS keys found."
        return
    }

    foreach ($keyArn in ($keyArns -split "\s+")) {
        if (-not $keyArn) {
            continue
        }

        $keyState = & aws kms describe-key `
            --region $AwsRegion `
            --key-id $keyArn `
            --query "KeyMetadata.KeyState" `
            --output text 2>$null

        if ($LASTEXITCODE -ne 0 -or $keyState -ne "PendingDeletion") {
            continue
        }

        Write-Host "Rescheduling KMS key deletion to 7 days: $keyArn"
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & aws kms cancel-key-deletion --region $AwsRegion --key-id $keyArn 2>$null | Out-Host
            if ($LASTEXITCODE -eq 0) {
                & aws kms schedule-key-deletion --region $AwsRegion --key-id $keyArn --pending-window-in-days 7 2>$null | Out-Host
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Could not reschedule KMS deletion for $keyArn; continuing."
                }
            } else {
                Write-Warning "Could not cancel existing KMS deletion schedule for $keyArn; continuing."
            }
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
    }
}

Write-Step "Destroy safety check"
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "This will destroy the full demo infrastructure managed by Terraform." -ForegroundColor Yellow

if (-not $AutoApprove) {
    $answer = Read-Host "Type DESTROY to continue"
    if ($answer -ne "DESTROY") {
        throw "Destroy cancelled."
    }
}

Remove-KubernetesResources
Remove-EcrImages

Invoke-TerraformDestroy -Path $AwsEnv -Label "AWS primary" -RemoveRuntimeState
Invoke-TerraformDestroy -Path $AzureEnv -Label "Azure warm standby" -RemoveRuntimeState

Remove-RetainedRdsBackups
Remove-ProjectSecrets
Set-ProjectKmsDeletionWindow

Write-Step "Post-destroy reminder"
Write-Host "Check for remaining cost-bearing resources: Load Balancers, NAT Gateways, EKS/AKS nodes, RDS, ElastiCache, VPN Gateways, public IPs, disks, snapshots." -ForegroundColor Green
