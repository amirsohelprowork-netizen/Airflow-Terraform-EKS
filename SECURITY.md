# Security Policy

## Reporting a vulnerability

Do **not** open a public GitHub issue for security problems that expose credentials or cluster access.

Email the repository maintainer, or open a **private** GitHub security advisory if available.

## What this project stores

- **GitHub Actions secrets** hold AWS bootstrap keys and Airflow UI credentials.
- **AWS Secrets Manager** holds the RDS master password.
- Terraform state lives in **your** S3 bucket (never commit `*.tfstate` or `terraform.tfvars`).

## Rules for forks

1. Never commit AWS access keys, Airflow passwords, or `.tfvars` with secrets.
2. Use a **dedicated IAM user** for `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — not the root account.
3. Run **Destroy Demo Stack** when finished so EKS/NAT do not keep charging.
4. Prefer forking into a personal account; org-wide OIDC mistakes can let other repos deploy into your AWS account if you loosen trust policies.

## Placeholders in Helm values

`CHANGE-ME` strings in `helm/airflow/values.yaml` are intentional. CI overrides them with GitHub secrets at deploy time. Do not put real passwords in that file.
