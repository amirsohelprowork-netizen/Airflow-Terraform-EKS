# Airflow EKS demo runbook

## Scope

Cost-capped, short-lived EKS demonstration. Enterprise patterns (immutable
images, RDS, remote logs, OIDC, IRSA, KubernetesExecutor) on Free Tier–eligible
node types that can actually schedule Airflow — not `t3.micro` for the control plane.

## Required GitHub configuration

Run `scripts/bootstrap-remote-state.ps1` once, then add:

**Variables:** `AWS_REGION`, `AWS_ACCOUNT_ID`, `TF_STATE_BUCKET`, `TF_LOCK_TABLE`,
`TF_STATE_KEY`, `TF_VAR_KUBERNETES_VERSION`, `TF_VAR_ADMIN_CIDR_BLOCKS`,
`BUDGET_ALERT_EMAIL` (recommended), optional `BUDGET_LIMIT_USD`, optional
`GITHUB_DEPLOY_ROLE_ARN`.

**Secrets:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (infra/destroy only),
`AIRFLOW_ADMIN_PASSWORD`, `AIRFLOW_API_SECRET_KEY`.

## Demo validation

1. Deploy infrastructure; confirm state in S3 and budget alert email (if configured).
2. Deploy Airflow; port-forward to the UI.
3. Trigger `controlled_kubernetes_scale_test` with ~20 tasks.
4. Confirm worker ASG scales from 0 toward the capped max (default 2).

## Cleanup

GitHub Actions → **Destroy Demo Stack** → confirm with `destroy`.

Or:

```powershell
.\scripts\teardown.ps1 -AwsRegion us-east-1
```
