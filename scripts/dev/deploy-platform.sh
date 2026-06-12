#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
KUBECONFIG_PATH="${KUBECONFIG:-$REPO_ROOT/infra/talos/generated/kubeconfig}"
PLATFORM_DIR="$REPO_ROOT/infra/kubernetes/platform"
SECRETS_DIR="$REPO_ROOT/infra/kubernetes/secrets/lab"
VALUES_DIR="$REPO_ROOT/infra/helm/values/platform"
DEPLOY_TIMEOUT="${DEPLOY_TIMEOUT:-15m}"
BOOTSTRAP_TIMEOUT="${BOOTSTRAP_TIMEOUT:-300s}"

require_file() {
  path="$1"
  description="$2"

  if [ ! -f "$path" ]; then
    echo "Missing $description at $path. Run scripts/dev/provision-lab.sh and scripts/dev/bootstrap-cilium.sh first, or set KUBECONFIG." >&2
    exit 1
  fi
}

require_command() {
  command_name="$1"

  command -v "$command_name" >/dev/null 2>&1 || {
    echo "$command_name is required but was not found in PATH." >&2
    exit 1
  }
}

print_step() {
  printf '\n==> %s\n' "$1"
}

apply_kustomization() {
  path="$1"

  kubectl --kubeconfig "$KUBECONFIG_PATH" apply -k "$path"
}

helm_release() {
  namespace="$1"
  release="$2"
  chart="$3"
  version="$4"
  values_file="${5:-}"

  if [ -n "$values_file" ]; then
    helm --kubeconfig "$KUBECONFIG_PATH" upgrade --install "$release" "$chart" \
      --namespace "$namespace" \
      --version "$version" \
      --values "$values_file" \
      --wait \
      --timeout "$DEPLOY_TIMEOUT"
  else
    helm --kubeconfig "$KUBECONFIG_PATH" upgrade --install "$release" "$chart" \
      --namespace "$namespace" \
      --version "$version" \
      --wait \
      --timeout "$DEPLOY_TIMEOUT"
  fi
}

apply_secret_file() {
  path="$1"

  if grep -q '^sops:' "$path"; then
    require_command sops
    sops decrypt "$path" | kubectl --kubeconfig "$KUBECONFIG_PATH" apply -f -
  else
    kubectl --kubeconfig "$KUBECONFIG_PATH" apply -f "$path"
  fi
}

apply_lab_secrets() {
  if [ ! -d "$SECRETS_DIR/platform" ]; then
    return 0
  fi

  find "$SECRETS_DIR/platform" -type f \( -name '*.yaml' -o -name '*.yml' \) | while IFS= read -r secret_file; do
    apply_secret_file "$secret_file"
  done
}

require_file "$KUBECONFIG_PATH" "kubeconfig"
require_command kubectl
require_command helm
export KUBECONFIG="$KUBECONFIG_PATH"

print_step "Checking cluster readiness"
kubectl --kubeconfig "$KUBECONFIG_PATH" wait --for=condition=Ready nodes --all --timeout="$BOOTSTRAP_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n kube-system rollout status daemonset/cilium --timeout="$BOOTSTRAP_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n kube-system rollout status deployment/cilium-operator --timeout="$BOOTSTRAP_TIMEOUT"

print_step "Configuring Helm repositories"
helm repo add longhorn https://charts.longhorn.io --force-update >/dev/null
helm repo add istio https://istio-release.storage.googleapis.com/charts --force-update >/dev/null
helm repo add zitadel https://charts.zitadel.com --force-update >/dev/null
helm repo update

print_step "Installing cert-manager"
apply_kustomization "$PLATFORM_DIR/cert-manager/install"
helm_release cert-manager cert-manager oci://quay.io/jetstack/charts/cert-manager v1.20.2 "$VALUES_DIR/cert-manager.yaml"

print_step "Installing Envoy Gateway"
apply_kustomization "$PLATFORM_DIR/gateway/envoy-gateway/install"
helm_release envoy-gateway-system envoy-gateway oci://docker.io/envoyproxy/gateway-helm v1.5.9

print_step "Installing local certificate resources"
apply_kustomization "$PLATFORM_DIR/cert-manager/local-ca"

print_step "Installing Longhorn"
apply_kustomization "$PLATFORM_DIR/longhorn"
helm_release longhorn-system longhorn longhorn/longhorn v1.12.0 "$VALUES_DIR/longhorn.yaml"

print_step "Installing Istio ambient mesh"
apply_kustomization "$PLATFORM_DIR/mesh/istio/base"
helm_release istio-system istio-base istio/base 1.30.1
helm_release istio-system istiod istio/istiod 1.30.1 "$VALUES_DIR/istiod.yaml"
helm_release istio-system istio-cni istio/cni 1.30.1 "$VALUES_DIR/istio-cni.yaml"
helm_release istio-system ztunnel istio/ztunnel 1.30.1

print_step "Applying Envoy Gateway configuration"
apply_kustomization "$PLATFORM_DIR/gateway/envoy-gateway/config"

print_step "Preparing ZITADEL namespace and secrets"
kubectl --kubeconfig "$KUBECONFIG_PATH" apply -f "$PLATFORM_DIR/auth/zitadel/namespace.yaml"
apply_lab_secrets

print_step "Installing ZITADEL dependencies"
helm_release zitadel zitadel-postgresql oci://registry-1.docker.io/bitnamicharts/postgresql 18.5.13 "$VALUES_DIR/zitadel-postgresql.yaml"
helm_release zitadel zitadel zitadel/zitadel 10.0.2 "$VALUES_DIR/zitadel.yaml"

print_step "Applying ZITADEL routing"
apply_kustomization "$PLATFORM_DIR/auth/zitadel"

printf '\n%s\n' "Platform deployment complete."
printf '%s\n' "Next: ./scripts/dev/blackbox-lab.sh"
