terraform {
  backend "s3" {
    bucket         = "airflow-eks-tfstate-20260728231302"
    key            = "airflow-demo/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "airflow-eks-tflock-20260728231302"
    encrypt        = true
  }
}
