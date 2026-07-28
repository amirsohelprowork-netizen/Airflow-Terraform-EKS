param(
    [string]$AwsRegion = "us-east-1"
)

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
Write-Host "Set these GitHub Actions repository variables before the first infrastructure run:"
Write-Host "AWS_REGION=$AwsRegion"
Write-Host "AWS_ACCOUNT_ID=$AccountId"
Write-Host "TF_STATE_BUCKET=$BucketName"
Write-Host "TF_LOCK_TABLE=$DynamoDbTable"
Write-Host "TF_STATE_KEY=airflow-demo/terraform.tfstate"
Write-Host "TF_VAR_KUBERNETES_VERSION=<EKS version supported in $AwsRegion>"
Write-Host "TF_VAR_ADMIN_CIDR_BLOCKS=[`"0.0.0.0/0`"]   # JSON list required by Terraform (CI also accepts bare 0.0.0.0/0)"
Write-Host "BUDGET_ALERT_EMAIL=<your-email@example.com>"
Write-Host "BUDGET_LIMIT_USD=40"
Write-Host ""
Write-Host "After Deploy Infrastructure succeeds, optionally set:"
Write-Host "GITHUB_DEPLOY_ROLE_ARN=<terraform output github_deploy_role_arn>"
Write-Host ""
Write-Host "Demo defaults: 2x m7i-flex.large system, t3.small workers from 0, db.t3.micro."
Write-Host "Destroy the stack the same day via the Destroy Demo Stack workflow."
Write-Host "This script intentionally does not write backend.tf into the repository."
