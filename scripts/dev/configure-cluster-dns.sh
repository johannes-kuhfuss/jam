#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
KUBECONFIG_PATH="${KUBECONFIG:-$REPO_ROOT/infra/talos/generated/kubeconfig}"
PUBLIC_AUTH_HOSTNAME="${PUBLIC_AUTH_HOSTNAME:-auth.mam.jku.internal}"
PUBLIC_AUTH_INTERNAL_SERVICE="${PUBLIC_AUTH_INTERNAL_SERVICE:-public-api-internal.envoy-gateway-system.svc.cluster.local}"
COREDNS_NAMESPACE="${COREDNS_NAMESPACE:-kube-system}"
COREDNS_CONFIGMAP="${COREDNS_CONFIGMAP:-coredns}"

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
  rm -f "$corefile_path" "$patched_corefile_path"
}

require_file "$KUBECONFIG_PATH" "kubeconfig"
require_command kubectl

corefile_path=$(mktemp)
patched_corefile_path=$(mktemp)
trap cleanup EXIT INT TERM

kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$COREDNS_NAMESPACE" \
  get configmap "$COREDNS_CONFIGMAP" -o jsonpath='{.data.Corefile}' > "$corefile_path"

if grep -Fq "rewrite name exact $PUBLIC_AUTH_HOSTNAME $PUBLIC_AUTH_INTERNAL_SERVICE" "$corefile_path"; then
  exit 0
fi

awk \
  -v hostname="$PUBLIC_AUTH_HOSTNAME" \
  -v internal_service="$PUBLIC_AUTH_INTERNAL_SERVICE" '
    !added && /^[[:space:]]*kubernetes[[:space:]]/ {
      indent = $0
      sub(/[^[:space:]].*$/, "", indent)
      print indent "rewrite name exact " hostname " " internal_service
      added = 1
    }
    { print }
    END {
      if (!added) {
        exit 42
      }
    }
  ' "$corefile_path" > "$patched_corefile_path" || {
  status="$?"
  if [ "$status" = "42" ]; then
    echo "Could not find the CoreDNS kubernetes plugin in the Corefile." >&2
  fi
  exit "$status"
}

kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$COREDNS_NAMESPACE" \
  create configmap "$COREDNS_CONFIGMAP" \
  --from-file=Corefile="$patched_corefile_path" \
  --dry-run=client \
  -o yaml |
  kubectl --kubeconfig "$KUBECONFIG_PATH" apply -f -

kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$COREDNS_NAMESPACE" \
  rollout restart deployment/coredns
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$COREDNS_NAMESPACE" \
  rollout status deployment/coredns --timeout=180s
