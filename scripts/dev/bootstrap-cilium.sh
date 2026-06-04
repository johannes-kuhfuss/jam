#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
KUBECONFIG_PATH="${KUBECONFIG:-$REPO_ROOT/infra/talos/generated/kubeconfig}"
CILIUM_VERSION="${CILIUM_VERSION:-}"

if [ ! -f "$KUBECONFIG_PATH" ]; then
  echo "Missing kubeconfig at $KUBECONFIG_PATH. Run scripts/dev/provision-lab.sh first or set KUBECONFIG." >&2
  exit 1
fi

command -v helm >/dev/null 2>&1 || {
  echo "helm is required but was not found in PATH." >&2
  exit 1
}

command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl is required but was not found in PATH." >&2
  exit 1
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

ensure_crd_serves_version() {
  crd_name="$1"
  api_version="$2"

  served_versions=$(kubectl get crd "$crd_name" -o jsonpath='{range .spec.versions[?(@.served==true)]}{.name}{" "}{end}')
  case " $served_versions " in
    *" $api_version "*) ;;
    *)
      echo "CRD $crd_name does not serve version $api_version. Served versions: $served_versions" >&2
      return 1
      ;;
  esac
}

export KUBECONFIG="$KUBECONFIG_PATH"

helm repo add cilium https://helm.cilium.io/ >/dev/null
helm repo update cilium >/dev/null

if [ -n "$CILIUM_VERSION" ]; then
  helm upgrade --install cilium cilium/cilium \
    --namespace kube-system \
    --version "$CILIUM_VERSION" \
    --values "$REPO_ROOT/infra/platform/cilium/values.yaml"
else
  helm upgrade --install cilium cilium/cilium \
    --namespace kube-system \
    --values "$REPO_ROOT/infra/platform/cilium/values.yaml"
fi

kubectl -n kube-system rollout status daemonset/cilium --timeout=10m
kubectl -n kube-system rollout status deployment/cilium-operator --timeout=10m

wait_for_crd ciliumloadbalancerippools.cilium.io
wait_for_crd ciliuml2announcementpolicies.cilium.io
ensure_crd_serves_version ciliumloadbalancerippools.cilium.io v2

kubectl apply -f "$REPO_ROOT/infra/platform/cilium/l2-lab.yaml"

printf '%s\n' "Cilium bootstrap complete. GitOps can now adopt infra/platform/cilium."
