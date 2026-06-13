#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
KUBECONFIG_PATH="${KUBECONFIG:-$REPO_ROOT/infra/talos/generated/kubeconfig}"
SOURCE_NAMESPACE="${SOURCE_NAMESPACE:-cert-manager}"
SOURCE_CERTIFICATE="${SOURCE_CERTIFICATE:-jam-local-root-ca}"
SOURCE_SECRET="${SOURCE_SECRET:-jam-local-root-ca}"
TARGET_NAMESPACE="${TARGET_NAMESPACE:-envoy-gateway-system}"
TARGET_CONFIGMAP="${TARGET_CONFIGMAP:-jam-local-root-ca-bundle}"
CERT_WAIT_TIMEOUT="${CERT_WAIT_TIMEOUT:-180s}"

require_file() {
  local path
  local description

  path="$1"
  description="$2"

  if [ ! -f "$path" ]; then
    echo "Missing $description at $path. Run scripts/dev/provision-lab.sh first, or set KUBECONFIG." >&2
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

cleanup() {
  rm -f "$ca_path"
}

require_file "$KUBECONFIG_PATH" "kubeconfig"
require_command base64
require_command kubectl

ca_path=$(mktemp)
trap cleanup EXIT INT TERM

kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$SOURCE_NAMESPACE" \
  wait --for=condition=Ready "certificate/$SOURCE_CERTIFICATE" --timeout="$CERT_WAIT_TIMEOUT"

kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$SOURCE_NAMESPACE" \
  get secret "$SOURCE_SECRET" -o jsonpath='{.data.ca\.crt}' |
  base64 -d > "$ca_path"

kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$TARGET_NAMESPACE" \
  create configmap "$TARGET_CONFIGMAP" \
  --from-file=ca.crt="$ca_path" \
  --dry-run=client \
  -o yaml |
  kubectl --kubeconfig "$KUBECONFIG_PATH" apply -f -
