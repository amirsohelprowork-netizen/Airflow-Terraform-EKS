# Enterprise Airflow EKS — Runbook

## What this project proves

This is a production-grade reference implementation: EKS runs the Airflow
control plane and KubernetesExecutor runs each task in a separate Pod. It
demonstrates isolation, independently bounded task resources, immutable DAG
releases, IAM federation, and horizontal Kubernetes capacity.

It is **not** evidence that an untested deployment has already sustained
25,000 task instances per day. Capacity certification requires testing with your
actual DAG parsing time, task duration, concurrency peaks, database behaviour,
and downstream-service limits.

## Quick demo walkthrough

1. Show `terraform plan` for the VPC, EKS, RDS, ECR, S3, and IAM/OIDC layers.
2. Show GitHub Actions using OIDC to build a SHA-tagged image and deploy via Helm.
3. Open the Airflow UI and inspect the KubernetesExecutor configuration.
4. Trigger `controlled_kubernetes_scale_test` with `{ "task_count": 20 }`.
5. Watch task Pods appear with `kubectl -n airflow get pods -w`.
6. Show EKS node autoscaling behaviour and remote S3 logs.
7. Run the teardown steps after the demonstration.

## Required GitHub repository variables

Set these in **Settings → Secrets and variables → Actions → Variables**:

| Variable | Source |
|---|---|
| `AWS_REGION` | Your AWS region, normally `us-east-1` |
| `EKS_CLUSTER_NAME` | `terraform output -raw cluster_name` |
| `ECR_REPOSITORY` | ECR repository path from `terraform output -raw airflow_ecr_repository_url` (use only the part after the `/`) |
| `AIRFLOW_LOG_BUCKET` | `terraform output -raw airflow_bucket_name` |
| `AWS_DEPLOY_ROLE_ARN` | `terraform output -raw github_deploy_role_arn` |
| `AIRFLOW_IRSA_ROLE_ARN` | `terraform output -raw airflow_irsa_role_arn` |

## Required GitHub repository secrets (Phase 1 only)

| Secret | Source |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | Your IAM user secret key |

## Before applying

- Use an IAM administrator role/user, never the AWS root access key.
- Limit `admin_cidr_blocks` in your `terraform.tfvars` to your current public IP (`x.x.x.x/32`).
- Select an EKS Kubernetes version currently supported in the target Region.
- Replace the demo's single NAT Gateway and single-AZ RDS setting with HA
  settings before production deployment.
- Set AWS Budget and Cost Anomaly Detection alerts first.

## Cleanup

After you are finished, remove the complete stack by following the
[teardown steps in the Quickstart Guide](PRESENTATION.md#-step-6-teardown-important).

The 3-step sequence is:
1. `helm uninstall` to remove Kubernetes Load Balancers.
2. `terraform destroy` to remove EKS, RDS, VPC, and all other AWS resources.
3. Delete the remote state S3 bucket and DynamoDB table.

> [!WARNING]
> Do not leave EKS, RDS, NAT Gateway, load balancers, or worker nodes running.
> This project costs ~$3-4/day.
