# Demo walkthrough

The supported setup instructions are in the repository [README](../README.md).

This is a deliberately short-lived EKS demonstration. It uses AWS credits, not
only Free Tier services. Before presenting it, set an AWS Budget and confirm
that `terraform destroy` is available to the operator.

## Demonstration sequence

1. Show the remote Terraform state bucket and DynamoDB lock table created by
   `scripts/bootstrap-remote-state.ps1`.
2. Run **Deploy Infrastructure**. It provisions VPC, EKS, RDS, S3, ECR, IRSA,
   scoped GitHub OIDC, and Cluster Autoscaler IAM.
3. Run **Deploy Airflow to EKS**. It obtains the image repository, cluster,
   bucket, and IAM roles from remote Terraform state rather than copied output
   variables.
4. Trigger `controlled_kubernetes_scale_test` with a low task count, then watch
   the dedicated task node group grow from zero.
5. Access the UI using `kubectl port-forward`; no public load balancer is
   created in the demo profile.
6. Uninstall Helm releases and run `terraform destroy` immediately afterwards.

Do not represent this small demonstration as capacity certification for
thousands of DAGs or task instances. Use a representative load test first.
