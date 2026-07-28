# Apache Airflow on Amazon EKS (fork & deploy demo)

Deploy a cost-capped **Apache Airflow 3** stack on **Amazon EKS** with GitHub Actions — no Airflow/AWS expertise required for the happy path.

| | |
| --- | --- |
| Executor | `KubernetesExecutor` |
| Infra | Terraform (VPC, EKS, RDS, S3, ECR, IRSA, OIDC) |
| App deploy | Docker image (commit SHA) + Helm |
| Teardown | One Actions workflow |

> **Cost warning:** EKS and NAT Gateway are **not free**. Expect roughly **a few USD per day** while the stack is up. Destroy when finished. This is a short demo, not a production capacity platform (~10 concurrent tasks).

## 7-step deploy (happy path)

### 0. Prerequisites

- An AWS account (credits/Free Tier OK; you will still pay for EKS/NAT)
- Tools installed and logged in:
  - [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (`aws configure`)
  - [GitHub CLI](https://cli.github.com/) (`gh auth login`)
  - `kubectl` (for opening the UI)
- An IAM user with permission to create VPC/EKS/RDS (not root) — you will paste its access keys once

### 1. Use this template / fork

On GitHub: **Use this template** (preferred) or **Fork**, then clone **your** copy.

### 2. Bootstrap (one command)

**Windows (PowerShell):**

```powershell
.\scripts\bootstrap.ps1 -BudgetAlertEmail "you@example.com" -AwsRegion us-east-1
```

**Mac / Linux:**

```bash
chmod +x scripts/*.sh
./scripts/bootstrap.sh --email you@example.com --region us-east-1
```

This will:

- Create Terraform state S3 bucket + DynamoDB lock table  
- Detect a supported EKS version  
- Create GitHub Environment `demo`  
- Set all required GitHub **variables** and **secrets**  
- Print a random Airflow **admin password** — save it  

### 3. Deploy infrastructure

GitHub → **Actions** → **Deploy Infrastructure** → **Run workflow**.

Wait until it is green (~15–25 minutes).

### 4. Deploy Airflow

GitHub → **Actions** → **Deploy Airflow to EKS** → **Run workflow**.

Wait until it is green.

### 5. Open the UI

```powershell
.\scripts\open-airflow.ps1
```

```bash
./scripts/open-airflow.sh
```

Open http://127.0.0.1:8080 — user `admin`, password from bootstrap.

### 6. Try a DAG

In the UI, trigger `controlled_kubernetes_scale_test` with ~10–20 tasks and watch worker nodes scale.

### 7. Destroy (same day)

GitHub → **Actions** → **Destroy Demo Stack** → type `destroy` → run.

Leaving EKS up overnight will burn credits.

---

## What you get

- System nodes: `m7i-flex.large` × 2 (Airflow control plane; **not** `t3.micro`)  
- Workers: `t3.small` from **0** → max **2** (~10 concurrent tasks)  
- Metadata: RDS `db.t3.micro`  
- Logs: S3 via IRSA  
- App deploy auth: GitHub OIDC (after first infra apply)

## Docs

| Doc | Purpose |
| --- | --- |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Fix common CI / OIDC / Helm failures |
| [docs/enterprise-demo-runbook.md](docs/enterprise-demo-runbook.md) | Operator checklist |
| [SECURITY.md](SECURITY.md) | Secrets & reporting |
| [terraform/production.tfvars.example](terraform/production.tfvars.example) | Larger paid profile (not Free Tier) |

## Manual / advanced

If you cannot use `gh`, run state bootstrap only:

```powershell
.\scripts\bootstrap-remote-state.ps1 -AwsRegion us-east-1
```

Then set variables/secrets yourself (names printed by the script). See troubleshooting for details.

## License

MIT — see [LICENSE](LICENSE).
