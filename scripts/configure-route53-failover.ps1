#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory = $true)]
    [string]$HostedZoneId,

    [Parameter(Mandatory = $true)]
    [string]$RecordName,

    [string]$AwsKubeContext = "arn:aws:eks:us-east-1:800557027783:cluster/voting-app-cluster",
    [string]$AzureKubeContext = "devsecops-voting-aks",
    [string]$Namespace = "voting",
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

Require-Command aws
Require-Command kubectl

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

Write-Step "Creating Route53 health check for AWS primary"
$healthCheckConfig = @{
    CallerReference  = $callerReference
    HealthCheckConfig = @{
        Type              = "HTTP"
        FullyQualifiedDomainName = $healthFqdn
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
$recordPayload = @{
    Comment = "DevSecOps voting app active-passive DNS failover"
    Changes = @(
        @{
            Action = "UPSERT"
            ResourceRecordSet = @{
                Name = $RecordName
                Type = "CNAME"
                SetIdentifier = "aws-primary"
                Failover = "PRIMARY"
                TTL = $Ttl
                ResourceRecords = @(@{ Value = $PrimaryEndpoint })
                HealthCheckId = $healthCheckId
            }
        },
        @{
            Action = "UPSERT"
            ResourceRecordSet = @{
                Name = $RecordName
                Type = "CNAME"
                SetIdentifier = "azure-standby"
                Failover = "SECONDARY"
                TTL = $Ttl
                ResourceRecords = @(@{ Value = $SecondaryEndpoint })
            }
        }
    )
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
Write-Host "Primary: $PrimaryEndpoint"
Write-Host "Secondary: $SecondaryEndpoint"
Write-Host "HealthCheckId: $healthCheckId"
Write-Host "If compute failover is required, connect the optional SNS alarm action to a Lambda/Azure Function that runs scripts/dr-failover.ps1."
