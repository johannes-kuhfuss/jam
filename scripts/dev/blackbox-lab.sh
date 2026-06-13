#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
GENERATED_DIR="$REPO_ROOT/infra/talos/generated"
KUBECONFIG_PATH="${KUBECONFIG:-$GENERATED_DIR/kubeconfig}"
TALOSCONFIG_PATH="${TALOSCONFIG:-$GENERATED_DIR/talosconfig}"
SMOKE_NAMESPACE="${SMOKE_NAMESPACE:-jam-blackbox}"
SMOKE_TIMEOUT="${SMOKE_TIMEOUT:-180s}"
SMOKE_IMAGE="${SMOKE_IMAGE:-docker.io/nginxinc/nginx-unprivileged:1.27-alpine}"
SMOKE_RUN_AS_USER="${SMOKE_RUN_AS_USER:-101}"
SMOKE_RUN_AS_GROUP="${SMOKE_RUN_AS_GROUP:-101}"
SMOKE_CLIENT_IMAGE="${SMOKE_CLIENT_IMAGE:-docker.io/library/busybox:1.36}"
SMOKE_CLIENT_RUN_AS_USER="${SMOKE_CLIENT_RUN_AS_USER:-65532}"
SMOKE_CLIENT_RUN_AS_GROUP="${SMOKE_CLIENT_RUN_AS_GROUP:-65532}"

cleanup() {
  kubectl --kubeconfig "$KUBECONFIG_PATH" delete namespace "$SMOKE_NAMESPACE" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}

require_file() {
  local path
  local description

  path="$1"
  description="$2"

  if [ ! -f "$path" ]; then
    echo "Missing $description at $path. Run scripts/dev/provision-lab.sh, scripts/dev/bootstrap-cilium.sh, and scripts/dev/deploy-platform.sh first, or set the matching environment variable." >&2
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

check_helm_release() {
  local namespace
  local name

  namespace="$1"
  name="$2"

  helm --kubeconfig "$KUBECONFIG_PATH" --namespace "$namespace" status "$name" >/dev/null
}

check_zitadel() {
  check_helm_release zitadel zitadel
  kubectl --kubeconfig "$KUBECONFIG_PATH" -n zitadel get secret zitadel-masterkey >/dev/null
  kubectl --kubeconfig "$KUBECONFIG_PATH" -n zitadel get service zitadel >/dev/null
  kubectl --kubeconfig "$KUBECONFIG_PATH" -n zitadel get service zitadel-login >/dev/null
  kubectl --kubeconfig "$KUBECONFIG_PATH" -n zitadel get httproute zitadel >/dev/null
}

require_file "$KUBECONFIG_PATH" "kubeconfig"
require_file "$TALOSCONFIG_PATH" "talosconfig"
require_command kubectl
require_command helm
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

print_step "Checking Helm releases"
check_helm_release cert-manager cert-manager
check_helm_release envoy-gateway-system envoy-gateway
check_helm_release longhorn-system longhorn
check_helm_release istio-system istio-base
check_helm_release istio-system istiod
check_helm_release istio-system istio-cni
check_helm_release istio-system ztunnel
check_helm_release zitadel zitadel-postgresql
check_helm_release zitadel zitadel

print_step "Checking cert-manager and local certificates"
check_helm_release cert-manager cert-manager
kubectl --kubeconfig "$KUBECONFIG_PATH" -n cert-manager rollout status deployment/cert-manager --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n cert-manager rollout status deployment/cert-manager-cainjector --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n cert-manager rollout status deployment/cert-manager-webhook --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" get clusterissuer jam-selfsigned jam-local-ca >/dev/null
kubectl --kubeconfig "$KUBECONFIG_PATH" -n cert-manager wait --for=condition=Ready certificate/jam-local-root-ca --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n envoy-gateway-system wait --for=condition=Ready certificate/mam-jku-internal-wildcard --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n envoy-gateway-system get secret mam-jku-internal-wildcard-tls >/dev/null

print_step "Checking Envoy Gateway"
check_helm_release envoy-gateway-system envoy-gateway
kubectl --kubeconfig "$KUBECONFIG_PATH" -n envoy-gateway-system rollout status deployment/envoy-gateway --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" get gatewayclass envoy >/dev/null
kubectl --kubeconfig "$KUBECONFIG_PATH" -n envoy-gateway-system get gateway public-api >/dev/null
kubectl --kubeconfig "$KUBECONFIG_PATH" -n envoy-gateway-system wait --for=condition=Accepted gateway/public-api --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n envoy-gateway-system wait --for=condition=Programmed gateway/public-api --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n envoy-gateway-system get gateway public-api -o jsonpath='{.status.addresses[0].value}' | grep -q .

print_step "Checking Istio ambient mesh"
check_helm_release istio-system istio-base
check_helm_release istio-system istiod
check_helm_release istio-system istio-cni
check_helm_release istio-system ztunnel
kubectl --kubeconfig "$KUBECONFIG_PATH" -n istio-system rollout status deployment/istiod --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n istio-system rollout status daemonset/istio-cni-node --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n istio-system rollout status daemonset/ztunnel --timeout="$SMOKE_TIMEOUT"

print_step "Checking ZITADEL deployment"
check_zitadel

print_step "Checking Longhorn rollout and default StorageClass"
check_helm_release longhorn-system longhorn
kubectl --kubeconfig "$KUBECONFIG_PATH" -n longhorn-system rollout status deployment/longhorn-driver-deployer --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n longhorn-system rollout status deployment/longhorn-ui --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n longhorn-system rollout status daemonset/longhorn-manager --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" get storageclass longhorn -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' | grep -q '^true$'

print_step "Deploying smoke workload"
kubectl --kubeconfig "$KUBECONFIG_PATH" delete namespace "$SMOKE_NAMESPACE" --ignore-not-found --wait=true --timeout="$SMOKE_TIMEOUT" >/dev/null
kubectl --kubeconfig "$KUBECONFIG_PATH" create namespace "$SMOKE_NAMESPACE" >/dev/null
kubectl --kubeconfig "$KUBECONFIG_PATH" label namespace "$SMOKE_NAMESPACE" \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  istio.io/dataplane-mode=ambient >/dev/null
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$SMOKE_NAMESPACE" apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: smoke-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: smoke-nginx
  template:
    metadata:
      labels:
        app.kubernetes.io/name: smoke-nginx
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: $SMOKE_RUN_AS_USER
        runAsGroup: $SMOKE_RUN_AS_GROUP
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: nginx
          image: $SMOKE_IMAGE
          ports:
            - containerPort: 8080
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
EOF
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$SMOKE_NAMESPACE" rollout status deployment/smoke-nginx --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$SMOKE_NAMESPACE" expose deployment smoke-nginx --port=80 --target-port=8080 >/dev/null

print_step "Checking in-cluster service networking"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$SMOKE_NAMESPACE" apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: smoke-client
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: $SMOKE_CLIENT_RUN_AS_USER
    runAsGroup: $SMOKE_CLIENT_RUN_AS_GROUP
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: smoke-client
      image: $SMOKE_CLIENT_IMAGE
      command:
        - wget
        - -qO-
        - http://smoke-nginx
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
EOF
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$SMOKE_NAMESPACE" wait --for=condition=Ready pod/smoke-client --timeout="$SMOKE_TIMEOUT" >/dev/null 2>&1 || true
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$SMOKE_NAMESPACE" wait --for=jsonpath='{.status.phase}'=Succeeded pod/smoke-client --timeout="$SMOKE_TIMEOUT"
kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$SMOKE_NAMESPACE" logs pod/smoke-client

print_step "Blackbox lab test passed"
printf '%s\n' "Next: verify DNS/TLS for *.mam.jku.internal, then add application HTTPRoutes."
