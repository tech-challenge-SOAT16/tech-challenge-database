output "endpoint" {
  description = "Endereço do RDS (host:porta)."
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Host do RDS."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Porta do RDS."
  value       = aws_db_instance.this.port
}

output "databases" {
  description = "Database, roles e namespace de cada ambiente."
  value       = module.bootstrap.environments
}

output "master_secret_arn" {
  description = "Secret com o usuário master."
  value       = aws_secretsmanager_secret.master.arn
}

output "lambda_secret_arns" {
  description = "Secret da Lambda por ambiente (variável secret_arn da Lambda)."
  value       = { for key, secret in aws_secretsmanager_secret.lambda : key => secret.arn }
}

output "api_secrets" {
  description = "Secret da API em cada ambiente."
  value       = module.bootstrap.api_secret_names
}

output "jobs" {
  description = "Jobs de bootstrap (kubectl -n techchallenge-database logs job/<nome>)."
  value       = [module.bootstrap.bootstrap_job_name, module.bootstrap.auth_clients_job_name]
}
