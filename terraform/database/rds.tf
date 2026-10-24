resource "random_password" "master" {
  length  = 32
  special = false
}

resource "aws_db_subnet_group" "this" {
  name        = "${var.project_name}-database"
  description = "Subnets privadas da VPC do tech-challenge-k8s"
  subnet_ids  = local.cluster.private_subnet_ids
}

# rds.force_ssl recusa conexões sem TLS (padrão no PostgreSQL 15+ do RDS,
# fixado aqui para não depender do padrão).
resource "aws_db_parameter_group" "this" {
  name        = "${var.project_name}-postgres17"
  family      = "postgres17"
  description = "PostgreSQL 17 com TLS obrigatorio"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.project_name}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  # Sem database padrão: o Job de bootstrap cria um por ambiente.
  username = var.master_username
  password = random_password.master.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [local.cluster.database_security_group_id]
  parameter_group_name   = aws_db_parameter_group.this.name
  ca_cert_identifier     = "rds-ca-rsa2048-g1"
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period  = var.backup_retention_days
  backup_window            = "06:00-07:00"
  maintenance_window       = "sun:07:30-sun:08:30"
  copy_tags_to_snapshot    = true
  delete_automated_backups = true

  # Limites do AWS Academy: sem Enhanced Monitoring (exige role própria) e sem
  # Performance Insights. Com create_iam_roles = true o monitoring é ligado.
  monitoring_interval          = var.create_iam_roles ? var.monitoring_interval : 0
  monitoring_role_arn          = var.create_iam_roles ? aws_iam_role.monitoring[0].arn : null
  performance_insights_enabled = var.performance_insights_enabled

  auto_minor_version_upgrade = true
  apply_immediately          = true
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : "${var.project_name}-postgres-final"

  tags = {
    Name = "${var.project_name}-postgres"
  }
}
