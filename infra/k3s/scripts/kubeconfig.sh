#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GENERATED_DIR="$SCRIPT_DIR/../generated"

if [ ! -d "$GENERATED_DIR" ]; then
  echo "Generated kubeconfig directory not found at $GENERATED_DIR. Run install.sh first." >&2
  exit 1
fi

KUBECONFIG_FILE=$(find "$GENERATED_DIR" -maxdepth 1 -type f -name '*.yaml' | sort | head -n 1)

if [ -z "$KUBECONFIG_FILE" ]; then
  echo "No kubeconfig files found in $GENERATED_DIR. Run install.sh first." >&2
  exit 1
fi

export KUBECONFIG="$KUBECONFIG_FILE"
printf 'KUBECONFIG=%s\n' "$KUBECONFIG"
