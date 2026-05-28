#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GENERATED_DIR="$SCRIPT_DIR/../generated"
KUBE_DIR="$HOME/.kube"
TARGET_KUBECONFIG="$KUBE_DIR/config"

if [ ! -d "$GENERATED_DIR" ]; then
  echo "Generated kubeconfig directory not found at $GENERATED_DIR. Run install.sh first." >&2
  exit 1
fi

KUBECONFIG_FILE=$(find "$GENERATED_DIR" -maxdepth 1 -type f -name '*.yaml' | sort | head -n 1)

if [ -z "$KUBECONFIG_FILE" ]; then
  echo "No kubeconfig files found in $GENERATED_DIR. Run install.sh first." >&2
  exit 1
fi

mkdir -p "$KUBE_DIR"

if [ -f "$TARGET_KUBECONFIG" ]; then
  BACKUP_PATH="$TARGET_KUBECONFIG.backup.$(date +%Y%m%d%H%M%S)"
  cp "$TARGET_KUBECONFIG" "$BACKUP_PATH"
  printf 'Backed up existing kubeconfig to %s\n' "$BACKUP_PATH"
fi

cp "$KUBECONFIG_FILE" "$TARGET_KUBECONFIG"
chmod 600 "$TARGET_KUBECONFIG"

printf 'Installed kubeconfig from %s to %s\n' "$KUBECONFIG_FILE" "$TARGET_KUBECONFIG"
printf '%s\n' 'kubectl can now use the default kubeconfig path.'
