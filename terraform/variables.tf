variable "project_name" {
  type    = string
  default = "airflow-enterprise"
}
variable "environment" {
  type    = string
  default = "demo"
}
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}
variable "kubernetes_version" {
  type        = string
  description = "A Kubernetes version currently supported by EKS in the target region."
}
variable "admin_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDRs permitted to reach the public EKS API endpoint. GitHub-hosted runners require 0.0.0.0/0; use a private endpoint and self-hosted runner for production."
}
variable "system_node_instance_type" {
  type        = string
  default     = "m7i-flex.large"
  description = "Free Tier-eligible on post-2025 Free plan accounts (8 GiB). t3.micro cannot host Airflow control-plane pods."
}
variable "worker_node_instance_type" {
  type        = string
  default     = "t3.small"
  description = "Free Tier-eligible worker size (2 GiB). Prefer scaling from zero over always-on micros."
}
variable "system_node_min_size" {
  type        = number
  default     = 2
  description = "Two m7i-flex.large nodes fit scheduler/api/triggerer/dag-processor without t3.micro OOM risk."
}
variable "system_node_max_size" {
  type        = number
  default     = 2
  description = "Keep system capacity fixed in the credit-capped demo profile."
}
variable "worker_node_min_size" {
  type        = number
  default     = 0
  description = "Zero warm workers: Cluster Autoscaler adds t3.small nodes only when KubernetesExecutor pods are Pending."
}
variable "max_worker_nodes" {
  type        = number
  default     = 2
  description = "Hard cap for demo cost control. Raise only after a measured load test."
}
variable "budget_limit_usd" {
  type        = number
  default     = 40
  description = "Monthly AWS Budget threshold (USD). Pair with budget_alert_email."
}
variable "budget_alert_email" {
  type        = string
  default     = ""
  description = "If set, creates a monthly cost budget with 50/80/100% notifications. Leave empty to skip."
}
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "postgres_version" {
  type    = string
  default = "16"
}
variable "enable_multi_az" {
  type        = bool
  default     = false
  description = "Enable for production; false keeps the time-boxed demo cost lower."
}
variable "backup_retention_days" {
  type    = number
  default = 1
}
variable "github_repository" {
  type        = string
  description = "GitHub repository in owner/name format allowed to deploy."
}
variable "terraform_state_bucket" {
  type        = string
  description = "Name of the pre-created S3 bucket used as the Terraform remote backend."
}
variable "terraform_lock_table" {
  type        = string
  description = "Name of the pre-created DynamoDB table used for Terraform state locking."
}
