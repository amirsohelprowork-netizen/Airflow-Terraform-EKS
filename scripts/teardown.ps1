param(
    [string]$AwsRegion = "us-east-1",
    [string]$Namespace = "airflow"
)

# Local teardown helper when GitHub Actions Destroy workflow is not used.
# Order: Helm first, then terraform destroy (avoids orphaned K8s objects in state).

$ErrorActionPreference = "Stop"

Write-Host "Resolving EKS cluster from Terraform state..."
Push-Location (Join-Path $PSScriptRoot "..\terraform")
try {
    $ClusterName = terraform output -raw cluster_name
} finally {
    Pop-Location
}

Write-Host "Updating kubeconfig for $ClusterName"
aws eks update-kubeconfig --name $ClusterName --region $AwsRegion

Write-Host "Uninstalling Helm releases..."
helm uninstall airflow -n $Namespace 2>$null
helm uninstall cluster-autoscaler -n kube-system 2>$null

Write-Host "Running terraform destroy..."
Push-Location (Join-Path $PSScriptRoot "..\terraform")
try {
    terraform destroy -auto-approve
} finally {
    Pop-Location
}

Write-Host "Teardown complete. Delete the state bucket/lock table only if you no longer need them."
