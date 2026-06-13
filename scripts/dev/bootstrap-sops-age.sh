#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$REPO_ROOT/infra/talos/generated/sops-age.agekey}"
SOPS_CONFIG_PATH="${SOPS_CONFIG_PATH:-$REPO_ROOT/.sops.yaml}"

require_command() {
  command_name="$1"

  command -v "$command_name" >/dev/null 2>&1 || {
    echo "$command_name is required but was not found in PATH." >&2
    exit 1
  }
}

extract_public_key() {
  sed -n 's/^# public key: //p' "$SOPS_AGE_KEY_FILE" | head -n 1
}

write_sops_config() {
  recipient="$1"

  cat > "$SOPS_CONFIG_PATH" <<EOF
creation_rules:
  - path_regex: infra/kubernetes/secrets/lab/.*\\.ya?ml$
    encrypted_regex: ^(data|stringData)$
    age: $recipient
EOF
}

require_command age-keygen

mkdir -p "$(dirname "$SOPS_AGE_KEY_FILE")"

if [ ! -f "$SOPS_AGE_KEY_FILE" ]; then
  age-keygen -o "$SOPS_AGE_KEY_FILE"
  chmod 600 "$SOPS_AGE_KEY_FILE"
fi

recipient=$(extract_public_key)
if [ -z "$recipient" ]; then
  echo "Could not extract age public recipient from $SOPS_AGE_KEY_FILE." >&2
  exit 1
fi

write_sops_config "$recipient"

printf '%s\n' "Age private key: $SOPS_AGE_KEY_FILE"
printf '%s\n' "Age public recipient: $recipient"
printf '%s\n' "Updated SOPS config: $SOPS_CONFIG_PATH"
printf '%s\n' "Next: ./scripts/dev/deploy-platform.sh --prepare-zitadel"
