#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

& (Join-Path $Root "scripts/infra-down.ps1") -Environment full-demo @args
