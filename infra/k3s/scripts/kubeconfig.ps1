$ErrorActionPreference = "Stop"

$GeneratedDirPath = "$PSScriptRoot\..\generated"
$KubeDir = Join-Path $HOME ".kube"
$TargetKubeconfig = Join-Path $KubeDir "config"

if (-not (Test-Path $GeneratedDirPath)) {
    throw "Generated kubeconfig directory not found at $GeneratedDirPath. Run install.ps1 first."
}

$GeneratedDir = Resolve-Path $GeneratedDirPath
$Kubeconfig = Get-ChildItem -Path $GeneratedDir -Filter "*.yaml" | Sort-Object Name | Select-Object -First 1

if ($null -eq $Kubeconfig) {
    throw "No kubeconfig files found in $GeneratedDir. Run install.ps1 first."
}

New-Item -ItemType Directory -Path $KubeDir -Force | Out-Null

if (Test-Path $TargetKubeconfig) {
    $BackupPath = "$TargetKubeconfig.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Copy-Item -Path $TargetKubeconfig -Destination $BackupPath
    Write-Host "Backed up existing kubeconfig to $BackupPath"
}

Copy-Item -Path $Kubeconfig.FullName -Destination $TargetKubeconfig -Force

Write-Host "Installed kubeconfig from $($Kubeconfig.FullName) to $TargetKubeconfig"
Write-Host "kubectl can now use the default kubeconfig path."
