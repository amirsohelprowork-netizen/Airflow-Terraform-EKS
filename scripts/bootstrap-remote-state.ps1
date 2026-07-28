param(
    [string]$AwsRegion = "us-east-1"
)

Write-Host "NOTE: Prefer .\scripts\bootstrap.ps1 -BudgetAlertEmail you@example.com"
Write-Host "      It configures GitHub Actions automatically via 'gh'."
Write-Host ""

$Timestamp = Get-Date -Format "yyyyMMddHHmmss"
$BucketName = "airflow-eks-tfstate-$Timestamp"
$DynamoDbTable = "airflow-eks-tflock-$Timestamp"
$AccountId = aws sts get-caller-identity --query Account --output text

Write-Host "Creating Terraform state bucket: $BucketName"
if ($AwsRegion -eq "us-east-1") {
    aws s3api create-bucket --bucket $BucketName --region $AwsRegion
} else {
    aws s3api create-bucket --bucket $BucketName --region $AwsRegion --create-bucket-configuration LocationConstraint=$AwsRegion
}
aws s3api put-bucket-versioning --bucket $BucketName --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket $BucketName --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

Write-Host "Creating Terraform lock table: $DynamoDbTable"
aws dynamodb create-table `
    --table-name $DynamoDbTable `
    --attribute-definitions AttributeName=LockID,AttributeType=S `
    --key-schema AttributeName=LockID,KeyType=HASH `
    --billing-mode PAY_PER_REQUEST `
    --region $AwsRegion | Out-Null
aws dynamodb wait table-exists --table-name $DynamoDbTable --region $AwsRegion

Write-Host ""
Write-Host "Create GitHub Environment 'demo', then set variables/secrets:"
Write-Host "AWS_REGION=$AwsRegion"
Write-Host "AWS_ACCOUNT_ID=$AccountId"
Write-Host "TF_STATE_BUCKET=$BucketName"
Write-Host "TF_LOCK_TABLE=$DynamoDbTable"
Write-Host "TF_STATE_KEY=airflow-demo/terraform.tfstate"
Write-Host "TF_VAR_KUBERNETES_VERSION=<supported EKS version>"
Write-Host "TF_VAR_ADMIN_CIDR_BLOCKS=[`"0.0.0.0/0`"]"
Write-Host "BUDGET_ALERT_EMAIL=<your-email@example.com>"
Write-Host "BUDGET_LIMIT_USD=40"
Write-Host ""
Write-Host "Secrets: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AIRFLOW_ADMIN_PASSWORD, AIRFLOW_API_SECRET_KEY"
Write-Host "Or re-run: .\scripts\bootstrap.ps1 -BudgetAlertEmail you@example.com"
