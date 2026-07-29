# Demo walkthrough

Supported setup: repository [README](../README.md). Troubleshooting: [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

Short-lived EKS demonstration on Free Tier–eligible compute **plus** credits
(EKS and NAT Gateway are **not** free). Always set a budget email and destroy
the same day.

## What you are demonstrating

| Pattern | How this repo shows it |
| --- | --- |
| Infrastructure as Code | Terraform: VPC, EKS, RDS, S3, ECR, IRSA, OIDC, optional AWS Budget |
| Immutable app deploys | DAGs + deps baked into an image tagged with the git SHA |
| Least-privilege cloud auth | GitHub OIDC for app CI; IRSA for Airflow → S3 logs |
| Elastic task compute | `KubernetesExecutor` + Cluster Autoscaler (workers from **0**) |
| Safe teardown | **Destroy Demo Stack** workflow |

**Demo capacity (honest):** ~**10** concurrent tasks (2× `t3.small` workers). Not a 5k-DAG / 30k-task/day platform.

## Demonstration sequence

1. Bootstrap (preferred):
   - Windows: `.\scripts\bootstrap.ps1 -BudgetAlertEmail you@example.com`
   - Mac/Linux: `./scripts/bootstrap.sh --email you@example.com`
2. **Deploy Infrastructure** — wait until green (~15–25 min).
3. **Deploy Airflow to EKS** — DAG validation, SHA image, Helm, pod readiness.
4. Open UI: `.\scripts\open-airflow.ps1` or `./scripts/open-airflow.sh`  
   (no public load balancer in the demo).
5. Trigger `controlled_kubernetes_scale_test` with ~10–20 tasks; show worker ASG scale from zero.
6. Optional: push a new `*.py` DAG under `dags/` → show Actions rebuild → DAG appears in UI.
7. **Destroy Demo Stack** (type `destroy`) or `.\scripts\teardown.ps1`.

## Talking points if asked

- Why not `t3.micro` for the control plane? **1 GiB RAM is too small** for Airflow 3 pods; defaults use `m7i-flex.large` system nodes.
- Why bake DAGs into the image? **Immutability and rollback** by SHA tag (files must end in `.py`).
- Why OIDC + long-lived keys? Keys only bootstrap infra (chicken-and-egg); app deploy uses OIDC, including GitHub’s immutable `sub` claim format.
