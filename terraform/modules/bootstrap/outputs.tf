output "environments" {
  description = "Database, roles e namespace de cada ambiente."
  value       = var.environments
}

output "lambda_passwords" {
  description = "Senha da role da Lambda em cada ambiente."
  value       = { for key, password in random_password.lambda : key => password.result }
  sensitive   = true
}

output "api_secret_names" {
  description = "Secret da API em cada ambiente (namespace/nome)."
  value       = { for key, secret in kubernetes_secret_v1.api : key => "${secret.metadata[0].namespace}/${secret.metadata[0].name}" }
}

output "bootstrap_job_name" {
  description = "Job que cria roles, databases e tabelas de estado da Lambda."
  value       = kubernetes_job_v1.bootstrap.metadata[0].name
}

output "auth_clients_job_name" {
  description = "Job que cria a view auth_clients depois das migrations da API."
  value       = kubernetes_job_v1.auth_clients.metadata[0].name
}
