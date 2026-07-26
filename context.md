# Project Context & Progress Log

## Project Summary
- **Goal:** IaC and CI/CD pipeline for deploying an Apache Airflow environment on AWS for testing/demo purposes.
- **GitHub Repository:** [Airflow_CICD](https://github.com/amirsohelprowork-netizen/Airflow_CICD.git)
- **Deployment Architecture:**
  - **IaC:** Terraform (AWS Provider)
  - **Host:** AWS EC2 (`t3.small` - Free Tier eligible: 2 vCPU, 2GB RAM + 4GB Swap configured)
  - **Container Runtime:** Docker Compose (`apache/airflow:2.9.2` with LocalExecutor + `postgres:15-alpine` metadata DB)
  - **CI/CD:** GitHub Actions (Automated DAG syntax validation + SSH deployment to EC2)

---

## Current Status: ✅ LIVE & WORKING

The Airflow cluster is **fully deployed and operational**.

- **Airflow Web UI URL:** [http://44.217.173.170:8080](http://44.217.173.170:8080)
- **Public IP:** `44.217.173.170`
- **Airflow UI Credentials:**
  - **Username:** `admin`
  - **Password:** `AirflowAdmin123!`
- **SSH Access:**
  ```powershell
  ssh -i terraform/airflow-key.pem ec2-user@44.217.173.170
  ```

---

## Chronological Journey & What Happened So Far

1. **Initial Requirement:**
   - User requested IaC + CI/CD for deploying Airflow on AWS within a $100 budget.

2. **Phase 1 (AWS MWAA Attempt):**
   - Designed and created full Terraform IaC for Managed Workflows for Apache Airflow (MWAA) in `us-east-1` (VPC, private subnets, NAT Gateway, S3 bucket, IAM roles).
   - Ran `terraform apply`.
   - **Error Encountered:** `SubscriptionRequiredException: The AWS Access Key Id needs a subscription for the service`.
   - Root cause: AWS account type/free tier restricts MWAA access without prior subscription activation in the console.

3. **Phase 2 (Pivot to EC2 + Docker Compose):**
   - Destroyed all MWAA resources (`terraform destroy`).
   - Refactored Terraform code to provision an EC2 instance in a single public subnet (saving costs, avoiding NAT Gateway fees).
   - Created `user_data.sh` script to automate Docker, Docker Compose, 4GB swap file setup, and Airflow startup.
   - **Error Encountered:** `t3.medium` and `t2.micro` instances were rejected by AWS API as not free-tier eligible for this specific account.
   - Queried eligible instances: `aws ec2 describe-instance-types --filters "Name=free-tier-eligible,Values=true"`
   - Found `t3.small` (2 vCPU, 2GB RAM) is free-tier eligible on this account.

4. **Phase 3 (Successful Deployment):**
   - Deployed EC2 instance (`t3.small`) using `terraform apply`.
   - Configured 4GB swap space and memory limits in `docker-compose.yml` to ensure Airflow runs smoothly on 2GB RAM.
   - Fixed Windows SSH key permissions for `terraform/airflow-key.pem`.
   - Verified containers via SSH: `airflow-webserver` (healthy), `airflow-scheduler` (healthy), `postgres` (healthy). Returned HTTP 200 on `http://44.217.173.170:8080`.
   - Pushed complete codebase to GitHub repository: `main` branch.

---

## File & Repository Structure

```
Airflow_full_deploy/
├── .github/workflows/
│   ├── deploy-dags.yml      # CI/CD pipeline: validates Python DAG syntax & copies to EC2 via SSH
│   └── terraform.yml        # CI/CD pipeline for Terraform plan/apply
├── dags/
│   └── example_dag.py       # Sample Hello World DAG
├── requirements/
│   └── requirements.txt     # Python requirements for Airflow
├── scripts/
│   └── validate_dags.py     # Script used by GitHub Actions to validate DAG syntax
├── terraform/
│   ├── main.tf              # Provider configuration (AWS, TLS, Local)
│   ├── variables.tf         # Input variables (defaults to t3.small, us-east-1)
│   ├── outputs.tf           # Output IPs, SSH commands, URLs
│   ├── vpc.tf               # Public subnet, IGW, Route tables
│   ├── security_groups.tf   # Ports 22 (SSH) and 8080 (Airflow UI) open
│   ├── ec2.tf               # EC2 instance definition + SSH Key creation
│   ├── user_data.sh         # EC2 bootstrap script (Swap + Docker + Airflow)
│   ├── airflow-key.pem      # SSH Private Key (ignored in git)
│   └── terraform.tfvars     # Local variables overriding defaults
├── .gitignore
├── README.md
└── context.md               # This context document
```

---

## Next Steps / GitHub CI/CD Configuration

To enable automatic DAG deployment whenever a commit is pushed to `main`:

1. Go to GitHub Repository -> **Settings** -> **Secrets and variables** -> **Actions**.
2. Add the following repository secrets:
   - `AIRFLOW_HOST`: `44.217.173.170`
   - `SSH_PRIVATE_KEY`: Paste the full contents of `c:\Users\amirs\Airflow_full_deploy\terraform\airflow-key.pem`
3. Push changes to `dags/` on `main` branch — GitHub Actions will validate and deploy to `/opt/airflow/dags/` on EC2.

---

## Cleanup Command (When Done Testing)

To avoid ongoing AWS charges, run from `terraform/` directory:
```powershell
cd terraform
terraform destroy -auto-approve
```
