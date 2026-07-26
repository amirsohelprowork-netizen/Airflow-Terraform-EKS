# Enterprise Airflow reference demo on Amazon EKS

This repository is a production-shaped demonstration of Apache Airflow on Amazon EKS using an **Infrastructure as Code (IaC) and CI/CD** approach. 

It is designed as an open-source template for deploying:
- Kubernetes task isolation
- Managed PostgreSQL (RDS)
- Immutable Docker releases
- Least-privilege AWS IAM identity
- Central logs (S3)

## ⚠️ AWS Free Tier Warning
**Amazon EKS is NOT included in the AWS Free Tier.** The control plane alone costs ~$0.10/hour (~$73/month). The NAT Gateway and worker nodes will add additional costs. **This project will cost ~$3 to $4 per day to run.** Always destroy the resources when you are finished testing!

## Architecture

```text
GitHub Actions (OIDC) → ECR immutable Airflow image → EKS + Helm
                                                  ├─ scheduler replicas
                                                  ├─ webserver replicas
                                                  └─ KubernetesExecutor task Pods
                                                            ↓
                                             RDS PostgreSQL + S3 remote logs
```

This code has **not** been applied; it cannot incur new AWS charges until you
run Terraform apply.

## Why KubernetesExecutor

Each task runs in an isolated Kubernetes Pod with defined CPU/memory limits.
EKS can add worker nodes for queued Pods, while the Airflow control plane stays
on a dedicated node group. This is stronger than a single EC2 + LocalExecutor
deployment, but customer capacity must still be proven by a load test.

## Two-Phase Deployment Architecture

This template is separated into two distinct GitHub Actions CI/CD pipelines to mimic enterprise best practices:

### Phase 1: Platform & Infrastructure (`deploy-infra.yml`)
1. Fork this repository to your own GitHub account.
2. In your AWS Account, create an OIDC Identity Provider for GitHub Actions (or use access keys).
3. Run `scripts/bootstrap-remote-state.ps1` locally to create an S3 bucket for your Terraform state.
4. Push any changes to the `terraform/` folder.
5. GitHub Actions will automatically run `terraform apply` to build your EKS cluster, RDS database, and VPC.

### Phase 2: Application & DAGs (`deploy-airflow-eks.yml`)
1. Once the infrastructure is ready, edit the DAGs in the `dags/` folder.
2. Update Python packages in `requirements/requirements.txt` if needed.
3. Push to the `main` branch.
4. GitHub Actions will automatically:
   - Build a new Docker image containing your DAGs and dependencies.
   - Push the immutable image to Amazon ECR.
   - Run a `helm upgrade` to seamlessly deploy the new Airflow image onto your EKS cluster.

## Teardown

To avoid incurring massive AWS charges, destroy the environment immediately after you are finished evaluating it:
```bash
cd terraform
terraform destroy -auto-approve
```
