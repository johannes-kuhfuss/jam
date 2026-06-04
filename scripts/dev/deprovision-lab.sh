#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
OPENTOFU_DIR="$REPO_ROOT/infra/opentofu/environments/lab"
GENERATED_DIR="$REPO_ROOT/infra/talos/generated"

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

printf '%s\n' "Lab resources destroyed. Removed generated Talos and Kubernetes client configs."
