####################################################
# Outputs
####################################################

output "airflow_url" {
  description = "URL for the Airflow web UI"
  value       = "http://${aws_eip.airflow.public_ip}:${var.airflow_ui_port}"
}

output "airflow_public_ip" {
  description = "Public IP of the Airflow EC2 instance"
  value       = aws_eip.airflow.public_ip
}

output "airflow_admin_username" {
  description = "Airflow admin username"
  value       = var.airflow_admin_username
}

output "airflow_admin_password" {
  description = "Airflow admin password"
  value       = var.airflow_admin_password
  sensitive   = true
}

output "ssh_command" {
  description = "SSH command to connect to the Airflow instance"
  value       = "ssh -i terraform/airflow-key.pem ec2-user@${aws_eip.airflow.public_ip}"
}

output "ssh_private_key_path" {
  description = "Path to the SSH private key"
  value       = local_file.private_key.filename
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.airflow.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "destroy_warning" {
  description = "Reminder to destroy resources when done testing"
  value       = "⚠️  Remember to run 'terraform destroy' when done testing to avoid charges!"
}
