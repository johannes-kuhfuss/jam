#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
KUBECONFIG_PATH="${KUBECONFIG:-$REPO_ROOT/infra/talos/generated/kubeconfig}"
FLUX_NAMESPACE="${FLUX_NAMESPACE:-flux-system}"
FLUX_REPO_URL="${FLUX_REPO_URL:-https://github.com/johannes-kuhfuss/jam.git}"
FLUX_REPO_BRANCH="${FLUX_REPO_BRANCH:-main}"
FLUX_CLUSTER_PATH="${FLUX_CLUSTER_PATH:-./infra/gitops/clusters/lab}"
FLUX_SOURCE_NAME="${FLUX_SOURCE_NAME:-jam}"
FLUX_SYNC_NAME="${FLUX_SYNC_NAME:-jam-lab}"
FLUX_SYNC_INTERVAL="${FLUX_SYNC_INTERVAL:-1m}"
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

wait_for_crd() {
  crd_name="$1"
  timeout_seconds="${2:-300}"
  elapsed_seconds=0

  printf 'Waiting for CRD %s\n' "$crd_name"
  until kubectl get crd "$crd_name" >/dev/null 2>&1; do
    if [ "$elapsed_seconds" -ge "$timeout_seconds" ]; then
      echo "Timed out waiting for CRD $crd_name." >&2
      return 1
    fi
    sleep 2
    elapsed_seconds=$((elapsed_seconds + 2))
  done

  kubectl wait --for=condition=Established "crd/$crd_name" --timeout=60s
}

require_file "$KUBECONFIG_PATH" "kubeconfig"
require_command kubectl
require_command flux
export KUBECONFIG="$KUBECONFIG_PATH"

kubectl wait --for=condition=Ready nodes --all --timeout="$BOOTSTRAP_TIMEOUT"
kubectl -n kube-system rollout status daemonset/cilium --timeout="$BOOTSTRAP_TIMEOUT"
kubectl -n kube-system rollout status deployment/cilium-operator --timeout="$BOOTSTRAP_TIMEOUT"

flux check --pre
flux install --namespace "$FLUX_NAMESPACE"

kubectl -n "$FLUX_NAMESPACE" rollout status deployment/source-controller --timeout="$BOOTSTRAP_TIMEOUT"
kubectl -n "$FLUX_NAMESPACE" rollout status deployment/kustomize-controller --timeout="$BOOTSTRAP_TIMEOUT"
kubectl -n "$FLUX_NAMESPACE" rollout status deployment/helm-controller --timeout="$BOOTSTRAP_TIMEOUT"
kubectl -n "$FLUX_NAMESPACE" rollout status deployment/notification-controller --timeout="$BOOTSTRAP_TIMEOUT"

wait_for_crd gitrepositories.source.toolkit.fluxcd.io
wait_for_crd kustomizations.kustomize.toolkit.fluxcd.io

kubectl apply -f - <<EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: $FLUX_SOURCE_NAME
  namespace: $FLUX_NAMESPACE
spec:
  interval: $FLUX_SYNC_INTERVAL
  url: $FLUX_REPO_URL
  ref:
    branch: $FLUX_REPO_BRANCH
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: $FLUX_SYNC_NAME
  namespace: $FLUX_NAMESPACE
spec:
  interval: $FLUX_SYNC_INTERVAL
  path: $FLUX_CLUSTER_PATH
  prune: true
  sourceRef:
    kind: GitRepository
    name: $FLUX_SOURCE_NAME
  wait: false
  timeout: $BOOTSTRAP_TIMEOUT
EOF

flux reconcile source git "$FLUX_SOURCE_NAME" --namespace "$FLUX_NAMESPACE"
flux reconcile kustomization "$FLUX_SYNC_NAME" --namespace "$FLUX_NAMESPACE" --with-source
flux get sources git --namespace "$FLUX_NAMESPACE"
flux get kustomizations --namespace "$FLUX_NAMESPACE"

printf '%s\n' "Flux bootstrap complete. GitOps is reconciling $FLUX_REPO_URL#$FLUX_REPO_BRANCH:$FLUX_CLUSTER_PATH."
printf '%s\n' "Next: ./scripts/dev/blackbox-lab.sh"
printf '%s\n' "Then: verify DNS/TLS for *.mam.jku.internal and test https://auth.mam.jku.internal"
