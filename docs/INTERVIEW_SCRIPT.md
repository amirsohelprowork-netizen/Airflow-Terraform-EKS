# Mock Interview: Airflow on EKS

**Role**: Junior / Mid DevOps or Platform Engineer  
**Interviewer**: Senior DevOps Engineer (Sarah)  
**Candidate**: You (Alex)

Use this as a speaking script. Be honest: the public repo is a **cost-capped demo** that proves enterprise *patterns*, not unlimited production capacity.

---

**Sarah**: I saw your Airflow-on-EKS GitHub project. Give me a high-level overview.

**Alex**: I built a reference Apache Airflow 3 deployment on Amazon EKS. Terraform provisions the platform — VPC, EKS with two node groups, RDS PostgreSQL for metadata, ECR, S3 for remote logs, IRSA, GitHub OIDC, Cluster Autoscaler, and an optional AWS Budget. GitHub Actions has two paths: one applies infrastructure, the other builds an immutable, commit-SHA-tagged image with DAGs, deploys with Helm, and we have a destroy workflow so demos don’t leave EKS burning money. The default profile is deliberately small — about ten concurrent KubernetesExecutor tasks — so people can fork it on credits without pretending it’s a 30k-tasks-per-day farm.

**Sarah**: Why EKS and KubernetesExecutor instead of one EC2 with LocalExecutor?

**Alex**: Isolation and elasticity. Every task is its own Pod on a tainted worker node group, so a bad task can’t take down the scheduler. Cluster Autoscaler can grow workers from zero when pods are Pending and shrink when idle. The control plane stays on separate system nodes — we use Free Tier–eligible `m7i-flex.large` there because `t3.micro`’s 1 GiB can’t host Airflow 3 components reliably.

**Sarah**: How is CI/CD structured?

**Alex**: Platform vs application. **Deploy Infrastructure** runs Terraform with bootstrap IAM keys — that’s the chicken-and-egg: Terraform creates the GitHub OIDC provider and deploy role. **Deploy Airflow to EKS** assumes that role with OIDC, reads cluster/ECR/bucket ARNs from remote Terraform state (no hand-copying outputs), validates DAGs, builds and pushes the image, deploys Cluster Autoscaler and the official Airflow Helm chart, then waits for pods Ready. Forkers run one bootstrap script that creates state backends and sets GitHub variables/secrets via `gh`.

**Sarah**: You’re baking DAGs into the image. Why not EFS or git-sync?

**Alex**: Immutability. Each deploy is a known SHA. Rollback is changing the image tag. Git-sync is fine for some teams, but then the running set of DAGs can drift from what’s in CI. Important detail: Airflow only loads `*.py` files — an extensionless file in `dags/` will sit in the image and never appear in the UI.

**Sarah**: How does GitHub authenticate to AWS for the app pipeline?

**Alex**: OIDC — `AssumeRoleWithWebIdentity`, no long-lived app keys. The trust policy is scoped to this repository and the `demo` environment. After GitHub’s 2026 immutable subject claims (and renames), the `sub` looks like `repo:org@id/repo@id:environment:demo`, so the IAM trust must match both classic and immutable formats or you get AccessDenied. Infra still uses access keys once to create that trust.

**Sarah**: How do Airflow pods write logs to S3?

**Alex**: IRSA. An IAM role is bound to the Airflow service accounts — scheduler, api-server, workers, dag-processor, triggerer — with least-privilege access to that log bucket only, not the whole cluster.

**Sarah**: Where is Terraform state, and how do you avoid secret issues in the metadata DB connection?

**Alex**: Remote state in S3 with DynamoDB locking — never commit `tfstate`. RDS uses Secrets Manager for the master password. We URL-encode that password when writing the Kubernetes `airflow-metadata` connection string; without that, special characters break URL parsing and you get `Invalid IPv6 URL` and CrashLoop on `wait-for-airflow-migrations`.

**Sarah**: What would you change for real production scale — say tens of thousands of tasks a day?

**Alex**: Keep the same patterns, change the profile: more and larger worker nodes, higher `parallelism`, stronger Multi-AZ RDS, multi-NAT, private API endpoint with runners in the VPC, TLS ingress, monitoring and alerts, NetworkPolicies. The demo defaults and destroy workflow exist so people learn the architecture without leaving a bill running overnight.

**Sarah**: Solid. You’ve shown you understand the trade-offs, not just the YAML. Thanks, Alex.

**Alex**: Thank you, Sarah.

---

## Quick cheat sheet (if you freeze)

| Topic | One-liner |
| --- | --- |
| Executor | KubernetesExecutor → one Pod per task |
| Nodes | System (`m7i-flex.large`) vs workers (`t3.small`, scale 0→2) |
| DAGs | Baked into SHA-tagged image; must be `*.py` |
| Auth app CI | GitHub OIDC (classic + immutable `sub`) |
| Auth pods → S3 | IRSA |
| State | S3 + DynamoDB lock |
| RDS secret | Secrets Manager + `urlencode` in K8s secret |
| Cost | Destroy same day; EKS/NAT not Free Tier |
| Capacity | Demo ≈ 10 concurrent tasks |
