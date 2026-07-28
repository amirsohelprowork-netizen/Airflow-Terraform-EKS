#!/usr/bin/env bash
# One-time bootstrap for forks: Terraform remote state + GitHub Actions vars/secrets.
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
BUDGET_LIMIT_USD="${BUDGET_LIMIT_USD:-40}"
SKIP_GITHUB="${SKIP_GITHUB:-0}"
BUDGET_ALERT_EMAIL="${BUDGET_ALERT_EMAIL:-}"

usage() {
  cat <<EOF
Usage: ./scripts/bootstrap.sh --email you@example.com [options]

Options:
  --email EMAIL          Required. AWS Budget alert email.
  --region REGION        AWS region (default: us-east-1).
  --budget-limit USD     Monthly budget (default: 40).
  --skip-github          Only create AWS state backend; print values.
  -h, --help             Show help.

Also accepts env: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (for GitHub secrets).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --email) BUDGET_ALERT_EMAIL="$2"; shift 2 ;;
    --region) AWS_REGION="$2"; shift 2 ;;
    --budget-limit) BUDGET_LIMIT_USD="$2"; shift 2 ;;
    --skip-github) SKIP_GITHUB=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$BUDGET_ALERT_EMAIL" ]]; then
  echo "ERROR: --email is required (used for AWS Budget alerts)."
  usage
  exit 1
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: required command not found: $1"; exit 1; }; }
need aws

echo "==> Checking AWS identity..."
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
echo "    Account: ${ACCOUNT_ID}  Region: ${AWS_REGION}"

echo "==> Detecting a supported EKS Kubernetes version..."
K8S_VERSION="$(
  aws eks describe-addon-versions --region "$AWS_REGION" --addon-name vpc-cni \
    --query 'addons[0].addonVersions[].compatibilities[].clusterVersion' --output text \
    | tr '\t' '\n' | grep -E '^[0-9]+\.[0-9]+$' | sort -u | tail -1
)"
if [[ -z "$K8S_VERSION" ]]; then
  echo "ERROR: could not detect EKS versions in ${AWS_REGION}"
  exit 1
fi
echo "    Using Kubernetes ${K8S_VERSION}"

TS="$(date +%Y%m%d%H%M%S)"
BUCKET="airflow-eks-tfstate-${TS}"
LOCK_TABLE="airflow-eks-tflock-${TS}"
STATE_KEY="airflow-demo/terraform.tfstate"

echo "==> Creating Terraform state bucket: ${BUCKET}"
if [[ "$AWS_REGION" == "us-east-1" ]]; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION" >/dev/null
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION" \
    --create-bucket-configuration "LocationConstraint=${AWS_REGION}" >/dev/null
fi
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled >/dev/null
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true >/dev/null

echo "==> Creating Terraform lock table: ${LOCK_TABLE}"
aws dynamodb create-table \
  --table-name "$LOCK_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION" >/dev/null
aws dynamodb wait table-exists --table-name "$LOCK_TABLE" --region "$AWS_REGION"

ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)"
API_SECRET_KEY="$(openssl rand -base64 48 | tr -d '/+=' | cut -c1-48)"

echo ""
echo "Generated Airflow admin password (save this): ${ADMIN_PASSWORD}"
echo ""

if [[ "$SKIP_GITHUB" == "1" ]]; then
  echo "SKIP_GITHUB=1 — configure GitHub manually."
  echo "AWS_REGION=${AWS_REGION}"
  echo "AWS_ACCOUNT_ID=${ACCOUNT_ID}"
  echo "TF_STATE_BUCKET=${BUCKET}"
  echo "TF_LOCK_TABLE=${LOCK_TABLE}"
  echo "TF_STATE_KEY=${STATE_KEY}"
  echo "TF_VAR_KUBERNETES_VERSION=${K8S_VERSION}"
  echo "TF_VAR_ADMIN_CIDR_BLOCKS=[\"0.0.0.0/0\"]"
  echo "BUDGET_ALERT_EMAIL=${BUDGET_ALERT_EMAIL}"
  echo "BUDGET_LIMIT_USD=${BUDGET_LIMIT_USD}"
else
  need gh
  gh auth status >/dev/null
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
  echo "==> Configuring GitHub repo: ${REPO}"

  echo "    Ensuring Environment 'demo' exists..."
  gh api --method PUT "repos/${REPO}/environments/demo" >/dev/null 2>&1 || true

  if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    echo "Enter IAM access keys for GitHub Actions (infra/destroy only — not root):"
    read -r -p "AWS_ACCESS_KEY_ID: " AWS_ACCESS_KEY_ID
    read -r -s -p "AWS_SECRET_ACCESS_KEY: " AWS_SECRET_ACCESS_KEY
    echo ""
  fi

  echo "    Setting repository variables..."
  gh variable set AWS_REGION --body "$AWS_REGION" --repo "$REPO"
  gh variable set AWS_ACCOUNT_ID --body "$ACCOUNT_ID" --repo "$REPO"
  gh variable set TF_STATE_BUCKET --body "$BUCKET" --repo "$REPO"
  gh variable set TF_LOCK_TABLE --body "$LOCK_TABLE" --repo "$REPO"
  gh variable set TF_STATE_KEY --body "$STATE_KEY" --repo "$REPO"
  gh variable set TF_VAR_KUBERNETES_VERSION --body "$K8S_VERSION" --repo "$REPO"
  gh variable set TF_VAR_ADMIN_CIDR_BLOCKS --body '["0.0.0.0/0"]' --repo "$REPO"
  gh variable set BUDGET_ALERT_EMAIL --body "$BUDGET_ALERT_EMAIL" --repo "$REPO"
  gh variable set BUDGET_LIMIT_USD --body "$BUDGET_LIMIT_USD" --repo "$REPO"

  echo "    Setting repository secrets..."
  printf '%s' "$AWS_ACCESS_KEY_ID" | gh secret set AWS_ACCESS_KEY_ID --repo "$REPO"
  printf '%s' "$AWS_SECRET_ACCESS_KEY" | gh secret set AWS_SECRET_ACCESS_KEY --repo "$REPO"
  printf '%s' "$ADMIN_PASSWORD" | gh secret set AIRFLOW_ADMIN_PASSWORD --repo "$REPO"
  printf '%s' "$API_SECRET_KEY" | gh secret set AIRFLOW_API_SECRET_KEY --repo "$REPO"

  echo "==> GitHub configuration complete."
fi

cat <<EOF

==========================================
 NEXT STEPS
==========================================
1. Open GitHub Actions on your fork.
2. Run workflow: Deploy Infrastructure  (wait until green).
3. Run workflow: Deploy Airflow to EKS  (wait until green).
4. Open the UI:
     ./scripts/open-airflow.sh
   Login: admin / (password printed above)
5. When finished, run: Destroy Demo Stack  (type destroy).

State backend: s3://${BUCKET}/${STATE_KEY}  lock=${LOCK_TABLE}
Docs: README.md  and  docs/TROUBLESHOOTING.md
EOF
