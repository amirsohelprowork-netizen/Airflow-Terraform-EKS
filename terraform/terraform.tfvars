# Do not commit terraform.tfvars. Replace the Kubernetes version with one supported in us-east-1.
kubernetes_version = "1.30"
admin_cidr_blocks  = ["YOUR.PUBLIC.IP/32"]
github_repository  = "YOUR_ORG/YOUR_REPO"

# Demo defaults are intentionally constrained. Raise these only after performance testing.
max_worker_nodes       = 10
enable_multi_az        = false
backup_retention_days  = 1
