# Enterprise Airflow EKS demo runbook

## What this demo proves

This is a production-shaped reference implementation: EKS runs the Airflow
control plane and KubernetesExecutor runs each task in a separate Pod. It
demonstrates isolation, independently bounded task resources, immutable DAG
releases, IAM federation, and horizontal Kubernetes capacity.

It is **not** evidence that an untested deployment has already sustained
25,000 task instances per day. Capacity certification requires the customer's
actual DAG parsing time, task duration, concurrency peaks, database behaviour,
and downstream-service limits.

## One-hour demo sequence

1. Show `terraform plan` for the VPC, EKS, RDS, ECR, S3, and IAM/OIDC layers.
2. Show GitHub Actions using OIDC to build a SHA-tagged image and deploy Helm.
3. Open the Airflow UI and inspect the KubernetesExecutor configuration.
4. Trigger `controlled_kubernetes_scale_test` with `{ "task_count": 100 }`.
5. Watch task Pods appear with `kubectl -n airflow get pods -w`.
6. Show EKS nodes / autoscaling behaviour and remote S3 logs.
7. Explain that a controlled benchmark progresses from 100 to 500 tasks before
   testing the customer's peak pattern in a dedicated non-production account.
8. Run the explicit destroy command after the demonstration.

## Required GitHub repository variables

Set these in **Settings → Secrets and variables → Actions → Variables**:

| Variable | Source |
|---|---|
| `AWS_REGION` | Terraform input, normally `us-east-1` |
| `EKS_CLUSTER_NAME` | `terraform output -raw cluster_name` |
| `ECR_REPOSITORY` | ECR repository path from Terraform output |
| `AIRFLOW_LOG_BUCKET` | `terraform output -raw airflow_bucket_name` |
| `AWS_DEPLOY_ROLE_ARN` | `terraform output -raw github_deploy_role_arn` |

## Before applying

- Use an IAM administrator role/user, never the AWS root access key.
- Limit `admin_cidr_blocks` to your current public IP (`x.x.x.x/32`).
- Select an EKS Kubernetes version currently supported in the target Region.
- Replace the demo's single NAT Gateway and single-AZ RDS setting with HA
  settings before production deployment.
- Set AWS Budget and Cost Anomaly Detection alerts first.

## Cleanup

After the demo, remove the complete stack:

```powershell
.\scripts\destroy-enterprise-demo.ps1 -Confirm DESTROY-EKS-DEMO
```

Do not leave EKS, RDS, NAT Gateway, load balancers, or worker nodes running.
