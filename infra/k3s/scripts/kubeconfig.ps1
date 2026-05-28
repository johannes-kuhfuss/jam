$ErrorActionPreference = "Stop"

$GeneratedDir = Resolve-Path "$PSScriptRoot\..\generated"
$Kubeconfig = Join-Path $GeneratedDir "jam-k3s-01.yaml"

if (-not (Test-Path $Kubeconfig)) {
    throw "Kubeconfig not found at $Kubeconfig. Run install.ps1 first."
}

$env:KUBECONFIG = $Kubeconfig
Write-Host "KUBECONFIG=$Kubeconfig"
