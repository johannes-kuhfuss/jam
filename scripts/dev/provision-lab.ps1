$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."
$TerraformDir = Join-Path $RepoRoot "infra\terraform\environments\lab"
$AnsibleDir = Join-Path $RepoRoot "infra\ansible"
$InventoryPath = Join-Path $AnsibleDir "inventories\lab\hosts.yml"

if (-not (Test-Path (Join-Path $TerraformDir "terraform.tfvars"))) {
    throw "Missing $TerraformDir\terraform.tfvars. Copy terraform.tfvars.example and fill in your Proxmox values."
}

Push-Location $TerraformDir
try {
    terraform init
    terraform apply

    $Nodes = terraform output -json k3s_nodes | ConvertFrom-Json
    $SshUser = terraform output -raw ssh_user
}
finally {
    Pop-Location
}

$ExampleInventory = Join-Path $AnsibleDir "inventories\lab\hosts.yml.example"
if (-not (Test-Path $InventoryPath)) {
    Copy-Item $ExampleInventory $InventoryPath
}

$InventoryLines = foreach ($Node in $Nodes) {
    @"
        $($Node.name):
          ansible_host: $($Node.ipv4_address)
          ansible_user: ${SshUser}
"@
}

$Inventory = @"
---
all:
  children:
    k3s_servers:
      hosts:
$($InventoryLines -join "`n")
"@

Set-Content -Path $InventoryPath -Value $Inventory

Push-Location $AnsibleDir
try {
    ansible-playbook -i inventories/lab/hosts.yml playbooks/bootstrap-nodes.yml
    ansible-playbook -i inventories/lab/hosts.yml playbooks/install-k3s.yml
}
finally {
    Pop-Location
}
