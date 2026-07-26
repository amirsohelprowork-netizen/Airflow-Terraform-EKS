# Enterprise Airflow reference demo on Amazon EKS

This repository is an **unapplied, production-shaped demonstration** of Apache
Airflow on Amazon EKS. It is designed for a customer that expects thousands of
daily workflow runs and wants to see the right operational building blocks:
Kubernetes task isolation, resilient schedulers, managed PostgreSQL, immutable
releases, least-privilege deployment identity, central logs, and explicit
teardown.

## Architecture

```text
GitHub Actions (OIDC) → ECR immutable Airflow image → EKS + Helm
                                                  ├─ scheduler replicas
                                                  ├─ webserver replicas
                                                  └─ KubernetesExecutor task Pods
                                                            ↓
                                             RDS PostgreSQL + S3 remote logs
```

The current EC2/LocalExecutor environment was destroyed before this redesign.
This code has **not** been applied; it cannot incur new AWS charges until you
run Terraform apply.

## Why KubernetesExecutor

Each task runs in an isolated Kubernetes Pod with defined CPU/memory limits.
EKS can add worker nodes for queued Pods, while the Airflow control plane stays
on a dedicated node group. This is stronger than a single EC2 + LocalExecutor
deployment, but customer capacity must still be proven by a load test.

## Demo deployment

1. Install Terraform, AWS CLI, kubectl, and Helm. Authenticate using a
   non-root IAM role/user.
2. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`.
   Set a supported EKS version, your public IP CIDR, and the GitHub repository.
3. Create an AWS Budget before provisioning.
4. Run `terraform init`, `terraform plan`, then `terraform apply` in
   `terraform/` after reviewing the plan.
5. Run `scripts/bootstrap-airflow-secrets.ps1` with the Terraform outputs.
6. Set the GitHub repository variables listed in
   [the runbook](docs/enterprise-demo-runbook.md).
7. Push to `main` to build a SHA-tagged image and deploy the Airflow Helm chart.
8. Trigger `controlled_kubernetes_scale_test` with `{ "task_count": 100 }`.

## Cost boundary

This is a short-lived demo. The Terraform defaults intentionally use one NAT
Gateway, single-AZ RDS, and constrained worker-node scaling. They are not the
production HA settings. Destroy the stack immediately after the demo:

```powershell
.\scripts\destroy-enterprise-demo.ps1 -Confirm DESTROY-EKS-DEMO
```

See [the full runbook](docs/enterprise-demo-runbook.md) before applying.
