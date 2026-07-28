# Troubleshooting

Common failures when forking and deploying this demo. Fix these before opening an issue.

## Cost / Free Tier

**Symptom:** Unexpected AWS charges.

**Cause:** EKS control plane and NAT Gateway are **not** Free Tier.

**Fix:** Run **Destroy Demo Stack** (type `destroy`) the same day. Set `BUDGET_ALERT_EMAIL` during bootstrap.

---

## Deploy Infrastructure fails: `Invalid number literal` on `admin_cidr_blocks`

**Cause:** GitHub variable was set to `0.0.0.0/0` without JSON list syntax.

**Fix:** Current CI auto-wraps bare CIDRs. Prefer:

```text
TF_VAR_ADMIN_CIDR_BLOCKS=["0.0.0.0/0"]
```

Re-run bootstrap or edit the variable, then re-run **Deploy Infrastructure**.

---

## Deploy Airflow fails: `Not authorized to perform sts:AssumeRoleWithWebIdentity`

**Cause:** GitHub OIDC subject claims may use the immutable format after repo create/rename:

`repo:ORG@OWNER_ID/REPO@REPO_ID:environment:demo`

**Fix:** This repo’s Terraform trust policy matches both classic and immutable subjects. Re-run **Deploy Infrastructure** so the IAM role trust is up to date, then re-run **Deploy Airflow to EKS**.

Also confirm:

- GitHub Environment named exactly `demo` exists
- Workflow runs on branch `main` (or via that environment)

---

## Deploy Airflow fails: Helm `context deadline exceeded`

**Cause:** Control-plane pods stuck in `Init:CrashLoopBackOff`, often on `wait-for-airflow-migrations`.

**Check:**

```bash
kubectl get pods -n airflow
kubectl logs -n airflow -l component=scheduler -c wait-for-airflow-migrations --tail=50
```

### `ValueError: Invalid IPv6 URL`

RDS password special characters were not URL-encoded in the metadata secret. Current Terraform uses `urlencode(...)`. Re-run **Deploy Infrastructure**, or patch the secret and run migrations (see maintainer notes in git history).

### Waiting for migrations forever

Migration Job never completed. Re-run **Deploy Airflow to EKS**, or run:

```bash
# Use your ECR image tag from the failed workflow
kubectl create job airflow-db-migrate-manual --from=job/DOES-NOT-EXIST  # prefer re-running the workflow
```

Prefer a clean workflow re-run after infra is healthy.

---

## Missing GitHub Environment `demo`

**Symptom:** Workflow waits on environment protection or fails oddly.

**Fix:** Repo → **Settings** → **Environments** → create `demo`. Bootstrap scripts try to create it via `gh` when possible.

---

## Cannot open the UI

There is **no public load balancer** in the demo (cost + security).

```powershell
.\scripts\open-airflow.ps1
```

```bash
./scripts/open-airflow.sh
```

Then open http://127.0.0.1:8080 — user `admin`, password = generated value printed by bootstrap (also in GitHub secret `AIRFLOW_ADMIN_PASSWORD`).

---

## Wrong Terraform state bucket

**Symptom:** Plan/apply looks empty or points at a deleted bucket.

**Fix:** Re-run `./scripts/bootstrap.sh` / `bootstrap.ps1` only if you destroyed the old state backend. Update GitHub vars `TF_STATE_BUCKET` / `TF_LOCK_TABLE` to match. Do not create two backends for the same live stack.

---

## Instance type / Free Tier eligibility

`t3.micro` cannot host the Airflow control plane (1 GiB). Defaults use larger Free Tier–eligible types on newer Free plan accounts. On older accounts, you may be billed for `m7i-flex.large` / `t3.small` — check:

```bash
aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true --query 'InstanceTypes[].InstanceType' --output text
```

---

## Still stuck?

1. Confirm **Deploy Infrastructure** is green.
2. Confirm pods: `kubectl get pods -n airflow`
3. Confirm budget alerts are configured.
4. Destroy and retry once on a clean account if state is corrupted.
