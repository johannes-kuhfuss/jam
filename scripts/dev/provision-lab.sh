#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
TERRAFORM_DIR="$REPO_ROOT/infra/terraform/environments/lab"
ANSIBLE_DIR="$REPO_ROOT/infra/ansible"
INVENTORY_PATH="$ANSIBLE_DIR/inventories/lab/hosts.yml"

remove_known_host_entries() {
  command -v ssh-keygen >/dev/null 2>&1 || return 0

  while IFS= read -r host; do
    [ -n "$host" ] || continue
    ssh-keygen -R "$host" >/dev/null 2>&1 || true
  done
}

if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
  echo "Missing $TERRAFORM_DIR/terraform.tfvars. Copy terraform.tfvars.example and fill in your Proxmox values." >&2
  exit 1
fi

command -v terraform >/dev/null 2>&1 || {
  echo "terraform is required but was not found in PATH." >&2
  exit 1
}

command -v ansible-playbook >/dev/null 2>&1 || {
  echo "ansible-playbook is required but was not found in PATH." >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || {
  echo "jq is required but was not found in PATH." >&2
  exit 1
}

cd "$TERRAFORM_DIR"
terraform init
terraform apply

NODES_JSON=$(terraform output -json k3s_nodes)
SSH_USER=$(terraform output -raw ssh_user)

printf '%s\n' "$NODES_JSON" | jq -r '.[].ipv4_address' | remove_known_host_entries

{
  printf '%s\n' '---'
  printf '%s\n' 'all:'
  printf '%s\n' '  children:'
  printf '%s\n' '    k3s_servers:'
  printf '%s\n' '      hosts:'
  printf '%s\n' "$NODES_JSON" | jq -r --arg ssh_user "$SSH_USER" '.[] | "        \(.name):\n          ansible_host: \(.ipv4_address)\n          ansible_user: \($ssh_user)"'
} > "$INVENTORY_PATH"

cd "$ANSIBLE_DIR"
ansible-playbook -i inventories/lab/hosts.yml playbooks/bootstrap-nodes.yml
ansible-playbook -i inventories/lab/hosts.yml playbooks/install-k3s.yml
