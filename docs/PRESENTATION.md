# Demo walkthrough

Supported setup: repository [README](../README.md).

Short-lived EKS demonstration on Free Tier–eligible compute **plus** credits
(EKS/NAT are not free). Set `BUDGET_ALERT_EMAIL` and destroy the same day.

## Demonstration sequence

1. Bootstrap remote state with `scripts/bootstrap-remote-state.ps1`.
2. **Deploy Infrastructure** — VPC, EKS, RDS, S3, ECR, IRSA, scoped OIDC, optional budget.
3. **Deploy Airflow to EKS** — strict DAG validation, SHA-tagged image, Helm, pod readiness.
4. Trigger `controlled_kubernetes_scale_test` with a low task count; worker ASG grows from **zero**.
5. UI via `kubectl port-forward` (no public LB in demo).
6. **Destroy Demo Stack** (type `destroy`) or `scripts/teardown.ps1`.

Do not present this as capacity certification for thousands of DAGs.
