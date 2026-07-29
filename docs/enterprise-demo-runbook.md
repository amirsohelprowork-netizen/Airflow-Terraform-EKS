# Airflow EKS demo runbook

## Scope

Cost-capped, short-lived Apache Airflow **3.2.2** on EKS for learning and
architecture demos. Enterprise patterns (immutable images, RDS, remote logs,
OIDC, IRSA, KubernetesExecutor) on Free Tier–eligible instance types that can
actually schedule Airflow — not `t3.micro` for the control plane.

**Not** capacity-certified for thousands of DAG definitions or 25k+ tasks/day.
Default demo concurrency is roughly **10** parallel task pods.

## Happy path

1. Fork / use template; clone your copy.
2. Bootstrap (creates state backend + GitHub env/vars/secrets):
   - `.\scripts\bootstrap.ps1 -BudgetAlertEmail you@example.com`
   - `./scripts/bootstrap.sh --email you@example.com`
3. Actions → **Deploy Infrastructure** (green).
4. Actions → **Deploy Airflow to EKS** (green).
5. `.\scripts\open-airflow.ps1` or `./scripts/open-airflow.sh` → http://127.0.0.1:8080  
   Login: `admin` / password printed by bootstrap (`AIRFLOW_ADMIN_PASSWORD`).
6. When done: **Destroy Demo Stack** → type `destroy`  
   (or `.\scripts\teardown.ps1`).

## Demo capacity (defaults)

| Layer | Setting |
| --- | --- |
| System nodes | `m7i-flex.large` × 2 |
| Worker nodes | `t3.small`, min **0**, max **2** |
| Metadata DB | `db.t3.micro` |
| Airflow `parallelism` | 16 (cluster usually binds first ~10) |
| Network | Single NAT Gateway |

## Validation checklist

1. Terraform state object exists in the bootstrap S3 bucket.
2. `kubectl get pods -n airflow` — scheduler, api-server, dag-processor, triggerer Ready.
3. UI login works via port-forward helper.
4. Trigger `controlled_kubernetes_scale_test` with ~10–20 tasks; worker ASG moves toward max 2.
5. Optional: add a new `dags/*.py` file, push to `main`, wait for **Deploy Airflow to EKS**, confirm DAG in UI.

## DAG deploy rules

- DAGs are **not** git-synced live. Push under `dags/` must run the Airflow deploy workflow (image rebuild).
- Filenames must end in **`.py`** or Airflow will ignore them.

## Cleanup

GitHub Actions → **Destroy Demo Stack** → `destroy`.

After destroy, bootstrap state bucket/lock table can be deleted if unused (destroy workflow / local teardown leave them unless cleaned separately).

## Related docs

- [README](../README.md) — fork-and-deploy overview  
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — CI / OIDC / Helm failures  
- [PRESENTATION.md](PRESENTATION.md) — live demo script  
- [INTERVIEW_SCRIPT.md](INTERVIEW_SCRIPT.md) — architecture Q&A  
