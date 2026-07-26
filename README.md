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
2. Create an AWS IAM User with Administrator permissions (or appropriate least-privilege).
3. In your GitHub repository, go to **Settings → Secrets and variables → Actions**.
4. Add the following **Secrets**:
   - `AWS_ACCESS_KEY_ID`: Your IAM user access key.
   - `AWS_SECRET_ACCESS_KEY`: Your IAM user secret key.
5. Add the following **Variable**:
   - `AWS_REGION`: e.g., `us-east-1`
6. Run `scripts/bootstrap-remote-state.ps1` locally to create an S3 bucket for your Terraform state.
7. Push any changes to the `terraform/` folder to automatically trigger the build.

### Phase 2: Application & DAGs (`deploy-airflow-eks.yml`)
1. Once Phase 1 completes successfully, view the GitHub Actions logs for the "Terraform Apply" step to get your newly created AWS resources.
2. In your GitHub repository, go to **Settings → Secrets and variables → Actions** and add the following **Variables**:
   - `AWS_DEPLOY_ROLE_ARN`: The OIDC IAM Role ARN created by Terraform.
   - `EKS_CLUSTER_NAME`: The name of the EKS cluster.
   - `ECR_REPOSITORY`: The ECR repository path.
   - `AIRFLOW_LOG_BUCKET`: The S3 bucket name for Airflow remote logging.
3. Edit your DAGs in the `dags/` folder.
4. Push to the `main` branch to automatically build and deploy your Airflow application.

## Teardown

To avoid incurring massive AWS charges, destroy the environment immediately after you are finished evaluating it:
```bash
cd terraform
terraform destroy -auto-approve
```
