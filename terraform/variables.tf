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
  type    = string
  default = "t3.small"
}
variable "worker_node_instance_type" {
  type    = string
  default = "t3.small"
}
variable "system_node_min_size" {
  type        = number
  default     = 3
  description = "Three Free Tier-eligible micro nodes spread the demo control plane. Production sizing requires load testing."
}
variable "system_node_max_size" {
  type        = number
  default     = 3
  description = "Maximum system nodes for the cost-capped demo profile."
}
variable "worker_node_min_size" {
  type        = number
  default     = 1
  description = "Set to 1 to guarantee a worker node is always ready for tasks, bypassing autoscaler delay."
}
variable "max_worker_nodes" {
  type    = number
  default = 3
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
