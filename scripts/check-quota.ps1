param(
    [string]$AwsRegion = "us-east-1",
    [string]$AzureLocation = "southeastasia"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

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

function Invoke-NativeCapture {
    param(
        [scriptblock]$Command
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $Command 2>$null
        $exitCode = $LASTEXITCODE
        [pscustomobject]@{
            Output   = $output
            ExitCode = $exitCode
        }
    } catch {
        [pscustomobject]@{
            Output   = $null
            ExitCode = 1
        }
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Get-AwsQuota {
    param(
        [string]$ServiceCode,
        [string]$QuotaCode,
        [string]$Name
    )

    $result = Invoke-NativeCapture {
        aws service-quotas get-service-quota `
            --service-code $ServiceCode `
            --quota-code $QuotaCode `
            --region $AwsRegion `
            --query "Quota.Value" `
            --output text
    }

    if ($result.ExitCode -ne 0 -or -not $result.Output) {
        [pscustomobject]@{ Cloud = "AWS"; Name = $Name; Limit = "unknown"; Region = $AwsRegion }
    } else {
        [pscustomobject]@{ Cloud = "AWS"; Name = $Name; Limit = $result.Output; Region = $AwsRegion }
    }
}

function Get-AzureUsage {
    param(
        [string]$NamePattern,
        [string]$Name
    )

    $result = Invoke-NativeCapture {
        az vm list-usage --location $AzureLocation --query "[?contains(name.value, '$NamePattern')].[name.localizedValue,currentValue,limit]" --output tsv
    }

    if ($result.ExitCode -ne 0 -or -not $result.Output) {
        [pscustomobject]@{ Cloud = "Azure"; Name = $Name; Usage = "unknown"; Limit = "unknown"; Location = $AzureLocation }
        return
    }

    $result.Output -split "`n" | ForEach-Object {
        $parts = $_ -split "`t"
        [pscustomobject]@{
            Cloud    = "Azure"
            Name     = $parts[0]
            Usage    = $parts[1]
            Limit    = $parts[2]
            Location = $AzureLocation
        }
    }
}

Require-Command aws
Require-Command az

Write-Step "Checking AWS identity"
aws sts get-caller-identity --query "Arn" --output text | Out-Host

Write-Step "Checking Azure identity"
az account show --query "{name:name, subscription:id, tenant:tenantId}" --output table | Out-Host

Write-Step "AWS quota snapshot"
@(
    Get-AwsQuota -ServiceCode "vpc" -QuotaCode "L-F678F1CE" -Name "VPCs per Region"
    Get-AwsQuota -ServiceCode "vpc" -QuotaCode "L-0263D0A3" -Name "Elastic IP addresses per Region"
    Get-AwsQuota -ServiceCode "vpc" -QuotaCode "L-FE5A380F" -Name "NAT gateways per Availability Zone"
    Get-AwsQuota -ServiceCode "ec2" -QuotaCode "L-1216C47A" -Name "Running On-Demand Standard instances"
    Get-AwsQuota -ServiceCode "eks" -QuotaCode "L-1194D53C" -Name "EKS clusters per Region"
) | Format-Table -AutoSize

Write-Step "Azure quota snapshot"
@(
    Get-AzureUsage -NamePattern "standardDSv3Family" -Name "Standard DSv3 Family vCPUs"
    Get-AzureUsage -NamePattern "cores" -Name "Total Regional vCPUs"
) | Format-Table -AutoSize

Write-Step "Manual checks before apply"
Write-Host "- AWS: VPN gateway, NAT gateway, EIP, EKS node instance quota."
Write-Host "- Azure: AKS VM family vCPU quota and public IP quota in $AzureLocation."
Write-Host "- If any quota is near zero, request increase before running scripts/infra-up.ps1."
