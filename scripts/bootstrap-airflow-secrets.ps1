# Creates only Kubernetes references to values held in AWS Secrets Manager.
# Prerequisites: Terraform applied, kubectl authenticated to the EKS cluster.
# This script never prints secret values.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ClusterName,
    [Parameter(Mandatory = $true)][string]$DbMasterSecretArn,
    [string]$Region = 'us-east-1',
    [string]$Namespace = 'airflow'
)

$ErrorActionPreference = 'Stop'
aws eks update-kubeconfig --name $ClusterName --region $Region | Out-Null
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - | Out-Null

# Retrieve the managed RDS secret only in memory, then create the chart's
# expected metadata connection secret. Do not redirect, echo, or commit it.
$rdsSecret = aws secretsmanager get-secret-value --secret-id $DbMasterSecretArn --region $Region --query SecretString --output text | ConvertFrom-Json
$dbHost = (aws rds describe-db-instances --region $Region --query "DBInstances[?MasterUserSecret.SecretArn=='$DbMasterSecretArn'].Endpoint.Address | [0]" --output text)
if (-not $dbHost -or $dbHost -eq 'None') { throw 'Could not resolve the RDS endpoint from the supplied secret ARN.' }

$connection = "postgresql+psycopg2://$($rdsSecret.username):$($rdsSecret.password)@$dbHost`:5432/airflow?sslmode=require"
# Pass the value directly to kubectl rather than writing it to a temporary file.
& kubectl -n $Namespace create secret generic airflow-metadata "--from-literal=connection=$connection" --dry-run=client -o yaml |
    kubectl apply -f - | Out-Null

Write-Host "Created/updated the $Namespace/airflow-metadata secret without printing its value." -ForegroundColor Green
Write-Host 'For production, replace this bootstrap pattern with External Secrets + AWS Secrets Manager or EKS Pod Identity.' -ForegroundColor Yellow
