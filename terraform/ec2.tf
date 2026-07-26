####################################################
# EC2 Instance running Airflow via Docker Compose
####################################################

# ---------- Get latest Amazon Linux 2023 AMI ----------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------- SSH Key Pair (auto-generated) ----------
resource "tls_private_key" "airflow" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "airflow" {
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = tls_private_key.airflow.public_key_openssh

  tags = {
    Name = "${var.project_name}-${var.environment}-key"
  }
}

# Save private key locally for SSH access
resource "local_file" "private_key" {
  content         = tls_private_key.airflow.private_key_pem
  filename        = "${path.module}/airflow-key.pem"
  file_permission = "0600"
}

# ---------- EC2 Instance ----------
resource "aws_instance" "airflow" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.airflow.key_name
  vpc_security_group_ids = [aws_security_group.airflow.id]
  subnet_id              = aws_subnet.public.id

  # 30 GB root volume (Airflow + Docker images need space)
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-${var.environment}-root"
    }
  }

  # User data script to install Docker, Docker Compose, and start Airflow
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    airflow_image_tag      = var.airflow_image_tag
    airflow_admin_username = var.airflow_admin_username
    airflow_admin_password = var.airflow_admin_password
  }))

  tags = {
    Name = "${var.project_name}-${var.environment}-airflow"
  }

  # Wait for user_data to complete
  timeouts {
    create = "15m"
  }
}

# ---------- Elastic IP (stable public IP) ----------
resource "aws_eip" "airflow" {
  instance = aws_instance.airflow.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip"
  }
}
