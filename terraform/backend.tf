terraform {
  backend "s3" {
    bucket         = "airflow-enterprise-demo-tfstate-20260727235127"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "airflow-enterprise-demo-tflock"
    encrypt        = true
  }
}
