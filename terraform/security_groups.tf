####################################################
# Security Groups
####################################################

resource "aws_security_group" "airflow" {
  name_prefix = "${var.project_name}-${var.environment}-"
  description = "Security group for Airflow EC2 instance"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "SSH access"
  }

  # Airflow Web UI
  ingress {
    from_port   = var.airflow_ui_port
    to_port     = var.airflow_ui_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "Airflow Web UI"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-airflow-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
