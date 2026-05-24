#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory = $true)]
    [string]$ImageTag,

    [Parameter(Mandatory = $true)]
    [string]$EcrRegistry,

    [string]$AcrLoginServer = "",

    [string]$AwsValuesPath = "k8s/values-prod.yaml",
    [string]$AzureValuesPath = "k8s/values-azure.yaml"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Resolve-RepoPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $Root $Path
}

function Update-ServiceImage {
    param(
        [string]$Content,
        [string]$Service,
        [string]$Repository,
        [string]$Tag
    )

    $escapedService = [regex]::Escape($Service)
    $escapedRepository = $Repository -replace "\\", "\\"
    $pattern = "(?ms)(  ${escapedService}:\r?\n    repository: ).*?(\r?\n    tag: ).*?(\r?\n)"
    $replacement = "`${1}${escapedRepository}`${2}${Tag}`${3}"
    return [regex]::Replace($Content, $pattern, $replacement)
}

function Update-ValuesFile {
    param(
        [string]$Path,
        [hashtable]$Repositories,
        [string]$Tag
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Values file not found: $Path"
    }

    $content = Get-Content -LiteralPath $Path -Raw
    foreach ($service in @("vote", "result", "worker")) {
        $content = Update-ServiceImage -Content $content -Service $service -Repository $Repositories[$service] -Tag $Tag
    }

    Set-Content -LiteralPath $Path -Value $content -NoNewline
}

$awsRepositories = @{
    vote   = "$EcrRegistry/voting-app-vote"
    result = "$EcrRegistry/voting-app-result"
    worker = "$EcrRegistry/voting-app-worker"
}

Update-ValuesFile -Path (Resolve-RepoPath $AwsValuesPath) -Repositories $awsRepositories -Tag $ImageTag

if ($AcrLoginServer) {
    $azureRepositories = @{
        vote   = "$AcrLoginServer/voting-app-vote"
        result = "$AcrLoginServer/voting-app-result"
        worker = "$AcrLoginServer/voting-app-worker"
    }

    Update-ValuesFile -Path (Resolve-RepoPath $AzureValuesPath) -Repositories $azureRepositories -Tag $ImageTag
}
