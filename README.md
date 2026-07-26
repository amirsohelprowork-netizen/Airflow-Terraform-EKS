# 🚀 Enterprise Airflow on AWS EKS Blueprint

[![Terraform](https://img.shields.io/badge/Terraform-1.6+-623CE4.svg?logo=terraform)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.30-326ce5.svg?logo=kubernetes)](https://kubernetes.io/)
[![Apache Airflow](https://img.shields.io/badge/Apache%20Airflow-2.9.1-017CEE.svg?logo=apache-airflow)](https://airflow.apache.org/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF.svg?logo=github-actions)](https://github.com/features/actions)

This repository is a production-grade, open-source blueprint for deploying **Apache Airflow on Amazon EKS (Elastic Kubernetes Service)** using an **Infrastructure as Code (IaC)** and **CI/CD** approach. It is heavily optimized for enterprise scalability, security, and immutability. 

It is designed as an open-source template for deploying:
- Kubernetes task isolation
- Managed PostgreSQL (RDS)
- Immutable Docker releases
- Least-privilege AWS IAM identity
- Central logs (S3)

## 📚 Step-by-Step Quickstart Guide
**New here?** Check out the highly visual [**Quickstart Presentation Guide**](docs/PRESENTATION.md) for step-by-step instructions on how to fork, build, and deploy this pipeline from scratch!

## ⚠️ AWS Free Tier Warning
**Amazon EKS is NOT included in the AWS Free Tier.** The control plane alone costs ~$0.10/hour (~$73/month). The NAT Gateway and worker nodes will add additional costs. **This project will cost ~$3 to $4 per day to run.** Always destroy the resources when you are finished testing!

## Architecture

```text
GitHub Actions (OIDC) → ECR immutable Airflow image → EKS + Helm
                                                  ├─ scheduler replicas
                                                  ├─ webserver replicas
                                                  └─ KubernetesExecutor task Pods
                                                            ↓
                                             RDS PostgreSQL + S3 remote logs
```

## 🛠️ Technology Stack & Services Used

### ⚙️ Automation & Orchestration
1. **GitHub**: Source code hosting and version control.
2. **GitHub Actions**: Acts as our "robot assembly line" (CI/CD) to automatically build the infrastructure and deploy the Docker images without human intervention.
3. **Terraform**: Infrastructure as Code (IaC) to build AWS infrastructure predictably and enforce version control over our physical architecture.

### ☁️ Compute & Application
4. **Amazon EKS (Elastic Kubernetes Service)**: The core compute engine. EKS perfectly orchestrates Airflow, automatically spinning up new worker nodes when thousands of tasks are queued, and isolating each task into its own Pod (`KubernetesExecutor`).
5. **Amazon EC2**: The underlying virtual machines that act as the "worker nodes" in the EKS cluster.
6. **Docker**: Packages our DAGs and Python dependencies into a standardized, **immutable** container.
7. **Helm**: The package manager for Kubernetes. It installs the complex Airflow ecosystem into EKS with a single command.

### 💾 Storage & Databases
8. **Amazon RDS (PostgreSQL)**: Airflow's "memory." Tracks the state of every DAG, user logins, and connections. Amazon automatically handles backups, updates, and failures.
9. **Amazon ECR**: A secure, private registry to store the Airflow Docker images we build in Phase 2.
10. **Amazon S3**: Used for two critical things: 
    - Securely storing Terraform's remote "State File."
    - Storing Airflow's remote task logs, so they aren't lost when Kubernetes Pods are destroyed.
11. **Amazon DynamoDB**: A lightning-fast NoSQL database used purely for **Terraform State Locking** to prevent pipeline race conditions.

### 🔒 Networking & Security
12. **Amazon VPC**: The virtual "fence" around our infrastructure. EKS Nodes and the RDS Database are in **Private Subnets**, making them unreachable from the public internet.
13. **AWS ELB (Elastic Load Balancer)**: Automatically created by Kubernetes `ingress-nginx` to securely route browser traffic to the internal Airflow Webserver.
14. **AWS IAM**: Enforces "Least Privilege" security:
    - **OIDC (OpenID Connect)**: Allows GitHub Actions to deploy without static passwords.
    - **IRSA (IAM Roles for Service Accounts)**: Allows Kubernetes Pods to write to S3 without static passwords.
## Why KubernetesExecutor

Each task runs in an isolated Kubernetes Pod with defined CPU/memory limits.
EKS can add worker nodes for queued Pods, while the Airflow control plane stays
on a dedicated node group. This is stronger than a single EC2 + LocalExecutor
deployment, but customer capacity must still be proven by a load test.

## Two-Phase Deployment Architecture

This template is separated into two distinct GitHub Actions CI/CD pipelines to mimic enterprise best practices:

### Phase 1: Platform & Infrastructure (`deploy-infra.yml`)
1. Fork this repository to your own GitHub account.
2. Create an AWS IAM User with Administrator permissions (or appropriate least-privilege).
3. In your GitHub repository, go to **Settings → Secrets and variables → Actions**.
4. Add the following **Secrets**:
   - `AWS_ACCESS_KEY_ID`: Your IAM user access key.
   - `AWS_SECRET_ACCESS_KEY`: Your IAM user secret key.
5. Add the following **Variable**:
   - `AWS_REGION`: e.g., `us-east-1`
6. Run `scripts/bootstrap-remote-state.ps1` locally to create an S3 bucket for your Terraform state.
7. Push any changes to the `terraform/` folder to automatically trigger the build.

### Phase 2: Application & DAGs (`deploy-airflow-eks.yml`)
1. Once Phase 1 completes successfully, view the GitHub Actions logs for the "Terraform Apply" step to get your newly created AWS resources.
2. In your GitHub repository, go to **Settings → Secrets and variables → Actions** and add the following **Variables**:
   - `AWS_DEPLOY_ROLE_ARN`: The OIDC IAM Role ARN created by Terraform.
   - `EKS_CLUSTER_NAME`: The name of the EKS cluster.
   - `ECR_REPOSITORY`: The ECR repository path.
   - `AIRFLOW_LOG_BUCKET`: The S3 bucket name for Airflow remote logging.
3. Edit your DAGs in the `dags/` folder.
4. Push to the `main` branch to automatically build and deploy your Airflow application.

## Teardown

To avoid incurring massive AWS charges, destroy the environment immediately after you are finished evaluating it:
```bash
cd terraform
terraform destroy -auto-approve
```
