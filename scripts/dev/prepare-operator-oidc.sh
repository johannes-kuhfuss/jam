#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
SECRETS_DIR="$REPO_ROOT/infra/kubernetes/secrets/lab"
OPERATOR_SECRET_DIR="$SECRETS_DIR/platform/operator-ui"
SECRETS_KUSTOMIZATION="$SECRETS_DIR/kustomization.yaml"
DEFAULT_SOPS_AGE_KEY_FILE="$REPO_ROOT/infra/talos/generated/sops-age.agekey"
CILIUM_KUSTOMIZATION="$REPO_ROOT/infra/kubernetes/platform/cilium/kustomization.yaml"
LONGHORN_KUSTOMIZATION="$REPO_ROOT/infra/kubernetes/platform/longhorn/kustomization.yaml"

require_command() {
  local command_name

  command_name="$1"

  command -v "$command_name" >/dev/null 2>&1 || {
    echo "$command_name is required but was not found in PATH." >&2
    exit 1
  }
}

require_file() {
  local path
  local description

  path="$1"
  description="$2"

  if [ ! -f "$path" ]; then
    echo "Missing $description at $path." >&2
    exit 1
  fi
}

prompt_default() {
  local label
  local default_value
  local value

  label="$1"
  default_value="$2"
  value=""

  printf '%s [%s]: ' "$label" "$default_value" >&2
  read -r value
  if [ -z "$value" ]; then
    value="$default_value"
  fi
  printf '%s' "$value"
}

prompt_secret() {
  local label
  local value
  local stty_state

  label="$1"
  value=""
  stty_state=""

  while [ -z "$value" ]; do
    printf '%s: ' "$label" >&2
    if stty_state=$(stty -g 2>/dev/null); then
      stty -echo
      read -r value
      stty "$stty_state"
      printf '\n' >&2
    else
      read -r value
    fi
  done
  printf '%s' "$value"
}

yaml_single_quote() {
  local value

  value="$1"

  printf "%s" "$value" | sed "s/'/''/g"
}

ensure_kustomization_resource() {
  local file_path
  local resource_path
  local tmp_path

  file_path="$1"
  resource_path="$2"
  tmp_path="$file_path.tmp"

  if grep -Fq -- "- $resource_path" "$file_path"; then
    return 0
  fi

  awk -v resource="$resource_path" '
    { print }
    $0 == "resources:" && !added {
      print "  - " resource
      added = 1
    }
  ' "$file_path" > "$tmp_path"
  mv "$tmp_path" "$file_path"
}

configure_sops_age_key() {
  if [ -n "${SOPS_AGE_KEY_FILE:-}" ] ||
    [ -n "${SOPS_AGE_KEY:-}" ] ||
    [ -n "${SOPS_AGE_KEY_CMD:-}" ] ||
    [ -n "${SOPS_AGE_SSH_PRIVATE_KEY_FILE:-}" ] ||
    [ -n "${SOPS_AGE_SSH_PRIVATE_KEY_CMD:-}" ]; then
    return 0
  fi

  require_file "$DEFAULT_SOPS_AGE_KEY_FILE" "SOPS age key"
  export SOPS_AGE_KEY_FILE="$DEFAULT_SOPS_AGE_KEY_FILE"
}

write_oidc_secret() {
  local path
  local namespace
  local secret_name
  local client_id
  local client_secret
  local client_id_q
  local client_secret_q

  path="$1"
  namespace="$2"
  secret_name="$3"
  client_id="$4"
  client_secret="$5"
  client_id_q=$(yaml_single_quote "$client_id")
  client_secret_q=$(yaml_single_quote "$client_secret")

  cat > "$path" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $secret_name
  namespace: $namespace
type: Opaque
stringData:
  client-id: '$client_id_q'
  client-secret: '$client_secret_q'
EOF
}

encrypt_secret() {
  local path

  path="$1"

  require_command sops
  configure_sops_age_key
  sops --encrypt --in-place "$path"
}

prepare_client() {
  local label
  local namespace
  local secret_name
  local client_id
  local resource_path
  local secret_path
  local client_secret

  label="$1"
  namespace="$2"
  secret_name="$3"
  client_id="$4"
  resource_path="$5"
  secret_path="$OPERATOR_SECRET_DIR/$resource_path"

  printf '%s\n' "$label OIDC client ID: $client_id" >&2
  client_secret=$(prompt_secret "$label OIDC client secret")

  write_oidc_secret "$secret_path" "$namespace" "$secret_name" "$client_id" "$client_secret"
  encrypt_secret "$secret_path"
  ensure_kustomization_resource "$SECRETS_KUSTOMIZATION" "platform/operator-ui/$resource_path"
}

require_file "$SECRETS_KUSTOMIZATION" "lab secrets kustomization"
require_file "$CILIUM_KUSTOMIZATION" "Cilium platform kustomization"
require_file "$LONGHORN_KUSTOMIZATION" "Longhorn platform kustomization"
mkdir -p "$OPERATOR_SECRET_DIR"

prepare_client "Hubble UI" kube-system hubble-ui-oidc-client hubble-ui hubble-ui-oidc-client.secret.yaml
prepare_client "Longhorn UI" longhorn-system longhorn-ui-oidc-client longhorn-ui longhorn-ui-oidc-client.secret.yaml
ensure_kustomization_resource "$CILIUM_KUSTOMIZATION" "hubble-ui-security-policy.yaml"
ensure_kustomization_resource "$LONGHORN_KUSTOMIZATION" "security-policy.yaml"

printf '%s\n' "Prepared encrypted operator UI OIDC client secrets."
printf '%s\n' "Next: ./scripts/dev/deploy-platform.sh"
