# 🚀 Airflow on AWS — Enterprise IaC Deployment

Production-grade Apache Airflow deployment on AWS using **MWAA** (Managed Workflows for Apache Airflow), **Terraform** for infrastructure, and **GitHub Actions** for CI/CD.

## Architecture

```
Developer → Git Push → GitHub Actions → S3 Bucket → AWS MWAA (Airflow)
```

- **Infrastructure**: Terraform provisions VPC, S3, IAM, and MWAA
- **DAG Deployment**: Push DAGs to Git → CI validates → syncs to S3 → MWAA picks them up
- **Airflow UI**: Publicly accessible web UI (configurable to private)

## Prerequisites

| Tool | Version | Install Command |
|------|---------|-----------------|
| Terraform | ≥ 1.5 | `winget install HashiCorp.Terraform` |
| AWS CLI | v2 | `winget install Amazon.AWSCLI` |
| Git | any | Already installed |
| Python | ≥ 3.11 | For local DAG validation |

## Quick Start

### 1. Configure AWS CLI

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region (us-east-1)
```

### 2. Deploy Infrastructure

```bash
# Navigate to terraform directory
cd terraform

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your preferred values

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy (takes ~25-30 minutes for MWAA)
terraform apply
```

### 3. Upload Initial DAGs

```bash
# Get the S3 bucket name from Terraform output
export BUCKET=$(terraform output -raw s3_bucket_name)

# Sync DAGs to S3
aws s3 sync ../dags/ s3://$BUCKET/dags/
```

### 4. Access Airflow UI

```bash
# Get the Airflow URL
terraform output mwaa_webserver_url

# Open in browser — authenticate via AWS SSO/IAM
```

### 5. Set Up CI/CD (GitHub)

1. Push this repo to GitHub
2. Go to **Settings → Secrets and variables → Actions**
3. Add these secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION` (e.g., `us-east-1`)
   - `MWAA_S3_BUCKET` (from `terraform output s3_bucket_name`)
4. (Optional) Create a `production` environment with required reviewers for Terraform changes

### 6. Deploy DAGs via CI/CD

```bash
# Edit or add a DAG
vi dags/my_new_dag.py

# Push to GitHub
git add dags/
git commit -m "feat: add new data pipeline DAG"
git push origin main

# GitHub Actions will:
# 1. Validate the DAG syntax
# 2. Sync to S3
# 3. MWAA picks it up in ~30 seconds
```

## Project Structure

```
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                   # Provider config
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Output values
│   ├── vpc.tf                    # VPC, subnets, NAT, IGW
│   ├── s3.tf                     # S3 bucket for DAGs
│   ├── iam.tf                    # IAM roles and policies
│   ├── mwaa.tf                   # MWAA environment
│   ├── security_groups.tf        # Security groups
│   └── terraform.tfvars.example  # Example variables
│
├── dags/                         # Airflow DAGs
│   └── example_dag.py            # Sample DAG
│
├── requirements/
│   └── requirements.txt          # Python packages for Airflow
│
├── .github/workflows/
│   ├── deploy-dags.yml           # CI/CD for DAG deployment
│   └── terraform.yml             # CI/CD for infrastructure
│
├── scripts/
│   └── validate_dags.py          # DAG validation script
│
├── .gitignore
└── README.md
```

## Cost Estimate

| Resource | Cost/Day | Notes |
|----------|----------|-------|
| MWAA (mw1.small) | ~$11.76 | Minimum instance |
| NAT Gateway | ~$1.08 | Single AZ |
| S3 + Logs | ~$0.10 | Negligible |
| **Total** | **~$13/day** | — |

> ⚠️ **Always run `terraform destroy` when done testing!**

## Cleanup

```bash
cd terraform
terraform destroy
# Type 'yes' to confirm — this removes ALL resources
```

## CI/CD Workflows

### DAG Deployment (`deploy-dags.yml`)
- **Trigger**: Push to `main` affecting `dags/` or `requirements/`
- **Steps**: Validate Python → Sync to S3
- **PR**: Validates only (no deployment)

### Infrastructure (`terraform.yml`)
- **Trigger**: Push to `main` affecting `terraform/`
- **Steps**: Init → Format check → Validate → Plan → Apply
- **PR**: Shows plan in PR comments (no apply)

## License

MIT
