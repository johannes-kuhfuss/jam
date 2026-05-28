#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ANSIBLE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../ansible" && pwd)

cd "$ANSIBLE_DIR"
ansible-playbook -i inventories/lab/hosts.yml playbooks/bootstrap-nodes.yml
ansible-playbook -i inventories/lab/hosts.yml playbooks/install-k3s.yml
