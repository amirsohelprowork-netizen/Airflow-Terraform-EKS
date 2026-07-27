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

| Phase | Pipeline | Trigger | What it does |
|-------|----------|---------|-------------|
| **1 — Platform** | `deploy-infra.yml` | Changes to `terraform/` | Runs `terraform apply` to provision VPC, EKS, RDS, ECR, IAM OIDC |
| **2 — Application** | `deploy-airflow-eks.yml` | Changes to `dags/`, `docker/`, `helm/`, `requirements/` | Builds an immutable Docker image, pushes to ECR, deploys via Helm |

👉 For the complete step-by-step walkthrough (including prerequisites, GitHub Secrets setup, and teardown), see the [**Quickstart Presentation Guide**](docs/PRESENTATION.md).

## Teardown

> [!WARNING]
> **Amazon EKS costs ~$3-4/day.** Always destroy the infrastructure when you are finished!

See the detailed [teardown instructions in the Quickstart Guide](docs/PRESENTATION.md#-step-6-teardown-important) for the full 3-step process (Helm uninstall → Terraform destroy → Backend cleanup).
