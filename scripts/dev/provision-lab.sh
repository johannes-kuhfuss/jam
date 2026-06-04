#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
OPENTOFU_DIR="$REPO_ROOT/infra/opentofu/environments/lab"
GENERATED_DIR="$REPO_ROOT/infra/talos/generated"

if [ ! -f "$OPENTOFU_DIR/lab.auto.tfvars" ]; then
  echo "Missing $OPENTOFU_DIR/lab.auto.tfvars. Copy lab.auto.tfvars.example and fill in your Proxmox/Talos values." >&2
  exit 1
fi

command -v tofu >/dev/null 2>&1 || {
  echo "tofu is required but was not found in PATH." >&2
  exit 1
}

mkdir -p "$GENERATED_DIR"

cd "$OPENTOFU_DIR"
tofu init
tofu apply

tofu output -raw talosconfig > "$GENERATED_DIR/talosconfig"
tofu output -raw kubeconfig > "$GENERATED_DIR/kubeconfig"
chmod 600 "$GENERATED_DIR/talosconfig" "$GENERATED_DIR/kubeconfig"

printf '%s\n' "Generated Talos config: $GENERATED_DIR/talosconfig"
printf '%s\n' "Generated kubeconfig: $GENERATED_DIR/kubeconfig"
printf '%s\n' "Next: ./scripts/dev/bootstrap-cilium.sh"
