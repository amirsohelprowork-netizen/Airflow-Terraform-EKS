output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "airflow_db_endpoint" { value = aws_db_instance.airflow.address }
output "airflow_db_master_secret_arn" {
  value     = aws_db_instance.airflow.master_user_secret[0].secret_arn
  sensitive = true
}
output "airflow_bucket_name" { value = aws_s3_bucket.airflow.bucket }
output "airflow_ecr_repository_url" { value = aws_ecr_repository.airflow.repository_url }
output "github_deploy_role_arn" { value = aws_iam_role.github_deploy.arn }
