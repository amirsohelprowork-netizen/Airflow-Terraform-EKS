param(
    [string]$AwsRegion = "us-east-1",
    [string]$Namespace = "airflow",
    [int]$LocalPort = 8080
)

$ErrorActionPreference = "Stop"

Write-Host "Resolving EKS cluster..."
$clusters = aws eks list-clusters --region $AwsRegion --query "clusters[?contains(@, 'airflow')]" --output text
if (-not $clusters) {
    $clusters = aws eks list-clusters --region $AwsRegion --query "clusters[0]" --output text
}
$ClusterName = ($clusters -split "\s+" | Select-Object -First 1)
if (-not $ClusterName -or $ClusterName -eq "None") {
    throw "No EKS cluster found in $AwsRegion. Did Deploy Infrastructure succeed?"
}

Write-Host "Using cluster: $ClusterName"
aws eks update-kubeconfig --name $ClusterName --region $AwsRegion | Out-Null

Write-Host "Waiting for api-server service..."
kubectl -n $Namespace get svc airflow-api-server | Out-Null

Write-Host ""
Write-Host "Port-forwarding http://127.0.0.1:$LocalPort  (Ctrl+C to stop)"
Write-Host "Login user: admin"
Write-Host "Password: GitHub secret AIRFLOW_ADMIN_PASSWORD (printed by bootstrap)"
Write-Host ""
kubectl -n $Namespace port-forward "svc/airflow-api-server" "${LocalPort}:8080"
