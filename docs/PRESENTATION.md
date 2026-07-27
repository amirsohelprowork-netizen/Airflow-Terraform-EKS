# 🚀 Quickstart Guide: Enterprise Airflow on EKS

Welcome to the definitive guide for deploying a production-ready Apache Airflow cluster on Amazon EKS! This guide is designed to take you from zero to a fully functioning, immutable, and auto-scaling Airflow deployment in minutes.

---

## 📋 Prerequisites

Before you begin, ensure your local machine has the following installed:
1. [**Git**](https://git-scm.com/downloads)
2. [**AWS CLI**](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (You must run `aws configure` and log in with your AWS Administrator credentials).
3. **PowerShell** (Pre-installed on Windows. Mac/Linux users can install [PowerShell Core](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)).

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
3. **Create your Terraform variables file.** Copy the example file and fill in your own values:

```powershell
Copy-Item terraform/terraform.tfvars.example terraform/terraform.tfvars
```

4. Open `terraform/terraform.tfvars` in a text editor and replace the placeholder values:
   - `kubernetes_version`: Leave as `"1.30"` (or use the latest EKS-supported version).
   - `admin_cidr_blocks`: Replace with your public IP address. You can find it by Googling "what is my IP" and adding `/32` at the end (e.g. `["203.0.113.42/32"]`).
   - `github_repository`: Replace with your forked repository name in `owner/repo` format (e.g. `"your-username/Airflow-Terraform-EKS"`).

5. Run the bootstrap script to create an S3 bucket and DynamoDB locking table:

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
5. Commit and push **both** the generated `backend.tf` file **and** your `terraform.tfvars` file to your `main` branch.

> [!CAUTION]
> Wait — isn't committing `terraform.tfvars` a security risk? No! The `.gitignore` in this repository deliberately excludes `*.tfvars` from being tracked by Git, so it will **never** be pushed to GitHub. You need to push some other change in the `terraform/` folder (like the `backend.tf` file) to trigger the pipeline. Then, for the GitHub Actions runner to have access to the variables, they are passed via Terraform's default variable values and the `terraform.tfvars.example` defaults.

**GitHub Actions will now automatically launch the Phase 1 Infrastructure pipeline!** Grab a coffee ☕, this takes about 15-20 minutes.

---

## ✈️ Step 4: Phase 2 - Airflow & DAGs Pipeline

Once Phase 1 successfully completes, your AWS infrastructure is ready. Now we deploy Airflow!

1. Open the successful **Phase 1 GitHub Actions Run** and view the output of the "Terraform Apply" step. You will see several output values.
2. Go back to **Settings** → **Secrets and variables** → **Actions**.
3. Create the following **Repository Variables** using the Terraform outputs:
   - `AWS_DEPLOY_ROLE_ARN`: (The `github_deploy_role_arn` output from Terraform)
   - `AIRFLOW_IRSA_ROLE_ARN`: (The `airflow_irsa_role_arn` output from Terraform)
   - `EKS_CLUSTER_NAME`: (The `cluster_name` output, usually `airflow-enterprise-demo`)
   - `ECR_REPOSITORY`: (The `airflow_ecr_repository_url` output — use only the part after the `/`, e.g. `airflow-enterprise-demo/airflow`)
   - `AIRFLOW_LOG_BUCKET`: (The `airflow_bucket_name` output)
4. Create or edit a DAG file in the `dags/` folder.
5. Push your changes to the `main` branch.

**GitHub Actions will now trigger Phase 2!** It will package your DAGs into an immutable Docker image, push it to ECR, and deploy it to your EKS cluster using Helm.

---

## 🎉 Step 5: Success & Access!

Congratulations! You now have a production-grade Airflow deployment.

1. **Get the URL**: Open the successful **Phase 2 GitHub Actions Run**, click on the very last step called `🚀 Get Airflow URL`. It will print your live `http://...` link!
2. **Login**: Open the URL in your browser. The default credentials are `admin` / `admin`.

- Every time you push changes to `dags/`, GitHub Actions will safely upgrade your EKS cluster without downtime.
- Your tasks are isolated using the `KubernetesExecutor`.
- All task logs are securely streamed to Amazon S3 using IAM Roles for Service Accounts (IRSA).

---

## 🧨 Step 6: Teardown (IMPORTANT!)

When you are finished, you **must** destroy the infrastructure to avoid ongoing AWS charges.

1. **Delete Kubernetes resources first** (this removes the AWS Load Balancer that Terraform doesn't manage):
```bash
aws eks update-kubeconfig --name airflow-enterprise-demo --region us-east-1
helm uninstall airflow -n airflow
helm uninstall ingress-nginx -n ingress-nginx
```

2. **Destroy the Terraform infrastructure:**
```bash
cd terraform
terraform destroy -auto-approve
```

3. **Delete the remote state backend** (the S3 bucket and DynamoDB table created by the bootstrap script):
```powershell
# Replace BUCKET_NAME with the bucket name printed by the bootstrap script
aws s3 rm s3://BUCKET_NAME --recursive
aws s3api delete-bucket --bucket BUCKET_NAME --region us-east-1
aws dynamodb delete-table --table-name airflow-enterprise-demo-tflock --region us-east-1
```

> [!IMPORTANT]
> If `terraform destroy` fails with a `BucketNotEmpty` error, you need to empty the S3 log bucket first: `aws s3 rm s3://BUCKET_NAME --recursive`, then re-run `terraform destroy`.
