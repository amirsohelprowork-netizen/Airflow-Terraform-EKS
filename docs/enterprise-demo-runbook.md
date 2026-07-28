# Airflow EKS demo runbook

## Scope

Cost-capped, short-lived EKS demonstration for forks. Prefer the README happy path:

1. `./scripts/bootstrap.sh --email you@example.com` (or `bootstrap.ps1`)
2. **Deploy Infrastructure**
3. **Deploy Airflow to EKS**
4. `./scripts/open-airflow.sh`
5. **Destroy Demo Stack**

## Validation

1. Confirm Terraform state exists in the bootstrap S3 bucket.
2. Port-forward and log in as `admin`.
3. Trigger `controlled_kubernetes_scale_test` with ~10–20 tasks.
4. Confirm worker ASG scales toward max 2.

## Cleanup

GitHub Actions → **Destroy Demo Stack** → confirm with `destroy`.

Or: `.\scripts\teardown.ps1`

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) if a workflow fails.
