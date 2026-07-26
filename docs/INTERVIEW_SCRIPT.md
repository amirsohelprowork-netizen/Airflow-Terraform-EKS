# 🎙️ Mock Interview: Airflow on EKS

**Role**: Junior DevOps Engineer  
**Interviewer**: Senior DevOps Engineer (Sarah)  
**Candidate**: You (Alex)  

---

**Sarah (Interviewer)**: Hi Alex, thanks for coming in. I was reviewing your GitHub portfolio and I saw the "Enterprise Airflow on EKS" project. I’d love to dive into that. Can you give me a high-level overview of the architecture you built?

**Alex (Candidate)**: Absolutely. I built a production-ready Apache Airflow deployment on AWS. Instead of running it on a single EC2 instance, I used Terraform to provision an Amazon EKS cluster for the compute, and an RDS PostgreSQL instance for the Airflow metadata database. I also set up a two-stage CI/CD pipeline using GitHub Actions to fully automate both the infrastructure provisioning and the Airflow DAG deployments.

**Sarah**: Interesting. Why EKS? Airflow is often just run on a single virtual machine with the `LocalExecutor` for simplicity. Why did you choose the added complexity of Kubernetes?

**Alex**: That's true, a single VM is simpler, but it doesn't scale well and lacks isolation. I chose EKS specifically so I could use the `KubernetesExecutor`. With the `KubernetesExecutor`, every single Airflow task runs in its own isolated Pod. This means tasks don't fight for CPU or memory, and they can't crash the main Airflow scheduler. Plus, if there is a sudden spike in tasks, EKS can automatically spin up new worker nodes to handle the load, and then spin them down to save costs when the queue is empty.

**Sarah**: Good answer. Let's talk about the CI/CD pipeline. You mentioned a "two-stage" pipeline. How did you structure your GitHub Actions?

**Alex**: I separated the Platform layer from the Application layer. 
The first pipeline is the **Infrastructure Pipeline**. It runs `terraform apply` to build or update the VPC, the EKS cluster, and the RDS database. 
The second pipeline is the **Application Pipeline**. When a developer writes a new DAG, this pipeline builds a new Docker image containing those DAGs, tags it with the unique git commit SHA, pushes it to Amazon ECR, and then uses Helm to upgrade the Airflow deployment on the cluster with zero downtime. 

**Sarah**: Wait, you're baking the DAGs directly into the Docker image? Why not just use a shared file system like Amazon EFS, or Git-Sync to pull DAGs dynamically?

**Alex**: I chose to bake the DAGs into the Docker image because it enforces **immutability**. If a deployment breaks, I know exactly which Docker image tag caused it, and I can instantly roll back to the previous tag. With EFS or Git-Sync, the code changes dynamically underneath the running containers, which can lead to unpredictable state and makes rollbacks much harder to control in a strict production environment.

**Sarah**: Spot on. Immutability is critical for reliability. Let's talk about security. How is your GitHub Actions pipeline authenticating to AWS? Did you create an IAM User and put the Access Keys in GitHub Secrets?

**Alex**: That depends on which pipeline we are talking about! This is a classic "chicken-and-egg" bootstrap problem. For the **Application Pipeline** (Phase 2), I absolutely used **OIDC (OpenID Connect)**. I configured AWS to trust my specific GitHub repository, so GitHub just requests a temporary, short-lived token from AWS to deploy the DAGs. There are no passwords to steal. 
However, for the initial **Infrastructure Pipeline** (Phase 1), I *did* have to use an IAM User Access Key temporarily. Why? Because the OIDC trust relationship itself is created *by* Terraform! Terraform needs access keys to build the OIDC role before Airflow can use it. In a true corporate environment, a dedicated security team would bootstrap the OIDC role for me, but for a standalone project, you have to use keys for the initial build.

**Sarah**: I love hearing that. What about Airflow itself? Airflow needs to write task logs to an S3 bucket. How did you grant those Kubernetes Pods permission to talk to S3?

**Alex**: I used the exact same least-privilege philosophy. I used **IRSA (IAM Roles for Service Accounts)**. Instead of giving the entire EKS cluster access to S3, IRSA allows me to attach an IAM Role directly to a specific Kubernetes Service Account. So, only the specific Airflow worker Pods get temporary permissions to write to that exact S3 log bucket. The rest of the cluster has no access.

**Sarah**: Excellent. Last question. You used Terraform. Where did you store your Terraform state? You didn't commit `terraform.tfstate` to Git, did you?

**Alex**: No, committing state files to Git is dangerous because they can contain plaintext secrets. I configured a remote Terraform backend. The state file is stored securely in an encrypted Amazon S3 bucket, and I used a DynamoDB table for state locking. This ensures that if two developers trigger the Infrastructure pipeline at the exact same time, DynamoDB locks the state so they don't corrupt the infrastructure.

**Sarah**: Well, Alex, I have to say I'm incredibly impressed. You clearly understand not just *how* to use these tools, but *why* they are the right choice for enterprise environments. You’ve passed with flying colors. Welcome to the team!

**Alex**: Thank you so much, Sarah! I can't wait to get started.
