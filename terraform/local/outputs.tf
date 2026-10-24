output "host" {
  description = "Endereço do PostgreSQL dentro do cluster."
  value       = local.postgres_host
}

output "admin_password" {
  description = "Senha do usuário administrador (terraform output -raw admin_password)."
  value       = random_password.admin.result
  sensitive   = true
}

output "api_secrets" {
  description = "Secret da API em cada ambiente."
  value       = module.bootstrap.api_secret_names
}

output "jobs" {
  description = "Jobs de bootstrap (kubectl -n techchallenge-database logs job/<nome>)."
  value       = [module.bootstrap.bootstrap_job_name, module.bootstrap.auth_clients_job_name]
}
