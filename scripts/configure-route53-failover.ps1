#!/usr/bin/env pwsh
param(
    [string]$HostedZoneId,

    [Parameter(Mandatory = $true)]
    [string]$RecordName,

    [string]$AwsKubeContext = "arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster",
    [string]$AzureKubeContext = "devsecops-voting-aks",
    [string]$Namespace = "voting-production",
    [string]$ServiceName = "vote",
    [string]$HealthPath = "/healthz",
    [int]$Ttl = 30,
    [string]$PrimaryEndpoint,
    [string]$SecondaryEndpoint,
    [string]$FailureSnsTopicArn
)

$ErrorActionPreference = "Stop"

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

function Get-ServiceEndpoint {
    param(
        [string]$Context,
        [string]$Namespace,
        [string]$ServiceName
    )

    $hostname = kubectl --context $Context -n $Namespace get svc $ServiceName -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 2>$null
    if ($hostname) {
        return $hostname.Trim()
    }

    $ip = kubectl --context $Context -n $Namespace get svc $ServiceName -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>$null
    if ($ip) {
        return $ip.Trim()
    }
    throw "Service $Namespace/$ServiceName in context $Context does not have a public LoadBalancer endpoint. If the service is private (e.g. internal Azure LB or App Gateway), you must explicitly provide its endpoint using the -PrimaryEndpoint or -SecondaryEndpoint parameter."
}

function Invoke-AwsJson {
    param(
        [string[]]$Arguments,
        [hashtable]$Payload
    )

    $tmp = New-TemporaryFile
    try {
        $json = $Payload | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($tmp.FullName, $json, [System.Text.UTF8Encoding]::new($false))
        aws @Arguments "file://$($tmp.FullName)"
    } finally {
        Remove-Item -LiteralPath $tmp.FullName -ErrorAction SilentlyContinue
    }
}

function Test-IpAddress {
    param([string]$Value)
    $ip = $null
    return [System.Net.IPAddress]::TryParse($Value, [ref]$ip)
}

function Normalize-DnsName {
    param([string]$Value)
    return $Value.TrimEnd(".") + "."
}

function Get-HostedZoneForRecord {
    param([string]$RecordName)

    $record = $RecordName.TrimEnd(".")
    $zones = (aws route53 list-hosted-zones --output json | ConvertFrom-Json).HostedZones
    $matches = @($zones | Where-Object {
            $zoneName = $_.Name.TrimEnd(".")
            $record -eq $zoneName -or $record.EndsWith(".$zoneName")
        } | Sort-Object { $_.Name.Length } -Descending)

    if (-not $matches -or $matches.Count -eq 0) {
        throw "No Route53 hosted zone matches '$RecordName'. Create/import a hosted zone first, or pass -HostedZoneId explicitly."
    }

    $zone = $matches[0]
    return [pscustomobject]@{
        Id   = ($zone.Id -replace "^/hostedzone/", "")
        Name = $zone.Name.TrimEnd(".")
    }
}

function New-EndpointRecord {
    param(
        [string]$Endpoint,
        [string]$Role,
        [string]$RecordName
    )

    if (-not (Test-IpAddress $Endpoint)) {
        return [pscustomobject]@{
            Value          = $Endpoint
            HelperRecordSet = $null
        }
    }

    $helperName = Normalize-DnsName "$Role-$($RecordName.TrimEnd('.'))"
    return [pscustomobject]@{
        Value          = $helperName
        HelperRecordSet = @{
            Name            = $helperName
            Type            = "A"
            TTL             = $Ttl
            ResourceRecords = @(@{ Value = $Endpoint })
        }
    }
}

Require-Command aws
Require-Command kubectl

$zone = $null
if (-not $HostedZoneId) {
    Write-Step "Auto-detecting Route53 hosted zone for $RecordName"
    $zone = Get-HostedZoneForRecord -RecordName $RecordName
    $HostedZoneId = $zone.Id
}
else {
    $zone = [pscustomobject]@{ Id = $HostedZoneId; Name = "" }
}

if (-not $PrimaryEndpoint) {
    Write-Step "Reading AWS primary LoadBalancer endpoint"
    $PrimaryEndpoint = Get-ServiceEndpoint -Context $AwsKubeContext -Namespace $Namespace -ServiceName $ServiceName
}

if (-not $SecondaryEndpoint) {
    Write-Step "Reading Azure standby LoadBalancer endpoint"
    $SecondaryEndpoint = Get-ServiceEndpoint -Context $AzureKubeContext -Namespace $Namespace -ServiceName $ServiceName
}

$RecordName = $RecordName.TrimEnd(".") + "."
$healthFqdn = $PrimaryEndpoint.TrimEnd("/")
$callerReference = "devsecops-voting-$($RecordName)-$(Get-Date -Format yyyyMMddHHmmss)"
$primaryRecord = New-EndpointRecord -Endpoint $PrimaryEndpoint -Role "primary" -RecordName $RecordName
$secondaryRecord = New-EndpointRecord -Endpoint $SecondaryEndpoint -Role "secondary" -RecordName $RecordName

Write-Step "Creating Route53 health check for AWS primary"
$healthTarget = if (Test-IpAddress $healthFqdn) {
    @{ IPAddress = $healthFqdn }
}
else {
    @{ FullyQualifiedDomainName = $healthFqdn }
}

$healthCheckConfig = @{
    CallerReference  = $callerReference
    HealthCheckConfig = $healthTarget + @{
        Type              = "HTTP"
        Port              = 80
        ResourcePath      = $HealthPath
        RequestInterval   = 10
        FailureThreshold  = 3
        EnableSNI         = $false
    }
}

$healthCheck = Invoke-AwsJson -Arguments @("route53", "create-health-check", "--cli-input-json") -Payload $healthCheckConfig | ConvertFrom-Json
$healthCheckId = $healthCheck.HealthCheck.Id

Write-Step "Upserting Route53 failover CNAME records"
$changes = @()
foreach ($helperRecordSet in @($primaryRecord.HelperRecordSet, $secondaryRecord.HelperRecordSet)) {
    if ($helperRecordSet) {
        $changes += @{
            Action            = "UPSERT"
            ResourceRecordSet = $helperRecordSet
        }
    }
}

$changes += @(
    @{
        Action            = "UPSERT"
        ResourceRecordSet = @{
            Name            = $RecordName
            Type            = "CNAME"
            SetIdentifier   = "aws-primary"
            Failover        = "PRIMARY"
            TTL             = $Ttl
            ResourceRecords = @(@{ Value = $primaryRecord.Value })
            HealthCheckId   = $healthCheckId
        }
    },
    @{
        Action            = "UPSERT"
        ResourceRecordSet = @{
            Name            = $RecordName
            Type            = "CNAME"
            SetIdentifier   = "azure-standby"
            Failover        = "SECONDARY"
            TTL             = $Ttl
            ResourceRecords = @(@{ Value = $secondaryRecord.Value })
        }
    }
)

$recordPayload = @{
    Comment = "DevSecOps voting app active-passive DNS failover"
    Changes = $changes
}

Invoke-AwsJson -Arguments @("route53", "change-resource-record-sets", "--hosted-zone-id", $HostedZoneId, "--change-batch") -Payload $recordPayload | Out-Host

if ($FailureSnsTopicArn) {
    Write-Step "Creating CloudWatch alarm for failover automation hook"
    aws cloudwatch put-metric-alarm `
        --alarm-name "devsecops-voting-primary-healthcheck-failed" `
        --namespace "AWS/Route53" `
        --metric-name "HealthCheckStatus" `
        --dimensions "Name=HealthCheckId,Value=$healthCheckId" `
        --statistic Minimum `
        --period 60 `
        --evaluation-periods 1 `
        --threshold 1 `
        --comparison-operator LessThanThreshold `
        --alarm-actions $FailureSnsTopicArn `
        --region us-east-1 | Out-Host
}

Write-Step "Route53 failover configured"
Write-Host "Record: $RecordName"
Write-Host "HostedZoneId: $HostedZoneId"
Write-Host "Primary: $PrimaryEndpoint"
Write-Host "Secondary: $SecondaryEndpoint"
Write-Host "HealthCheckId: $healthCheckId"
Write-Host "If compute failover is required, connect the optional SNS alarm action to a Lambda/Azure Function that runs scripts/dr-failover.ps1."
