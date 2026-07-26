####################################################
# AWS MWAA (Managed Workflows for Apache Airflow)
####################################################

resource "aws_mwaa_environment" "this" {
  name = "${var.project_name}-${var.environment}"

  # ---------- Airflow Configuration ----------
  airflow_version       = var.airflow_version
  environment_class     = var.environment_class
  webserver_access_mode = var.webserver_access_mode

  # ---------- S3 Source ----------
  source_bucket_arn     = aws_s3_bucket.mwaa.arn
  dag_s3_path           = var.dag_s3_path
  requirements_s3_path  = var.requirements_s3_path
  requirements_s3_object_version = aws_s3_object.requirements.version_id

  # ---------- IAM ----------
  execution_role_arn = aws_iam_role.mwaa_execution.arn

  # ---------- Networking ----------
  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = aws_subnet.private[*].id
  }

  # ---------- Scaling ----------
  max_workers = var.max_workers
  min_workers = var.min_workers

  # ---------- Airflow Config Overrides ----------
  airflow_configuration_options = {
    "core.default_timezone"           = "utc"
    "core.load_default_connections"   = "false"
    "core.load_examples"              = "false"
    "webserver.default_ui_timezone"   = "utc"
    "webserver.dag_default_view"      = "graph"
  }

  # ---------- Logging ----------
  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = var.logging_level
    }

    scheduler_logs {
      enabled   = true
      log_level = var.logging_level
    }

    task_logs {
      enabled   = true
      log_level = var.logging_level
    }

    webserver_logs {
      enabled   = true
      log_level = var.logging_level
    }

    worker_logs {
      enabled   = true
      log_level = var.logging_level
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-mwaa"
  }

  # MWAA environment creation takes ~25-30 minutes
  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }

  depends_on = [
    aws_s3_bucket_versioning.mwaa,
    aws_s3_bucket_public_access_block.mwaa,
    aws_iam_role_policy.mwaa_execution,
    aws_nat_gateway.main,
  ]
}
