# Cost-capped Apache Airflow on Amazon EKS

This is a public reference deployment for Apache Airflow with `KubernetesExecutor`, EKS managed node groups, RDS PostgreSQL, ECR, S3 remote logs, GitHub Actions OIDC, IRSA, and Cluster Autoscaler.

It has two intentional operating profiles:

| Profile | Purpose | Cost / resilience |
| --- | --- | --- |
| Demo (default) | A short, 1–2 day learning or architecture test using AWS credits | Three `t3.micro` system nodes, zero task nodes until demand; not HA |
| Production example | A starting point for a real platform review | Multi-node, Multi-AZ settings; materially more expensive |

## Important cost and capacity statement

AWS EKS and NAT Gateway are **not Free Tier services**. This template is suitable for a time-boxed test on promotional AWS credits, not a zero-cost deployment. Set an AWS Budget before deployment and destroy the stack immediately after testing.

The demo proves deployment mechanics and task-pod autoscaling. It does **not** prove a workload of thousands of DAGs or tasks. Production capacity must be measured using representative DAG parsing, task duration, database load, and downstream dependencies.

## What is automated

After the one-time state bootstrap and GitHub configuration, a push to `main` will:

1. Provision/update AWS infrastructure with Terraform.
2. Build a commit-SHA-tagged image containing DAGs and dependencies.
3. Read deployment settings directly from Terraform remote state.
4. Deploy Cluster Autoscaler and Airflow with Helm.

No Terraform outputs need to be copied into GitHub variables for the default demo profile.

## First deployment

1. Fork this repository. Never run it from a GitHub organization whose other repositories should be able to deploy into this AWS account.
2. Run the one-time backend bootstrap locally:

   ```powershell
   .\scripts\bootstrap-remote-state.ps1 -AwsRegion us-east-1
   ```

3. Add these GitHub repository variables using the values the script prints:

   - `AWS_REGION`
   - `AWS_ACCOUNT_ID`
   - `TF_STATE_BUCKET`
   - `TF_LOCK_TABLE`
   - `TF_STATE_KEY`
   - `TF_VAR_KUBERNETES_VERSION` — an EKS version currently supported in your chosen region.
   - `TF_VAR_ADMIN_CIDR_BLOCKS` — use `["0.0.0.0/0"]` with GitHub-hosted runners. The API remains IAM-authenticated, but this is not a production network boundary. A private production endpoint requires a runner inside the VPC.

4. Add these repository secrets:

   - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` — one-time bootstrap credentials for the infrastructure workflow. Use a dedicated administrator identity, not root; later application deployments use OIDC.
   - `AIRFLOW_ADMIN_PASSWORD`
   - `AIRFLOW_API_SECRET_KEY` — generate a long random value.

5. Run **Deploy Infrastructure** from GitHub Actions. It creates the scoped GitHub OIDC deployment role.
6. Push a change under `dags/`, `docker/`, `requirements/`, or `helm/`, or run **Deploy Airflow to EKS** manually.
7. The demo does not create a public load balancer. Access the UI safely:

   ```bash
   kubectl -n airflow port-forward svc/airflow-api-server 8080:8080
   ```

## Scaling model

Airflow control-plane pods stay on the `system` node group. KubernetesExecutor task pods tolerate the dedicated task-node taint; Cluster Autoscaler raises the task group from zero to `max_worker_nodes` when pods cannot schedule. The demo uses Free Tier-eligible `t3.micro` nodes and caps task capacity at three nodes. Raise limits only after load testing.

## Production starting point

Copy [production.tfvars.example](terraform/production.tfvars.example) to a private, ignored `terraform.tfvars`, then review network egress, TLS/DNS, identity, backups, monitoring, alerting, resource quotas, NetworkPolicies, and disaster recovery before use. It is a starting point—not an approved production design.

## Teardown

Destroy application load-bearing resources first, then infrastructure:

```bash
helm uninstall airflow -n airflow
helm uninstall cluster-autoscaler -n kube-system
cd terraform
terraform destroy
```

Then delete the state bucket and DynamoDB lock table only after Terraform has completed and you no longer need its state history.
