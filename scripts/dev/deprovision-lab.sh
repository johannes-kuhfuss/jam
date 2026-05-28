#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
TERRAFORM_DIR="$REPO_ROOT/infra/terraform/environments/lab"
INVENTORY_PATH="$REPO_ROOT/infra/ansible/inventories/lab/hosts.yml"
KUBECONFIG_DIR="$REPO_ROOT/infra/k3s/generated"

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

rm -f "$INVENTORY_PATH"

if [ -d "$KUBECONFIG_DIR" ]; then
  find "$KUBECONFIG_DIR" -maxdepth 1 -type f -name '*.yaml' -delete
fi

printf '%s\n' "Lab resources destroyed. Removed generated inventory and kubeconfig files."
