#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="${NAMESPACE:-airflow}"
LOCAL_PORT="${LOCAL_PORT:-8080}"

echo "Resolving EKS cluster..."
CLUSTER="$(aws eks list-clusters --region "$AWS_REGION" --query "clusters[?contains(@, 'airflow')]|[0]" --output text)"
if [[ -z "$CLUSTER" || "$CLUSTER" == "None" ]]; then
  CLUSTER="$(aws eks list-clusters --region "$AWS_REGION" --query 'clusters[0]' --output text)"
fi
if [[ -z "$CLUSTER" || "$CLUSTER" == "None" ]]; then
  echo "ERROR: No EKS cluster found in ${AWS_REGION}. Did Deploy Infrastructure succeed?"
  exit 1
fi

echo "Using cluster: ${CLUSTER}"
aws eks update-kubeconfig --name "$CLUSTER" --region "$AWS_REGION" >/dev/null

kubectl -n "$NAMESPACE" get svc airflow-api-server >/dev/null

echo ""
echo "Port-forwarding http://127.0.0.1:${LOCAL_PORT}  (Ctrl+C to stop)"
echo "Login user: admin"
echo "Password: GitHub secret AIRFLOW_ADMIN_PASSWORD (printed by bootstrap)"
echo ""
kubectl -n "$NAMESPACE" port-forward svc/airflow-api-server "${LOCAL_PORT}:8080"
