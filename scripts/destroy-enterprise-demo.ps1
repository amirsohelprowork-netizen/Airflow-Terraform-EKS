# Deliberately requires an explicit confirmation before deleting the new EKS demo.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('DESTROY-EKS-DEMO')][string]$Confirm,
    [string]$TerraformDirectory = 'terraform'
)

$ErrorActionPreference = 'Stop'
if ($Confirm -ne 'DESTROY-EKS-DEMO') { throw 'Confirmation did not match.' }
Push-Location $TerraformDirectory
try {
    terraform init
    terraform destroy -auto-approve
}
finally {
    Pop-Location
}
