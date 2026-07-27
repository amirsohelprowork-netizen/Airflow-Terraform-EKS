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
  description = "Trusted public CIDRs permitted to reach the EKS API endpoint."
}
variable "system_node_instance_type" {
  type    = string
  default = "t3.large"
}
variable "worker_node_instance_type" {
  type    = string
  default = "t3.large"
}
variable "max_worker_nodes" {
  type    = number
  default = 10
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
