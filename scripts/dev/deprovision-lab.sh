#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
OPENTOFU_DIR="$REPO_ROOT/infra/opentofu/environments/lab"
GENERATED_DIR="$REPO_ROOT/infra/talos/generated"
KUBE_DIR="$HOME/.kube"
TARGET_KUBECONFIG="$KUBE_DIR/config"
MANAGED_KUBECONFIG_MARKER="$KUBE_DIR/config.jam-managed"
if [ -n "${XDG_CONFIG_HOME:-}" ]; then
  TALOS_DIR="$XDG_CONFIG_HOME/talos"
  TARGET_TALOSCONFIG="$TALOS_DIR/config.yaml"
else
  TALOS_DIR="$HOME/.talos"
  TARGET_TALOSCONFIG="$TALOS_DIR/config"
fi
MANAGED_TALOSCONFIG_MARKER="$TALOS_DIR/config.jam-managed"

restore_default_kubeconfig() {
  [ -f "$MANAGED_KUBECONFIG_MARKER" ] || return 0

  backup_path=$(head -n 1 "$MANAGED_KUBECONFIG_MARKER")

  if [ -n "$backup_path" ] && [ -f "$backup_path" ]; then
    mv "$backup_path" "$TARGET_KUBECONFIG"
    chmod 600 "$TARGET_KUBECONFIG"
    printf 'Restored previous kubeconfig from %s\n' "$backup_path"
  else
    rm -f "$TARGET_KUBECONFIG"
    printf 'Removed lab kubeconfig from %s\n' "$TARGET_KUBECONFIG"
  fi

  rm -f "$MANAGED_KUBECONFIG_MARKER"
}

restore_default_talosconfig() {
  [ -f "$MANAGED_TALOSCONFIG_MARKER" ] || return 0

  backup_path=$(head -n 1 "$MANAGED_TALOSCONFIG_MARKER")

  if [ -n "$backup_path" ] && [ -f "$backup_path" ]; then
    mv "$backup_path" "$TARGET_TALOSCONFIG"
    chmod 600 "$TARGET_TALOSCONFIG"
    printf 'Restored previous talosconfig from %s\n' "$backup_path"
  else
    rm -f "$TARGET_TALOSCONFIG"
    printf 'Removed lab talosconfig from %s\n' "$TARGET_TALOSCONFIG"
  fi

  rm -f "$MANAGED_TALOSCONFIG_MARKER"
}

if [ ! -f "$OPENTOFU_DIR/lab.auto.tfvars" ]; then
  echo "Missing $OPENTOFU_DIR/lab.auto.tfvars. OpenTofu needs it to destroy the lab resources." >&2
  exit 1
fi

command -v tofu >/dev/null 2>&1 || {
  echo "tofu is required but was not found in PATH." >&2
  exit 1
}

cd "$OPENTOFU_DIR"
tofu init
tofu destroy

rm -f "$GENERATED_DIR/talosconfig" "$GENERATED_DIR/kubeconfig"
restore_default_kubeconfig
restore_default_talosconfig

printf '%s\n' "Lab resources destroyed. Removed generated Talos and Kubernetes client configs."
