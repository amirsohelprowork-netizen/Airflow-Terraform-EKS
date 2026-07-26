terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project      = var.project_name
      Environment  = var.environment
      ManagedBy    = "terraform"
      Architecture = "eks-kubernetesexecutor"
    }
  }
}

data "aws_availability_zones" "available" { state = "available" }

locals {
  name = "${var.project_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = local.name
  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets = ["10.40.0.0/20", "10.40.16.0/20", "10.40.32.0/20"]
  public_subnets  = ["10.40.48.0/24", "10.40.49.0/24", "10.40.50.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # demo cost control; use one NAT Gateway per AZ in production
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.0"

  cluster_name    = local.name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access           = true
  cluster_endpoint_public_access_cidrs     = var.admin_cidr_blocks
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  eks_managed_node_groups = {
    system = {
      name           = "system"
      instance_types = [var.system_node_instance_type]
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      labels         = { workload = "airflow-system" }
      iam_role_additional_policies = {
        s3 = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
      }
    }
    workers = {
      name           = "workers"
      instance_types = [var.worker_node_instance_type]
      min_size       = 0
      max_size       = var.max_worker_nodes
      desired_size   = 0
      labels         = { workload = "airflow-task" }
      taints = {
        airflow = { key = "workload", value = "airflow-task", effect = "NO_SCHEDULE" }
      }
      iam_role_additional_policies = {
        s3 = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
      }
    }
  }

  access_entries = {
    github_deploy = {
      principal_arn = aws_iam_role.github_deploy.arn
      policy_associations = {
        airflow_namespace = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
          access_scope = { type = "namespace", namespaces = ["airflow"] }
        }
      }
    }
  }
}

resource "aws_security_group" "postgres" {
  name_prefix = "${local.name}-postgres-"
  description = "Airflow metadata database access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "airflow" {
  name       = "${local.name}-airflow"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_db_instance" "airflow" {
  identifier                  = "${local.name}-airflow"
  engine                      = "postgres"
  engine_version              = var.postgres_version
  instance_class              = var.db_instance_class
  allocated_storage           = 30
  max_allocated_storage       = 100
  storage_encrypted           = true
  multi_az                    = var.enable_multi_az
  db_name                     = "airflow"
  username                    = "airflow"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.airflow.name
  vpc_security_group_ids      = [aws_security_group.postgres.id]
  backup_retention_period     = var.backup_retention_days
  deletion_protection         = false
  skip_final_snapshot         = true # demo only; production must require a final snapshot
  publicly_accessible         = false
  apply_immediately           = true
}

resource "aws_s3_bucket" "airflow" { bucket_prefix = "${local.name}-airflow-" }
resource "aws_s3_bucket_versioning" "airflow" {
  bucket = aws_s3_bucket.airflow.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_public_access_block" "airflow" {
  bucket                  = aws_s3_bucket.airflow.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ecr_repository" "airflow" {
  name                 = "${local.name}/airflow"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}
