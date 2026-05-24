#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory = $true)]
    [string]$ImageTag,

    [Parameter(Mandatory = $true)]
    [string]$EcrRegistry,

    [string]$AcrLoginServer = "",

    [string]$AwsValuesPath = "k8s/values-prod.yaml",
    [string]$AzureValuesPath = "k8s/values-azure.yaml",

    [switch]$ResolveDigests
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
        [string]$Tag,
        [string]$Digest = ""
    )

    $escapedService = [regex]::Escape($Service)
    $escapedRepository = $Repository -replace "\\", "\\"
    $digestLine = if ($Digest) { "    digest: $Digest" } else { '    digest: ""' }
    $pattern = "(?ms)(  ${escapedService}:\r?\n    repository: ).*?(\r?\n    tag: ).*?(\r?\n)(    digest: .*?(\r?\n))?"
    $replacement = "`${1}${escapedRepository}`${2}${Tag}`${3}${digestLine}`${3}"
    return [regex]::Replace($Content, $pattern, $replacement)
}

function Update-ValuesFile {
    param(
        [string]$Path,
        [hashtable]$Repositories,
        [string]$Tag,
        [hashtable]$Digests = @{}
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Values file not found: $Path"
    }

    $content = Get-Content -LiteralPath $Path -Raw
    foreach ($service in @("vote", "result", "worker")) {
        $digest = if ($Digests.ContainsKey($service)) { $Digests[$service] } else { "" }
        $content = Update-ServiceImage -Content $content -Service $service -Repository $Repositories[$service] -Tag $Tag -Digest $digest
    }

    Set-Content -LiteralPath $Path -Value $content -NoNewline
}

function Resolve-EcrDigest {
    param(
        [string]$RepositoryName,
        [string]$Tag
    )

    return (aws ecr describe-images `
            --repository-name $RepositoryName `
            --image-ids "imageTag=$Tag" `
            --query "imageDetails[0].imageDigest" `
            --output text).Trim()
}

function Resolve-AcrDigest {
    param(
        [string]$AcrLoginServer,
        [string]$RepositoryName,
        [string]$Tag
    )

    $acrName = $AcrLoginServer -replace "\.azurecr\.io$", ""
    return (az acr repository show `
            --name $acrName `
            --image "${RepositoryName}:$Tag" `
            --query "digest" `
            --output tsv).Trim()
}

$awsRepositories = @{
    vote   = "$EcrRegistry/voting-app-vote"
    result = "$EcrRegistry/voting-app-result"
    worker = "$EcrRegistry/voting-app-worker"
}

$awsDigests = @{}
if ($ResolveDigests) {
    foreach ($service in @("vote", "result", "worker")) {
        $awsDigests[$service] = Resolve-EcrDigest -RepositoryName "voting-app-$service" -Tag $ImageTag
    }
}

Update-ValuesFile -Path (Resolve-RepoPath $AwsValuesPath) -Repositories $awsRepositories -Tag $ImageTag -Digests $awsDigests

if ($AcrLoginServer) {
    $azureRepositories = @{
        vote   = "$AcrLoginServer/voting-app-vote"
        result = "$AcrLoginServer/voting-app-result"
        worker = "$AcrLoginServer/voting-app-worker"
    }

    $azureDigests = @{}
    if ($ResolveDigests) {
        foreach ($service in @("vote", "result", "worker")) {
            $azureDigests[$service] = Resolve-AcrDigest -AcrLoginServer $AcrLoginServer -RepositoryName "voting-app-$service" -Tag $ImageTag
        }
    }

    Update-ValuesFile -Path (Resolve-RepoPath $AzureValuesPath) -Repositories $azureRepositories -Tag $ImageTag -Digests $azureDigests
}
