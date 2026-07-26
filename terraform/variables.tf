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

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (min 2 for MWAA)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (min 2 for MWAA)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

# ---------- MWAA ----------
variable "airflow_version" {
  description = "Apache Airflow version for MWAA"
  type        = string
  default     = "2.9.2"
}

variable "environment_class" {
  description = "MWAA environment class (mw1.small, mw1.medium, mw1.large)"
  type        = string
  default     = "mw1.small"
}

variable "max_workers" {
  description = "Maximum number of Airflow workers"
  type        = number
  default     = 2
}

variable "min_workers" {
  description = "Minimum number of Airflow workers"
  type        = number
  default     = 1
}

variable "webserver_access_mode" {
  description = "Webserver access mode: PUBLIC_ONLY or PRIVATE_ONLY"
  type        = string
  default     = "PUBLIC_ONLY"

  validation {
    condition     = contains(["PUBLIC_ONLY", "PRIVATE_ONLY"], var.webserver_access_mode)
    error_message = "webserver_access_mode must be PUBLIC_ONLY or PRIVATE_ONLY."
  }
}

variable "dag_s3_path" {
  description = "S3 path prefix for DAGs inside the bucket"
  type        = string
  default     = "dags/"
}

variable "requirements_s3_path" {
  description = "S3 path for the requirements.txt file"
  type        = string
  default     = "requirements/requirements.txt"
}

# ---------- Logging ----------
variable "logging_level" {
  description = "Airflow logging level"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"], var.logging_level)
    error_message = "logging_level must be one of: CRITICAL, ERROR, WARNING, INFO, DEBUG."
  }
}
