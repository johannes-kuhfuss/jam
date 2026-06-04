#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
GENERATED_DIR="$REPO_ROOT/infra/talos/generated"
KUBECONFIG_PATH="${KUBECONFIG:-$GENERATED_DIR/kubeconfig}"
TALOSCONFIG_PATH="${TALOSCONFIG:-$GENERATED_DIR/talosconfig}"
SMOKE_NAMESPACE="${SMOKE_NAMESPACE:-jam-blackbox}"
SMOKE_TIMEOUT="${SMOKE_TIMEOUT:-180s}"
SMOKE_IMAGE="${SMOKE_IMAGE:-docker.io/library/nginx:1.27-alpine}"
SMOKE_CLIENT_IMAGE="${SMOKE_CLIENT_IMAGE:-docker.io/library/busybox:1.36}"

cleanup() {
  kubectl --kubeconfig "$KUBECONFIG_PATH" delete namespace "$SMOKE_NAMESPACE" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}

require_file() {
  path="$1"
  description="$2"

  if [ ! -f "$path" ]; then
    echo "Missing $description at $path. Run scripts/dev/provision-lab.sh and scripts/dev/bootstrap-cilium.sh first, or set the matching environment variable." >&2
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

require_file "$KUBECONFIG_PATH" "kubeconfig"
require_file "$TALOSCONFIG_PATH" "talosconfig"
require_command kubectl
require_command talosctl
export KUBECONFIG="$KUBECONFIG_PATH"
trap cleanup EXIT INT TERM

print_step "Checking Kubernetes API with kubectl"
kubectl --kubeconfig "$KUBECONFIG_PATH" version --client >/dev/null
kubectl --kubeconfig "$KUBECONFIG_PATH" get nodes -o wide
kubectl --kubeconfig "$KUBECONFIG_PATH" wait --for=condition=Ready nodes --all --timeout="$SMOKE_TIMEOUT"

print_step "Checking Talos API with talosctl"
talosctl --talosconfig "$TALOSCONFIG_PATH" version

print_step "Checking Cilium rollout and CRDs"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n kube-system rollout status daemonset/cilium --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n kube-system rollout status deployment/cilium-operator --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" get crd ciliumloadbalancerippools.cilium.io ciliuml2announcementpolicies.cilium.io >/dev/null
kubectl --kubeconfig "$KUBECONFIG_PATH" -n kube-system get pods -l k8s-app=cilium -o wide

print_step "Deploying smoke workload"
kubectl --kubeconfig "$KUBECONFIG_PATH" delete namespace "$SMOKE_NAMESPACE" --ignore-not-found --wait=true --timeout="$SMOKE_TIMEOUT" >/dev/null
kubectl --kubeconfig "$KUBECONFIG_PATH" create namespace "$SMOKE_NAMESPACE" >/dev/null
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$SMOKE_NAMESPACE" create deployment smoke-nginx --image="$SMOKE_IMAGE" --port=80 >/dev/null
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$SMOKE_NAMESPACE" rollout status deployment/smoke-nginx --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$SMOKE_NAMESPACE" expose deployment smoke-nginx --port=80 --target-port=80 >/dev/null

print_step "Checking in-cluster service networking"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$SMOKE_NAMESPACE" run smoke-client \
  --rm \
  --attach \
  --restart=Never \
  --image="$SMOKE_CLIENT_IMAGE" \
  --command -- wget -qO- http://smoke-nginx

print_step "Blackbox lab test passed"
