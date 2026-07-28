<#
.SYNOPSIS
  One-time bootstrap for forks: Terraform remote state + GitHub Actions vars/secrets.

.DESCRIPTION
  Creates S3 + DynamoDB for Terraform state, detects a supported EKS version,
  generates Airflow secrets, creates the GitHub Environment "demo", and configures
  repository variables/secrets via the GitHub CLI.

.PARAMETER AwsRegion
  AWS region (default us-east-1).

.PARAMETER BudgetAlertEmail
  Email for the AWS Budget alert (strongly recommended).

.PARAMETER BudgetLimitUsd
  Monthly budget threshold (default 40).

.PARAMETER SkipGithub
  Only create AWS state backend; print values instead of calling gh.
#>
param(
    [string]$AwsRegion = "us-east-1",
    [Parameter(Mandatory = $true)]
    [string]$BudgetAlertEmail,
    [string]$BudgetLimitUsd = "40",
    [string]$AwsAccessKeyId = $env:AWS_ACCESS_KEY_ID,
    [string]$AwsSecretAccessKey = $env:AWS_SECRET_ACCESS_KEY,
    [switch]$SkipGithub
)

$ErrorActionPreference = "Stop"

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function New-RandomSecret([int]$Length = 32) {
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return ([Convert]::ToBase64String($bytes) -replace '[+/=]', 'x').Substring(0, [Math]::Min($Length, 40))
}

Require-Command aws

Write-Host "==> Checking AWS identity..."
$AccountId = aws sts get-caller-identity --query Account --output text
if (-not $AccountId -or $AccountId -eq "None") {
    throw "aws sts get-caller-identity failed. Run: aws configure"
}
Write-Host "    Account: $AccountId  Region: $AwsRegion"

Write-Host "==> Detecting a supported EKS Kubernetes version..."
$versions = aws eks describe-addon-versions `
    --region $AwsRegion `
    --addon-name vpc-cni `
    --query "addons[0].addonVersions[].compatibilities[].clusterVersion" `
    --output text 2>$null
if (-not $versions) {
    throw "Could not detect EKS versions in $AwsRegion. Set TF_VAR_KUBERNETES_VERSION manually later."
}
$K8sVersion = ($versions -split "\s+" | Where-Object { $_ } | Sort-Object -Unique | Select-Object -Last 1)
Write-Host "    Using Kubernetes $K8sVersion"

$Timestamp = Get-Date -Format "yyyyMMddHHmmss"
$BucketName = "airflow-eks-tfstate-$Timestamp"
$DynamoDbTable = "airflow-eks-tflock-$Timestamp"
$StateKey = "airflow-demo/terraform.tfstate"

Write-Host "==> Creating Terraform state bucket: $BucketName"
if ($AwsRegion -eq "us-east-1") {
    aws s3api create-bucket --bucket $BucketName --region $AwsRegion | Out-Null
} else {
    aws s3api create-bucket --bucket $BucketName --region $AwsRegion `
        --create-bucket-configuration "LocationConstraint=$AwsRegion" | Out-Null
}
aws s3api put-bucket-versioning --bucket $BucketName --versioning-configuration Status=Enabled | Out-Null
aws s3api put-public-access-block --bucket $BucketName `
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true | Out-Null

Write-Host "==> Creating Terraform lock table: $DynamoDbTable"
aws dynamodb create-table `
    --table-name $DynamoDbTable `
    --attribute-definitions AttributeName=LockID,AttributeType=S `
    --key-schema AttributeName=LockID,KeyType=HASH `
    --billing-mode PAY_PER_REQUEST `
    --region $AwsRegion | Out-Null
aws dynamodb wait table-exists --table-name $DynamoDbTable --region $AwsRegion

$AdminPassword = New-RandomSecret 24
$ApiSecretKey = New-RandomSecret 48

Write-Host ""
Write-Host "Generated Airflow admin password (save this): $AdminPassword"
Write-Host ""

if ($SkipGithub) {
    Write-Host "SkipGithub set — configure GitHub manually with values below."
} else {
    Require-Command gh
    $ghAuth = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI not logged in. Run: gh auth login"
    }

    $Repo = gh repo view --json nameWithOwner -q .nameWithOwner
    if (-not $Repo) {
        throw "Could not detect GitHub repo. Run this from a clone of your fork, or: gh repo set-default"
    }
    Write-Host "==> Configuring GitHub repo: $Repo"

    Write-Host "    Ensuring Environment 'demo' exists..."
    gh api --method PUT "repos/$Repo/environments/demo" --silent 2>$null

    if (-not $AwsAccessKeyId -or -not $AwsSecretAccessKey) {
        Write-Host ""
        Write-Host "Enter IAM access keys for GitHub Actions (infra/destroy only — not root):"
        $AwsAccessKeyId = Read-Host "AWS_ACCESS_KEY_ID"
        $secure = Read-Host "AWS_SECRET_ACCESS_KEY" -AsSecureString
        $AwsSecretAccessKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        )
    }
    if (-not $AwsAccessKeyId -or -not $AwsSecretAccessKey) {
        throw "AWS access keys are required to set GitHub secrets."
    }

    Write-Host "    Setting repository variables..."
    gh variable set AWS_REGION --body $AwsRegion --repo $Repo
    gh variable set AWS_ACCOUNT_ID --body $AccountId --repo $Repo
    gh variable set TF_STATE_BUCKET --body $BucketName --repo $Repo
    gh variable set TF_LOCK_TABLE --body $DynamoDbTable --repo $Repo
    gh variable set TF_STATE_KEY --body $StateKey --repo $Repo
    gh variable set TF_VAR_KUBERNETES_VERSION --body $K8sVersion --repo $Repo
    gh variable set TF_VAR_ADMIN_CIDR_BLOCKS --body '["0.0.0.0/0"]' --repo $Repo
    gh variable set BUDGET_ALERT_EMAIL --body $BudgetAlertEmail --repo $Repo
    gh variable set BUDGET_LIMIT_USD --body $BudgetLimitUsd --repo $Repo

    Write-Host "    Setting repository secrets..."
    $AwsAccessKeyId | gh secret set AWS_ACCESS_KEY_ID --repo $Repo
    $AwsSecretAccessKey | gh secret set AWS_SECRET_ACCESS_KEY --repo $Repo
    $AdminPassword | gh secret set AIRFLOW_ADMIN_PASSWORD --repo $Repo
    $ApiSecretKey | gh secret set AIRFLOW_API_SECRET_KEY --repo $Repo

    Write-Host "==> GitHub configuration complete."
}

Write-Host ""
Write-Host "=========================================="
Write-Host " NEXT STEPS"
Write-Host "=========================================="
Write-Host "1. Open GitHub Actions on your fork."
Write-Host "2. Run workflow: Deploy Infrastructure  (wait until green)."
Write-Host "3. Run workflow: Deploy Airflow to EKS  (wait until green)."
Write-Host "4. Open the UI:"
Write-Host "     .\scripts\open-airflow.ps1"
Write-Host "   Login: admin / (password printed above)"
Write-Host "5. When finished, run: Destroy Demo Stack  (type destroy)."
Write-Host ""
Write-Host "State backend: s3://$BucketName/$StateKey  lock=$DynamoDbTable"
Write-Host "Docs: README.md  and  docs/TROUBLESHOOTING.md"
