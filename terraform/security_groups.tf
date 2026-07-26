####################################################
# Security Groups for MWAA
####################################################

# MWAA requires a self-referencing security group
# that allows all traffic within the group
resource "aws_security_group" "mwaa" {
  name_prefix = "${var.project_name}-${var.environment}-mwaa-"
  description = "Security group for MWAA environment"
  vpc_id      = aws_vpc.main.id

  # Ingress: Allow all traffic from within the same security group
  # Required for MWAA workers, scheduler, and webserver to communicate
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
    description = "Allow all intra-MWAA traffic"
  }

  # Egress: Allow all outbound traffic
  # Required for MWAA to access AWS services (S3, CloudWatch, SQS, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-mwaa-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
