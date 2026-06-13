#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
OPENTOFU_DIR="$REPO_ROOT/infra/opentofu/environments/lab"
GENERATED_DIR="$REPO_ROOT/infra/talos/generated"
KUBE_DIR="$HOME/.kube"
TARGET_KUBECONFIG="$KUBE_DIR/config"
MANAGED_KUBECONFIG_MARKER="$KUBE_DIR/config.jam-managed"
KUBERNETES_API_TIMEOUT="${KUBERNETES_API_TIMEOUT:-300}"
if [ -n "${XDG_CONFIG_HOME:-}" ]; then
  TALOS_DIR="$XDG_CONFIG_HOME/talos"
  TARGET_TALOSCONFIG="$TALOS_DIR/config.yaml"
else
  TALOS_DIR="$HOME/.talos"
  TARGET_TALOSCONFIG="$TALOS_DIR/config"
fi
MANAGED_TALOSCONFIG_MARKER="$TALOS_DIR/config.jam-managed"

require_command() {
  command_name="$1"

  command -v "$command_name" >/dev/null 2>&1 || {
    echo "$command_name is required but was not found in PATH." >&2
    exit 1
  }
}

install_default_kubeconfig() {
  mkdir -p "$KUBE_DIR"

  backup_path=""
  if [ -f "$TARGET_KUBECONFIG" ] && [ ! -f "$MANAGED_KUBECONFIG_MARKER" ]; then
    backup_path="$KUBE_DIR/config.jam-backup.$(date +%Y%m%d%H%M%S)"
    cp "$TARGET_KUBECONFIG" "$backup_path"
    chmod 600 "$backup_path"
  elif [ -f "$MANAGED_KUBECONFIG_MARKER" ]; then
    backup_path=$(head -n 1 "$MANAGED_KUBECONFIG_MARKER")
  fi

  cp "$GENERATED_DIR/kubeconfig" "$TARGET_KUBECONFIG"
  chmod 600 "$TARGET_KUBECONFIG"
  printf '%s\n' "$backup_path" > "$MANAGED_KUBECONFIG_MARKER"
}

install_default_talosconfig() {
  mkdir -p "$TALOS_DIR"

  backup_path=""
  if [ -f "$TARGET_TALOSCONFIG" ] && [ ! -f "$MANAGED_TALOSCONFIG_MARKER" ]; then
    backup_path="$TALOS_DIR/config.jam-backup.$(date +%Y%m%d%H%M%S)"
    cp "$TARGET_TALOSCONFIG" "$backup_path"
    chmod 600 "$backup_path"
  elif [ -f "$MANAGED_TALOSCONFIG_MARKER" ]; then
    backup_path=$(head -n 1 "$MANAGED_TALOSCONFIG_MARKER")
  fi

  cp "$GENERATED_DIR/talosconfig" "$TARGET_TALOSCONFIG"
  chmod 600 "$TARGET_TALOSCONFIG"
  printf '%s\n' "$backup_path" > "$MANAGED_TALOSCONFIG_MARKER"
}

wait_for_kubernetes_api() {
  elapsed_seconds=0

  printf 'Waiting for Kubernetes API to answer at the bootstrap endpoint'
  until kubectl --kubeconfig "$GENERATED_DIR/kubeconfig" --request-timeout=5s get --raw=/version >/dev/null 2>&1; do
    if [ "$elapsed_seconds" -ge "$KUBERNETES_API_TIMEOUT" ]; then
      printf '\n' >&2
      echo "Timed out waiting for the Kubernetes API after ${KUBERNETES_API_TIMEOUT}s." >&2
      echo "Check Talos machine readiness with: talosctl --talosconfig $GENERATED_DIR/talosconfig health" >&2
      return 1
    fi

    printf '.'
    sleep 5
    elapsed_seconds=$((elapsed_seconds + 5))
  done

  printf '\n'
}

if [ ! -f "$OPENTOFU_DIR/lab.auto.tfvars" ]; then
  echo "Missing $OPENTOFU_DIR/lab.auto.tfvars. Copy lab.auto.tfvars.example and fill in your Proxmox/Talos values." >&2
  exit 1
fi

require_command tofu
require_command kubectl

mkdir -p "$GENERATED_DIR"

cd "$OPENTOFU_DIR"
tofu init
tofu apply

tofu output -raw talosconfig > "$GENERATED_DIR/talosconfig"
tofu output -raw kubeconfig > "$GENERATED_DIR/kubeconfig"
api_endpoint=$(tofu output -raw kubernetes_api_endpoint)
bootstrap_api_endpoint=$(tofu output -raw bootstrap_kubernetes_api_endpoint)
if [ "$api_endpoint" != "$bootstrap_api_endpoint" ]; then
  sed "s|$api_endpoint|$bootstrap_api_endpoint|g" "$GENERATED_DIR/kubeconfig" > "$GENERATED_DIR/kubeconfig.bootstrap"
  mv "$GENERATED_DIR/kubeconfig.bootstrap" "$GENERATED_DIR/kubeconfig"
fi
chmod 600 "$GENERATED_DIR/talosconfig" "$GENERATED_DIR/kubeconfig"
install_default_kubeconfig
install_default_talosconfig

printf '%s\n' "Generated Talos config: $GENERATED_DIR/talosconfig"
printf '%s\n' "Generated kubeconfig: $GENERATED_DIR/kubeconfig"
printf '%s\n' "Installed default kubeconfig: $TARGET_KUBECONFIG"
printf '%s\n' "Installed default talosconfig: $TARGET_TALOSCONFIG"
wait_for_kubernetes_api
printf '%s\n' "Next: ./scripts/dev/bootstrap-cilium.sh"
printf '%s\n' "Then: ./scripts/dev/bootstrap-sops-age.sh"
printf '%s\n' "Then: ./scripts/dev/deploy-platform.sh --prepare-zitadel"
