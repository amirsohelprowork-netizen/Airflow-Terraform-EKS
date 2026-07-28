# Cost-capped Apache Airflow on Amazon EKS (Free Tier / credits profile)

This is a public reference deployment for Apache Airflow 3 with `KubernetesExecutor`, EKS managed node groups, RDS PostgreSQL, ECR, S3 remote logs, GitHub Actions OIDC, IRSA, Cluster Autoscaler, and an automated destroy path.

It has two intentional operating profiles:

| Profile | Purpose | Cost / resilience |
| --- | --- | --- |
| Demo (default) | Short learning / architecture test on AWS Free Tier eligibility + credits | 2× `m7i-flex.large` system nodes, `t3.small` workers from **0**, `db.t3.micro`; not HA |
| Production example | Starting point for a real platform review | See `terraform/production.tfvars.example` — materially more expensive |

## Important cost statement

**EKS and NAT Gateway are not Free Tier services.** They consume your credits (~a few dollars per day while running). `t3.micro` is Free Tier–eligible but **cannot** host the Airflow control plane (1 GiB RAM). This demo uses Free Tier–eligible **larger** instance types that actually schedule Airflow pods.

Before first deploy:

1. Set an AWS Budget (or set GitHub var `BUDGET_ALERT_EMAIL` so Terraform creates one).
2. Plan to run **Destroy Demo Stack** the same day you finish testing.

## Demo capacity (defaults)

| Layer | Choice | Why |
| --- | --- | --- |
| System nodes | `m7i-flex.large` × 2 | Free Tier–eligible on newer Free plan accounts; 8 GiB fits scheduler/api/triggerer/dag-processor |
| Worker nodes | `t3.small`, min 0, max 2 | Scale only when KubernetesExecutor pods are Pending |
| Metadata DB | `db.t3.micro` | Smallest practical RDS size for the demo |
| Network | 1 NAT Gateway | Cost control (not Multi-AZ) |

## What is automated

After one-time bootstrap and GitHub configuration, automation covers:

1. **Deploy Infrastructure** — Terraform (VPC, EKS, RDS, S3, ECR, IRSA, OIDC, optional budget).
2. **Deploy Airflow to EKS** — DAG validation → immutable SHA image → Cluster Autoscaler + Airflow Helm → readiness wait.
3. **Destroy Demo Stack** — Helm uninstall → `terraform destroy` (type `destroy` to confirm).

No Terraform outputs need to be copied for the default demo, except optionally `GITHUB_DEPLOY_ROLE_ARN` after the first infra run (a naming-convention fallback exists).

## First deployment

1. Fork this repository. Do not run it from a GitHub org whose other repos should deploy into this AWS account (OIDC is scoped to **this** repo + `main` / `demo` environment).
2. Run the one-time backend bootstrap:

   ```powershell
   .\scripts\bootstrap-remote-state.ps1 -AwsRegion us-east-1
   ```

3. Add GitHub **repository variables**:

   - `AWS_REGION`, `AWS_ACCOUNT_ID`
   - `TF_STATE_BUCKET`, `TF_LOCK_TABLE`, `TF_STATE_KEY`
   - `TF_VAR_KUBERNETES_VERSION` — an EKS version supported in your region
   - `TF_VAR_ADMIN_CIDR_BLOCKS` — `["0.0.0.0/0"]` for GitHub-hosted runners (IAM still required; not a production network boundary)
   - `BUDGET_ALERT_EMAIL` — strongly recommended (creates a $40 monthly budget by default)
   - `BUDGET_LIMIT_USD` — optional, default `40`
   - `GITHUB_DEPLOY_ROLE_ARN` — optional; set from infra workflow output after first apply

4. Add GitHub **secrets**:

   - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` — bootstrap credentials for infra/destroy only (not root)
   - `AIRFLOW_ADMIN_PASSWORD`
   - `AIRFLOW_API_SECRET_KEY` — long random value

5. Run **Deploy Infrastructure**, then **Deploy Airflow to EKS**.
6. Access the UI (no public load balancer in demo):

   ```bash
   kubectl -n airflow port-forward svc/airflow-api-server 8080:8080
   ```

## Scaling model

Control-plane pods stay on the `system` node group. KubernetesExecutor task pods tolerate the `airflow-task` taint; Cluster Autoscaler grows the worker ASG from **0** to `max_worker_nodes` when pods cannot schedule.

Validate with DAG `controlled_kubernetes_scale_test` (e.g. 20 tasks) and watch the worker ASG.

## Teardown (do this — credits will burn otherwise)

**Preferred:** GitHub Actions → **Destroy Demo Stack** → type `destroy`.

**Local:**

```powershell
.\scripts\teardown.ps1 -AwsRegion us-east-1
```

Or manually:

```bash
helm uninstall airflow -n airflow
helm uninstall cluster-autoscaler -n kube-system
cd terraform
terraform destroy
```

## Production starting point

Copy [production.tfvars.example](terraform/production.tfvars.example) to a private `terraform.tfvars`, then review private API endpoint, TLS/DNS, identity, backups, monitoring, NetworkPolicies, and DR. It is a starting point—not an approved production design.
