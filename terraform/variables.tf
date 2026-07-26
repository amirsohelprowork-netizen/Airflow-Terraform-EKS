####################################################
# Input Variables
####################################################

# ---------- General ----------
variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "airflow-prod"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# ---------- VPC ----------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# ---------- EC2 ----------
variable "instance_type" {
  description = "EC2 instance type (t3.medium recommended for Airflow)"
  type        = string
  default     = "t3.medium"
}

variable "airflow_ui_port" {
  description = "Port for Airflow web UI"
  type        = number
  default     = 8080
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Airflow UI and SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production!
}

variable "airflow_admin_username" {
  description = "Airflow admin username"
  type        = string
  default     = "admin"
}

variable "airflow_admin_password" {
  description = "Airflow admin password"
  type        = string
  default     = "AirflowAdmin123!"
  sensitive   = true
}

variable "airflow_image_tag" {
  description = "Apache Airflow Docker image tag"
  type        = string
  default     = "2.9.2"
}
