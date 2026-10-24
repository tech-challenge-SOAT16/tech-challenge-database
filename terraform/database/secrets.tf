# recovery_window_in_days = 0: o Academy recria o ambiente com frequência e um
# secret em recuperação bloqueia o mesmo nome por até 30 dias.
resource "aws_secretsmanager_secret" "master" {
  name                    = "${var.project_name}/database/master"
  description             = "Usuario master do RDS PostgreSQL"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    username = aws_db_instance.this.username
    password = random_password.master.result
  })
}

# Secret da Lambda de autenticação por ambiente. O Terraform grava só a
# database_connection; o responsável pela Lambda preenche private_key e
# otp_secret no console ou com put-secret-value. Por isso mudanças posteriores
# no conteúdo são ignoradas (ver README).
resource "aws_secretsmanager_secret" "lambda" {
  for_each = var.environments

  name                    = "${var.project_name}/lambda-auth/${each.key}"
  description             = "Segredos da Lambda de autenticacao (${each.key})"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "lambda" {
  for_each = var.environments

  secret_id = aws_secretsmanager_secret.lambda[each.key].id
  secret_string = jsonencode({
    database_connection = join(";", [
      "Host=${aws_db_instance.this.address}",
      "Port=${aws_db_instance.this.port}",
      "Database=${each.value.database}",
      "Username=${each.value.lambda_role}",
      "Password=${module.bootstrap.lambda_passwords[each.key]}",
      "SSL Mode=VerifyFull",
      "Root Certificate=/var/task/certs/rds-global-bundle.crt",
    ])
    private_key = ""
    otp_secret  = ""
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
