$ErrorActionPreference = "Stop"

Push-Location "$PSScriptRoot\..\..\ansible"
try {
    ansible-playbook -i inventories/lab/hosts.yml playbooks/bootstrap-nodes.yml
    ansible-playbook -i inventories/lab/hosts.yml playbooks/install-k3s.yml
}
finally {
    Pop-Location
}
