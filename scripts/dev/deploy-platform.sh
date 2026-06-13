#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
KUBECONFIG_PATH="${KUBECONFIG:-$REPO_ROOT/infra/talos/generated/kubeconfig}"
PLATFORM_DIR="$REPO_ROOT/infra/kubernetes/platform"
SECRETS_DIR="$REPO_ROOT/infra/kubernetes/secrets/lab"
VALUES_DIR="$REPO_ROOT/infra/helm/values/platform"
ZITADEL_SECRET_PATH="$SECRETS_DIR/platform/zitadel-masterkey.secret.yaml"
DEFAULT_SOPS_AGE_KEY_FILE="$REPO_ROOT/infra/talos/generated/sops-age.agekey"
PREPARE_ZITADEL="${PREPARE_ZITADEL:-auto}"
ENCRYPT_ZITADEL_SECRET="${ENCRYPT_ZITADEL_SECRET:-true}"
DEPLOY_TIMEOUT="${DEPLOY_TIMEOUT:-15m}"
BOOTSTRAP_TIMEOUT="${BOOTSTRAP_TIMEOUT:-300s}"

usage() {
  cat <<EOF
Usage: $0 [--prepare-zitadel] [--no-prepare-zitadel]

Options:
  --prepare-zitadel     Run scripts/dev/prepare-zitadel.sh before deployment.
  --no-prepare-zitadel  Do not run ZITADEL preparation automatically.

Environment:
  PREPARE_ZITADEL=true|false|auto
  ENCRYPT_ZITADEL_SECRET=true|false
  SOPS_AGE_KEY_FILE=/path/to/agekey
EOF
}

while [ "$#" -gt 0 ]; do
  arg="$1"

  case "$arg" in
    --prepare-zitadel)
      PREPARE_ZITADEL=true
      ;;
    --no-prepare-zitadel)
      PREPARE_ZITADEL=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

require_file() {
  local path
  local description

  path="$1"
  description="$2"

  if [ ! -f "$path" ]; then
    echo "Missing $description at $path. Run scripts/dev/provision-lab.sh and scripts/dev/bootstrap-cilium.sh first, or set KUBECONFIG." >&2
    exit 1
  fi
}

require_command() {
  local command_name

  command_name="$1"

  command -v "$command_name" >/dev/null 2>&1 || {
    echo "$command_name is required but was not found in PATH." >&2
    exit 1
  }
}

print_step() {
  local message

  message="$1"

  printf '\n==> %s\n' "$message"
}

apply_kustomization() {
  local path

  path="$1"

  kubectl --kubeconfig "$KUBECONFIG_PATH" apply -k "$path"
}

helm_release() {
  local namespace
  local release
  local chart
  local version
  local values_file

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
  local path

  path="$1"

  if grep -q '^sops:' "$path"; then
    require_command sops
    configure_sops_age_key
    sops decrypt "$path" | kubectl --kubeconfig "$KUBECONFIG_PATH" apply -f -
  else
    kubectl --kubeconfig "$KUBECONFIG_PATH" apply -f "$path"
  fi
}

apply_secret_directory() {
  local directory

  directory="$1"

  if [ ! -d "$directory" ]; then
    return 0
  fi

  find "$directory" -type f \( -name '*.yaml' -o -name '*.yml' \) | while IFS= read -r secret_file; do
    apply_secret_file "$secret_file"
  done
}

apply_lab_secrets() {
  apply_secret_directory "$SECRETS_DIR/platform"
}

apply_operator_ui_secret() {
  local secret_name
  local secret_path

  secret_name="$1"
  secret_path="$SECRETS_DIR/platform/operator-ui/$secret_name"

  if [ ! -f "$secret_path" ]; then
    return 0
  fi

  apply_secret_file "$secret_path"
}

configure_sops_age_key() {
  if [ -n "${SOPS_AGE_KEY_FILE:-}" ] ||
    [ -n "${SOPS_AGE_KEY:-}" ] ||
    [ -n "${SOPS_AGE_KEY_CMD:-}" ] ||
    [ -n "${SOPS_AGE_SSH_PRIVATE_KEY_FILE:-}" ] ||
    [ -n "${SOPS_AGE_SSH_PRIVATE_KEY_CMD:-}" ]; then
    return 0
  fi

  require_file "$DEFAULT_SOPS_AGE_KEY_FILE" "SOPS age key"
  export SOPS_AGE_KEY_FILE="$DEFAULT_SOPS_AGE_KEY_FILE"
}

encrypt_zitadel_secret_if_requested() {
  case "$ENCRYPT_ZITADEL_SECRET" in
    true|yes|1) ;;
    false|no|0) return 0 ;;
    *)
      echo "ENCRYPT_ZITADEL_SECRET must be true or false." >&2
      exit 1
      ;;
  esac

  require_file "$ZITADEL_SECRET_PATH" "ZITADEL master key Secret"

  if grep -q '^sops:' "$ZITADEL_SECRET_PATH"; then
    return 0
  fi

  require_command sops
  configure_sops_age_key
  print_step "Encrypting ZITADEL master key Secret"
  sops --encrypt --in-place "$ZITADEL_SECRET_PATH"
}

prepare_zitadel_if_needed() {
  case "$PREPARE_ZITADEL" in
    true|yes|1)
      PREPARE_ZITADEL_EMBEDDED=true "$SCRIPT_DIR/prepare-zitadel.sh"
      encrypt_zitadel_secret_if_requested
      return 0
      ;;
    false|no|0)
      encrypt_zitadel_secret_if_requested
      return 0
      ;;
    auto) ;;
    *)
      echo "PREPARE_ZITADEL must be true, false, or auto." >&2
      exit 1
      ;;
  esac

  if [ -f "$ZITADEL_SECRET_PATH" ]; then
    encrypt_zitadel_secret_if_requested
    return 0
  fi

  if [ -t 0 ]; then
    print_step "Preparing ZITADEL configuration"
    PREPARE_ZITADEL_EMBEDDED=true "$SCRIPT_DIR/prepare-zitadel.sh"
    encrypt_zitadel_secret_if_requested
    return 0
  fi

  echo "Missing ZITADEL master key Secret at $ZITADEL_SECRET_PATH." >&2
  echo "Run $0 --prepare-zitadel interactively, or create the Secret before noninteractive deployment." >&2
  exit 1
}

require_file "$KUBECONFIG_PATH" "kubeconfig"
require_command kubectl
require_command helm
export KUBECONFIG="$KUBECONFIG_PATH"

prepare_zitadel_if_needed

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

print_step "Preparing platform secrets"
apply_secret_file "$ZITADEL_SECRET_PATH"

print_step "Installing Longhorn"
kubectl --kubeconfig "$KUBECONFIG_PATH" apply -f "$PLATFORM_DIR/longhorn/namespace.yaml"
helm_release longhorn-system longhorn longhorn/longhorn 1.12.0 "$VALUES_DIR/longhorn.yaml"

print_step "Installing Istio ambient mesh"
apply_kustomization "$PLATFORM_DIR/mesh/istio/base"
helm_release istio-system istio-base istio/base 1.30.1
helm_release istio-system istiod istio/istiod 1.30.1 "$VALUES_DIR/istiod.yaml"
helm_release istio-system istio-cni istio/cni 1.30.1 "$VALUES_DIR/istio-cni.yaml"
helm_release istio-system ztunnel istio/ztunnel 1.30.1

print_step "Applying Envoy Gateway configuration"
apply_kustomization "$PLATFORM_DIR/gateway/envoy-gateway/config"
print_step "Configuring cluster DNS for public auth hostname"
sh "$SCRIPT_DIR/configure-cluster-dns.sh"
apply_operator_ui_secret hubble-ui-oidc-client.secret.yaml
apply_kustomization "$PLATFORM_DIR/cilium"
apply_operator_ui_secret longhorn-ui-oidc-client.secret.yaml
apply_kustomization "$PLATFORM_DIR/longhorn"

print_step "Preparing ZITADEL namespace and secrets"
kubectl --kubeconfig "$KUBECONFIG_PATH" apply -f "$PLATFORM_DIR/auth/zitadel/namespace.yaml"

print_step "Installing ZITADEL dependencies"
helm_release zitadel zitadel-postgresql oci://registry-1.docker.io/bitnamicharts/postgresql 18.5.13 "$VALUES_DIR/zitadel-postgresql.yaml"
helm_release zitadel zitadel zitadel/zitadel 10.0.2 "$VALUES_DIR/zitadel.yaml"

print_step "Applying ZITADEL routing"
apply_kustomization "$PLATFORM_DIR/auth/zitadel"

printf '\n%s\n' "Platform deployment complete."
printf '%s\n' "Next: ./scripts/dev/blackbox-lab.sh"
