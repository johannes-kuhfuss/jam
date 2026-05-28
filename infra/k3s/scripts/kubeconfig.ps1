$ErrorActionPreference = "Stop"

$GeneratedDirPath = "$PSScriptRoot\..\generated"
if (-not (Test-Path $GeneratedDirPath)) {
    throw "Generated kubeconfig directory not found at $GeneratedDirPath. Run install.ps1 first."
}

$GeneratedDir = Resolve-Path $GeneratedDirPath
$Kubeconfig = Get-ChildItem -Path $GeneratedDir -Filter "*.yaml" | Sort-Object Name | Select-Object -First 1

if ($null -eq $Kubeconfig) {
    throw "No kubeconfig files found in $GeneratedDir. Run install.ps1 first."
}

$env:KUBECONFIG = $Kubeconfig.FullName
Write-Host "KUBECONFIG=$($Kubeconfig.FullName)"
