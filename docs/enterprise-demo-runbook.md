# Airflow EKS demo runbook

## Scope

This is a cost-capped, short-lived EKS demonstration. It mirrors core
enterprise patterns—immutable images, RDS metadata, remote logs, OIDC, IRSA,
and isolated KubernetesExecutor pods—but it is not highly available or a
capacity-certified production platform.

## Required GitHub configuration

Run `scripts/bootstrap-remote-state.ps1` once, then add its output as
repository variables:

- `AWS_REGION`, `AWS_ACCOUNT_ID`
- `TF_STATE_BUCKET`, `TF_LOCK_TABLE`, `TF_STATE_KEY`
- `TF_VAR_KUBERNETES_VERSION`
- `TF_VAR_ADMIN_CIDR_BLOCKS` (`["0.0.0.0/0"]` is required by GitHub-hosted
  runners; production needs a private endpoint and a VPC runner.)

Add the following repository secrets:

- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` for the one-time infrastructure
  bootstrap only
- `AIRFLOW_ADMIN_PASSWORD`, `AIRFLOW_API_SECRET_KEY`

## Demo validation

1. Run infrastructure deployment and confirm Terraform state is in S3.
2. Deploy Airflow and use local port-forwarding to reach the UI.
3. Trigger `controlled_kubernetes_scale_test` with 20 tasks.
4. Watch task Pods and the worker Auto Scaling Group. The maximum task node
   count is deliberately capped at three in the demo profile.

## Cleanup

```bash
helm uninstall airflow -n airflow
helm uninstall cluster-autoscaler -n kube-system
cd terraform
terraform destroy
```

Only after the stack is destroyed, delete the Terraform state bucket and lock
table if their history is no longer needed.
