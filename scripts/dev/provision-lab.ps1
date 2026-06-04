$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."
$OpenTofuDir = Join-Path $RepoRoot "infra\opentofu\environments\lab"
$GeneratedDir = Join-Path $RepoRoot "infra\talos\generated"
$TfvarsPath = Join-Path $OpenTofuDir "lab.auto.tfvars"
$KubeDir = Join-Path $HOME ".kube"
$TargetKubeconfig = Join-Path $KubeDir "config"
$ManagedKubeconfigMarker = Join-Path $KubeDir "config.jam-managed"

function Install-DefaultKubeconfig {
    New-Item -ItemType Directory -Force -Path $KubeDir | Out-Null

    $BackupPath = ""
    if ((Test-Path $TargetKubeconfig) -and -not (Test-Path $ManagedKubeconfigMarker)) {
        $Timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $BackupPath = Join-Path $KubeDir "config.jam-backup.$Timestamp"
        Copy-Item -Path $TargetKubeconfig -Destination $BackupPath -Force
    }
    elseif (Test-Path $ManagedKubeconfigMarker) {
        $BackupPath = Get-Content -Path $ManagedKubeconfigMarker -TotalCount 1
    }

    Copy-Item -Path (Join-Path $GeneratedDir "kubeconfig") -Destination $TargetKubeconfig -Force
    Set-Content -Path $ManagedKubeconfigMarker -Value $BackupPath
}

if (-not (Test-Path $TfvarsPath)) {
    throw "Missing $TfvarsPath. Copy lab.auto.tfvars.example and fill in your Proxmox/Talos values."
}

if (-not (Get-Command tofu -ErrorAction SilentlyContinue)) {
    throw "tofu is required but was not found in PATH."
}

New-Item -ItemType Directory -Force -Path $GeneratedDir | Out-Null

Push-Location $OpenTofuDir
try {
    tofu init
    tofu apply

    tofu output -raw talosconfig | Set-Content -NoNewline -Path (Join-Path $GeneratedDir "talosconfig")
    tofu output -raw kubeconfig | Set-Content -NoNewline -Path (Join-Path $GeneratedDir "kubeconfig")
    Install-DefaultKubeconfig
}
finally {
    Pop-Location
}

Write-Host "Generated Talos config: $GeneratedDir\talosconfig"
Write-Host "Generated kubeconfig: $GeneratedDir\kubeconfig"
Write-Host "Installed default kubeconfig: $TargetKubeconfig"
Write-Host "Next: .\scripts\dev\bootstrap-cilium.ps1"
