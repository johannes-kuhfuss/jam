#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
TERRAFORM_DIR="$REPO_ROOT/infra/terraform/environments/lab"
INVENTORY_PATH="$REPO_ROOT/infra/ansible/inventories/lab/hosts.yml"
KUBECONFIG_DIR="$REPO_ROOT/infra/k3s/generated"
KUBE_DIR="$HOME/.kube"
TARGET_KUBECONFIG="$KUBE_DIR/config"
MANAGED_KUBECONFIG_MARKER="$KUBE_DIR/config.jam-managed"

remove_known_host_entries() {
  command -v ssh-keygen >/dev/null 2>&1 || return 0

  while IFS= read -r host; do
    [ -n "$host" ] || continue
    ssh-keygen -R "$host" >/dev/null 2>&1 || true
  done
}

remove_installed_kubeconfig() {
  [ -f "$TARGET_KUBECONFIG" ] || return 0
  [ -f "$MANAGED_KUBECONFIG_MARKER" ] || return 0
  [ -d "$KUBECONFIG_DIR" ] || return 0

  installed_source=$(find "$KUBECONFIG_DIR" -maxdepth 1 -type f -name '*.yaml' | sort | head -n 1)

  if [ -z "$installed_source" ] || ! cmp -s "$TARGET_KUBECONFIG" "$installed_source"; then
    printf '%s\n' "Default kubeconfig was changed after lab provisioning. Leaving $TARGET_KUBECONFIG in place."
    rm -f "$MANAGED_KUBECONFIG_MARKER"
    return 0
  fi

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

if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
  echo "Missing $TERRAFORM_DIR/terraform.tfvars. Terraform needs it to destroy the lab resources." >&2
  exit 1
fi

command -v terraform >/dev/null 2>&1 || {
  echo "terraform is required but was not found in PATH." >&2
  exit 1
}

cd "$TERRAFORM_DIR"
terraform init
terraform destroy

if [ -f "$INVENTORY_PATH" ]; then
  awk '$1 == "ansible_host:" { print $2 }' "$INVENTORY_PATH" | remove_known_host_entries
fi

remove_installed_kubeconfig

rm -f "$INVENTORY_PATH"

if [ -d "$KUBECONFIG_DIR" ]; then
  find "$KUBECONFIG_DIR" -maxdepth 1 -type f -name '*.yaml' -delete
fi

printf '%s\n' "Lab resources destroyed. Removed generated inventory, kubeconfig files, and stale SSH host keys."
