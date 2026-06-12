#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

ZITADEL_DIR="$REPO_ROOT/infra/gitops/platform/auth/zitadel"
SECRETS_DIR="$REPO_ROOT/infra/gitops/secrets/lab"
SECRET_PLATFORM_DIR="$SECRETS_DIR/platform"
SECRET_PATH="$SECRET_PLATFORM_DIR/zitadel-masterkey.secret.yaml"
SECRET_RESOURCE="platform/zitadel-masterkey.secret.yaml"
SECRETS_KUSTOMIZATION="$SECRETS_DIR/kustomization.yaml"
ZITADEL_KUSTOMIZATION="$ZITADEL_DIR/kustomization.yaml"
HELM_RELEASE="$ZITADEL_DIR/helm-release.yaml"
HTTP_ROUTE_TEMPLATE="$ZITADEL_DIR/templates/http-route.yaml"
HTTP_ROUTE="$ZITADEL_DIR/http-route.yaml"

require_file() {
  path="$1"
  description="$2"

  if [ ! -f "$path" ]; then
    echo "Missing $description at $path." >&2
    exit 1
  fi
}

prompt_default() {
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

prompt_required() {
  label="$1"
  value=""

  while [ -z "$value" ]; do
    printf '%s: ' "$label" >&2
    read -r value
  done
  printf '%s' "$value"
}

prompt_secret() {
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

prompt_yes_no() {
  label="$1"
  default_value="$2"
  answer=""

  while :; do
    printf '%s [%s]: ' "$label" "$default_value" >&2
    read -r answer
    if [ -z "$answer" ]; then
      answer="$default_value"
    fi
    case "$answer" in
      y|Y|yes|YES) printf '%s' "yes"; return 0 ;;
      n|N|no|NO) printf '%s' "no"; return 0 ;;
      *) echo "Please answer yes or no." >&2 ;;
    esac
  done
}

generate_masterkey() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c 1-32
    return 0
  fi

  if [ -r /dev/urandom ]; then
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32
    printf '\n'
    return 0
  fi

  echo "Could not generate a master key automatically. Enter one manually." >&2
  return 1
}

yaml_single_quote() {
  printf "%s" "$1" | sed "s/'/''/g"
}

ensure_kustomization_resource() {
  file_path="$1"
  resource_path="$2"
  tmp_path="$file_path.tmp"

  if grep -Fq -- "- $resource_path" "$file_path"; then
    return 0
  fi

  if grep -Fq "resources: []" "$file_path"; then
    sed "s|resources: \[\]|resources:\\
  - $resource_path|" "$file_path" > "$tmp_path"
    mv "$tmp_path" "$file_path"
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

update_helm_release() {
  external_domain="$1"
  admin_username="$2"
  admin_email="$3"
  admin_password="$4"
  tmp_path="$HELM_RELEASE.tmp"

  external_domain_q=$(yaml_single_quote "$external_domain")
  admin_username_q=$(yaml_single_quote "$admin_username")
  admin_email_q=$(yaml_single_quote "$admin_email")
  admin_password_q=$(yaml_single_quote "$admin_password")

  awk \
    -v external_domain="$external_domain_q" \
    -v admin_username="$admin_username_q" \
    -v admin_email="$admin_email_q" \
    -v admin_password="$admin_password_q" '
      /^  suspend:/ {
        print "  suspend: false"
        next
      }
      /^        ExternalDomain:/ {
        print "        ExternalDomain: '\''" external_domain "'\''"
        next
      }
      /^              UserName:/ {
        print "              UserName: '\''" admin_username "'\''"
        next
      }
      /^              Email:/ {
        print "              Email: '\''" admin_email "'\''"
        next
      }
      /^              Password:/ {
        print "              Password: '\''" admin_password "'\''"
        next
      }
      /^    postgresql:/ {
        print
        next
      }
      { print }
    ' "$HELM_RELEASE" > "$tmp_path"

  mv "$tmp_path" "$HELM_RELEASE"
}

update_http_route() {
  external_domain="$1"
  tmp_path="$HTTP_ROUTE.tmp"

  if [ ! -f "$HTTP_ROUTE" ]; then
    cp "$HTTP_ROUTE_TEMPLATE" "$HTTP_ROUTE"
  fi

  awk -v external_domain="$external_domain" '
    /^    - / && previous_hostnames {
      print "    - " external_domain
      previous_hostnames = 0
      next
    }
    /^  hostnames:/ {
      previous_hostnames = 1
      print
      next
    }
    { print }
  ' "$HTTP_ROUTE" > "$tmp_path"

  mv "$tmp_path" "$HTTP_ROUTE"
}

write_masterkey_secret() {
  masterkey="$1"

  mkdir -p "$SECRET_PLATFORM_DIR"

  if [ -f "$SECRET_PATH" ]; then
    overwrite=$(prompt_yes_no "Secret file already exists. Overwrite it" "no")
    if [ "$overwrite" != "yes" ]; then
      echo "Keeping existing $SECRET_PATH."
      return 0
    fi
  fi

  cat > "$SECRET_PATH" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: zitadel-masterkey
  namespace: zitadel
type: Opaque
stringData:
  masterkey: $masterkey
EOF
}

require_file "$HELM_RELEASE" "ZITADEL HelmRelease"
require_file "$ZITADEL_KUSTOMIZATION" "ZITADEL kustomization"
require_file "$SECRETS_KUSTOMIZATION" "lab secrets kustomization"
require_file "$HTTP_ROUTE_TEMPLATE" "ZITADEL HTTPRoute template"

external_domain=$(prompt_default "External ZITADEL hostname" "auth.mam.jku.internal")
admin_username=$(prompt_default "First instance admin username" "admin")
admin_email=$(prompt_required "First instance admin email")
admin_password=$(prompt_secret "First instance admin password")
use_bundled_postgresql=$(prompt_yes_no "Use bundled PostgreSQL chart for the lab" "yes")

if [ "$use_bundled_postgresql" != "yes" ]; then
  echo "External PostgreSQL values are not scaffolded in this repository yet." >&2
  echo "Configure the chart manually, then unsuspend the HelmRelease." >&2
  exit 1
fi

generate_key=$(prompt_yes_no "Generate a 32-character ZITADEL master key" "yes")
if [ "$generate_key" = "yes" ]; then
  masterkey=$(generate_masterkey)
else
  masterkey=$(prompt_required "ZITADEL master key")
fi

masterkey_length=$(printf '%s' "$masterkey" | wc -c | tr -d ' ')
if [ "$masterkey_length" != "32" ]; then
  echo "ZITADEL master key must be exactly 32 characters. Got $masterkey_length." >&2
  exit 1
fi

case "$masterkey" in
  *[!A-Za-z0-9]*)
    echo "ZITADEL master key must contain only alphanumeric characters." >&2
    exit 1
    ;;
esac

write_masterkey_secret "$masterkey"
ensure_kustomization_resource "$SECRETS_KUSTOMIZATION" "$SECRET_RESOURCE"
update_http_route "$external_domain"
ensure_kustomization_resource "$ZITADEL_KUSTOMIZATION" "http-route.yaml"
update_helm_release "$external_domain" "$admin_username" "$admin_email" "$admin_password"

printf '%s\n' "Prepared ZITADEL GitOps files."
printf '%s\n' "Next: encrypt the generated Secret before committing:"
printf '%s\n' "  sops --encrypt --in-place infra/gitops/secrets/lab/platform/zitadel-masterkey.secret.yaml"
printf '%s\n' "Then: review, commit, and push the GitOps changes."
printf '%s\n' "Then: ./scripts/dev/bootstrap-gitops.sh"
