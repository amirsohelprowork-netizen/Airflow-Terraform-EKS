# Project Context & Progress Log

## Project Summary
- **Goal:** Production-shaped Enterprise Apache Airflow deployment on Amazon EKS using Terraform, Helm, and GitHub Actions OIDC.
- **GitHub Repository:** [Airflow_CICD](https://github.com/amirsohelprowork-netizen/Airflow_CICD.git)
- **Deployment Architecture:**
  - **IaC:** Terraform (`terraform-aws-modules` for EKS & VPC, AWS RDS PostgreSQL, S3 Logs, ECR, OIDC)
  - **Host / Orchestrator:** Amazon EKS (Kubernetes)
  - **Executor:** `KubernetesExecutor` (Isolated per-task Pod execution)
  - **Container Packaging:** Immutable SHA-tagged Docker images built via Dockerfile and pushed to ECR.
  - **Deployment Mechanism:** Helm chart deployments via GitHub Actions OIDC (keyless authentication).

---

## Current Status: ✅ CODE COMPLETE & VALIDATED

- **Terraform Validation:** Passed (`terraform validate` -> `Success! The configuration is valid.`)
- **Git Status:** Fully committed and synchronized with GitHub `main` branch.
- **Active AWS Infrastructure:** **0 resources active** (No ongoing AWS charges).

---

## Complete Project Components

1. **Terraform IaC (`terraform/`):**
   - `main.tf`: Defines EKS cluster, node groups (control plane system nodes + dynamic worker nodes), RDS PostgreSQL database, S3 log bucket, ECR repository, and VPC networking.
   - `github_oidc.tf`: Configures AWS IAM OpenID Connect (OIDC) identity provider and least-privilege IAM roles for GitHub Actions.
   - `variables.tf` & `outputs.tf`: Configurable parameters and outputs for cluster name, ECR repository URL, IAM role ARNs.

2. **Kubernetes & Helm (`helm/airflow/`):**
   - `values.yaml`: Production-shaped Helm configuration for Airflow with `KubernetesExecutor`, remote S3 logging, and resource limits.
   - `pod_template.yaml`: Pod template specification used by `KubernetesExecutor` to spawn task pods on demand.

3. **Containerization (`docker/`):**
   - `Dockerfile`: Bakes DAGs and dependencies into an immutable container image for zero-downtime, deterministic releases.

4. **CI/CD Pipeline (`.github/workflows/`):**
   - `deploy-airflow-eks.yml`: Automates Python DAG syntax checks, Docker image build & push to ECR, and Helm upgrade on EKS via OIDC.

5. **DAGs & Load Testing (`dags/`):**
   - `example_dag.py`: Base Hello World test DAG.
   - `controlled_scale_test.py`: Dynamic task-expansion benchmark DAG for testing Kubernetes scaling (100–500 tasks).

6. **Automation & Operations (`scripts/` & `docs/`):**
   - `bootstrap-airflow-secrets.ps1`: Automated PowerShell script to populate Kubernetes secrets (DB credentials, Fernet key) post-Terraform apply.
   - `destroy-enterprise-demo.ps1`: Safe tear-down script to destroy all EKS/RDS infrastructure after a demo.
   - `enterprise-demo-runbook.md`: Detailed demonstration runbook.

---

## How to Spin Up / Test the Stack

1. **Provision Infrastructure:**
   ```powershell
   cd terraform
   copy terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars to specify region and admin IP
   terraform init
   terraform apply
   ```

2. **Bootstrap Secrets:**
   ```powershell
   .\scripts\bootstrap-airflow-secrets.ps1
   ```

3. **Configure GitHub Secrets & Variables:**
   Set `AWS_REGION`, `EKS_CLUSTER_NAME`, `ECR_REPOSITORY`, `AIRFLOW_LOG_BUCKET`, and `AWS_DEPLOY_ROLE_ARN` in **GitHub Settings → Secrets and Variables → Actions**.

4. **Deploy & Benchmark:**
   Push a commit to `main` to trigger the pipeline, then run `controlled_kubernetes_scale_test` in the Airflow UI.

5. **Teardown (Immediate Cleanup):**
   ```powershell
   .\scripts\destroy-enterprise-demo.ps1 -Confirm DESTROY-EKS-DEMO
   ```
