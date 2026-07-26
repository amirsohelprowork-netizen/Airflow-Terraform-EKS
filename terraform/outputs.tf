####################################################
# Outputs
####################################################

output "mwaa_environment_arn" {
  description = "ARN of the MWAA environment"
  value       = aws_mwaa_environment.this.arn
}

output "mwaa_webserver_url" {
  description = "URL for the Airflow web UI"
  value       = "https://${aws_mwaa_environment.this.webserver_url}"
}

output "mwaa_status" {
  description = "Status of the MWAA environment"
  value       = aws_mwaa_environment.this.status
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket storing DAGs"
  value       = aws_s3_bucket.mwaa.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.mwaa.arn
}

output "mwaa_execution_role_arn" {
  description = "ARN of the MWAA execution role"
  value       = aws_iam_role.mwaa_execution.arn
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

# ---------- Helpful commands ----------
output "destroy_warning" {
  description = "Reminder to destroy resources when done testing"
  value       = "⚠️  Remember to run 'terraform destroy' when done testing to avoid charges!"
}
