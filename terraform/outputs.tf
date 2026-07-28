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
output "airflow_irsa_role_arn" { value = module.airflow_irsa.iam_role_arn }
output "cluster_autoscaler_irsa_role_arn" { value = module.cluster_autoscaler_irsa.iam_role_arn }
output "demo_capacity_summary" {
  value = {
    system_instance = var.system_node_instance_type
    system_nodes    = var.system_node_min_size
    worker_instance = var.worker_node_instance_type
    worker_min      = var.worker_node_min_size
    worker_max      = var.max_worker_nodes
    db_instance     = var.db_instance_class
    budget_usd      = var.budget_limit_usd
  }
}
