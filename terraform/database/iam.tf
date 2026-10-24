# Só usado fora do AWS Academy (create_iam_roles = true): role do Enhanced
# Monitoring. No Learner Lab não é possível criar roles e a LabRole não confia
# em monitoring.rds.amazonaws.com, então o monitoring fica desligado.
resource "aws_iam_role" "monitoring" {
  count = var.create_iam_roles ? 1 : 0

  name = "${var.project_name}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count = var.create_iam_roles ? 1 : 0

  role       = aws_iam_role.monitoring[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
