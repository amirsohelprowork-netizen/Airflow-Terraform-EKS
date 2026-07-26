# 🚀 Quickstart Guide: Enterprise Airflow on EKS

Welcome to the definitive guide for deploying a production-ready Apache Airflow cluster on Amazon EKS! This guide is designed to take you from zero to a fully functioning, immutable, and auto-scaling Airflow deployment in minutes.

---

## 🛠️ Step 1: Fork & Setup

Before we start building, we need to prepare your GitHub and AWS environments.

1. **Fork this Repository**: Click the `Fork` button at the top right of this repository to create your own copy.
2. **AWS IAM User**: Ensure you have an AWS IAM User with `AdministratorAccess` (or the necessary least-privilege permissions to create VPCs, EKS clusters, and RDS databases).

> [!CAUTION]
> **Important**: This architecture uses Amazon EKS and RDS which are **NOT** covered by the AWS Free Tier. Running this demonstration will cost approximately $3 to $4 per day. Always remember to destroy the infrastructure when you are finished!

---

## 🏗️ Step 2: Bootstrapping Remote State

Terraform requires a place to store its "State" (the record of all the infrastructure it builds). We will store this securely in an AWS S3 bucket.

1. Clone your forked repository to your local machine.
2. Open PowerShell or a Terminal in the repository root.
3. Run the bootstrap script to automatically create an S3 bucket and DynamoDB locking table:

```powershell
.\scripts\bootstrap-remote-state.ps1
```

> [!NOTE]
> This script will automatically generate a `terraform/backend.tf` file configured to your new, personal S3 bucket.

---

## 🌩️ Step 3: Phase 1 - Infrastructure Pipeline

We will now instruct GitHub Actions to build the EKS cluster, the RDS database, and the secure OIDC IAM Roles.

1. Navigate to your GitHub repository in your browser.
2. Go to **Settings** → **Secrets and variables** → **Actions**.
3. Create the following **Repository Secrets**:
   - `AWS_ACCESS_KEY_ID`: (Your AWS Access Key)
   - `AWS_SECRET_ACCESS_KEY`: (Your AWS Secret Key)
4. Create the following **Repository Variable**:
   - `AWS_REGION`: (e.g., `us-east-1`)
5. Commit and push the generated `backend.tf` file (or any other change in the `terraform/` folder) to your `main` branch.

**GitHub Actions will now automatically launch the Phase 1 Infrastructure pipeline!** Grab a coffee ☕, this takes about 15-20 minutes.

---

## ✈️ Step 4: Phase 2 - Airflow & DAGs Pipeline

Once Phase 1 successfully completes, your AWS infrastructure is ready. Now we deploy Airflow!

1. Open the successful **Phase 1 GitHub Actions Run** and view the output of the "Terraform Apply" step. You will see several output values.
2. Go back to **Settings** → **Secrets and variables** → **Actions**.
3. Create the following **Repository Variables** using the Terraform outputs:
   - `AWS_DEPLOY_ROLE_ARN`: (The secure OIDC role created by Terraform)
   - `EKS_CLUSTER_NAME`: (Usually `airflow-enterprise-demo`)
   - `ECR_REPOSITORY`: (Your ECR repository path)
   - `AIRFLOW_LOG_BUCKET`: (The S3 bucket for Airflow logs)
4. Create or edit a DAG file in the `dags/` folder.
5. Push your changes to the `main` branch.

**GitHub Actions will now trigger Phase 2!** It will package your DAGs into an immutable Docker image, push it to ECR, and deploy it to your EKS cluster using Helm.

---

## 🎉 Step 5: Success!

Congratulations! You now have a production-grade Airflow deployment.

- Every time you push changes to `dags/`, GitHub Actions will safely upgrade your EKS cluster without downtime.
- Your tasks are isolated using the `KubernetesExecutor`.
- All task logs are securely streamed to Amazon S3 using IAM Roles for Service Accounts (IRSA).

> [!IMPORTANT]
> **Teardown**: When you are finished, open a terminal in the `terraform/` folder and run `terraform destroy -auto-approve` to completely wipe your AWS account and avoid recurring charges!
