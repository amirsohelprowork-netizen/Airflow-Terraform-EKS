

$AWS_REGION = "us-east-1"
$TIMESTAMP = Get-Date -Format "yyyyMMddHHmmss"
$BUCKET_NAME = "airflow-enterprise-demo-tfstate-$TIMESTAMP"
$DYNAMODB_TABLE = "airflow-enterprise-demo-tflock"

Write-Host "Creating S3 Bucket: $BUCKET_NAME in $AWS_REGION..."
aws s3api create-bucket --bucket $BUCKET_NAME --region $AWS_REGION

Write-Host "Enabling S3 Bucket Versioning..."
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled

Write-Host "Creating DynamoDB Table: $DYNAMODB_TABLE..."
$tableExists = aws dynamodb describe-table --table-name $DYNAMODB_TABLE 2>$null
if (-not $tableExists) {
    aws dynamodb create-table `
        --table-name $DYNAMODB_TABLE `
        --attribute-definitions AttributeName=LockID,AttributeType=S `
        --key-schema AttributeName=LockID,KeyType=HASH `
        --billing-mode PAY_PER_REQUEST `
        --region $AWS_REGION | Out-Null
    Write-Host "Waiting for DynamoDB table to become active..."
    aws dynamodb wait table-exists --table-name $DYNAMODB_TABLE --region $AWS_REGION
} else {
    Write-Host "DynamoDB Table $DYNAMODB_TABLE already exists."
}

$BACKEND_FILE = "terraform\backend.tf"
Write-Host "Generating $BACKEND_FILE..."

$backendConfig = @"
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "terraform.tfstate"
    region         = "$AWS_REGION"
    dynamodb_table = "$DYNAMODB_TABLE"
    encrypt        = true
  }
}
"@

Set-Content -Path $BACKEND_FILE -Value $backendConfig

Write-Host "Migrating local state to remote S3 backend..."
Set-Location terraform
terraform init -migrate-state -force-copy

Write-Host "✅ Terraform Remote State successfully bootstrapped and migrated!"
