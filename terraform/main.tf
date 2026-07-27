terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
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

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
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

  enable_irsa = true

  cluster_endpoint_public_access           = true
  cluster_endpoint_public_access_cidrs     = var.admin_cidr_blocks
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni = {
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  eks_managed_node_groups = {
    system = {
      name           = "system-v2"
      instance_types = [var.system_node_instance_type]
      min_size       = 3
      max_size       = 5
      desired_size   = 3
      labels         = { workload = "airflow-system" }
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
    }
  }

  access_entries = {
    github_deploy = {
      principal_arn = aws_iam_role.github_deploy.arn
      policy_associations = {
        airflow_namespace = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}

resource "kubernetes_namespace" "airflow" {
  metadata {
    name = "airflow"
  }
  depends_on = [module.eks]
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

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_db_instance.airflow.master_user_secret[0].secret_arn
}

resource "kubernetes_secret" "airflow_metadata" {
  metadata {
    name      = "airflow-metadata"
    namespace = kubernetes_namespace.airflow.metadata[0].name
  }
  data = {
    connection = "postgresql://${aws_db_instance.airflow.username}:${jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]}@${aws_db_instance.airflow.endpoint}/${aws_db_instance.airflow.db_name}"
  }
  type = "Opaque"
}

resource "aws_s3_bucket" "airflow" { 
  bucket_prefix = "${local.name}-airflow-" 
  force_destroy = true
}
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

# ---------------------------------------------------------
# IRSA: Least Privilege IAM Role for Airflow ServiceAccounts
# ---------------------------------------------------------
data "aws_iam_policy_document" "airflow_s3" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      aws_s3_bucket.airflow.arn,
      "${aws_s3_bucket.airflow.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "airflow_s3" {
  name_prefix = "${local.name}-airflow-s3-"
  description = "Allows Airflow Pods to write logs to S3"
  policy      = data.aws_iam_policy_document.airflow_s3.json
}

module "airflow_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.44.0"

  role_name = "${local.name}-airflow-irsa"

  role_policy_arns = {
    s3 = aws_iam_policy.airflow_s3.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "airflow:airflow-worker", 
        "airflow:airflow-scheduler",
        "airflow:airflow-webserver"
      ]
    }
  }
}
