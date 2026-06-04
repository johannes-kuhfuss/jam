$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."
$KubeconfigPath = if ($env:KUBECONFIG) { $env:KUBECONFIG } else { Join-Path $RepoRoot "infra\talos\generated\kubeconfig" }
$CiliumVersion = if ($env:CILIUM_VERSION) { $env:CILIUM_VERSION } else { "" }

if (-not (Test-Path $KubeconfigPath)) {
    throw "Missing kubeconfig at $KubeconfigPath. Run scripts/dev/provision-lab.ps1 first or set KUBECONFIG."
}

if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
    throw "helm is required but was not found in PATH."
}

if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw "kubectl is required but was not found in PATH."
}

$env:KUBECONFIG = $KubeconfigPath

helm repo add cilium https://helm.cilium.io/
helm repo update cilium

if ($CiliumVersion) {
    helm upgrade --install cilium cilium/cilium `
        --namespace kube-system `
        --version $CiliumVersion `
        --values (Join-Path $RepoRoot "infra\platform\cilium\values.yaml")
}
else {
    helm upgrade --install cilium cilium/cilium `
        --namespace kube-system `
        --values (Join-Path $RepoRoot "infra\platform\cilium\values.yaml")
}

kubectl -n kube-system rollout status daemonset/cilium --timeout=10m
kubectl -n kube-system rollout status deployment/cilium-operator --timeout=10m
kubectl apply -f (Join-Path $RepoRoot "infra\platform\cilium\l2-lab.yaml")

Write-Host "Cilium bootstrap complete. GitOps can now adopt infra/platform/cilium."
