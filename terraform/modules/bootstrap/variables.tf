variable "namespace" {
  description = "Namespace onde rodam os Jobs de bootstrap (precisa existir)."
  type        = string
}

variable "host" {
  description = "Endereço do PostgreSQL visto de dentro do cluster."
  type        = string
}

variable "port" {
  description = "Porta do PostgreSQL."
  type        = number
  default     = 5432
}

variable "admin_username" {
  description = "Usuário administrador (master do RDS) usado pelos Jobs."
  type        = string
}

variable "admin_password" {
  description = "Senha do usuário administrador."
  type        = string
  sensitive   = true
}

variable "ca_certificate" {
  description = "Certificado (PEM) da CA do servidor. Os Jobs conectam com sslmode=verify-full."
  type        = string
}

variable "app_ssl_mode" {
  description = "SSL Mode da connection string da API (Npgsql). Require criptografa sem exigir o certificado da CA dentro da imagem."
  type        = string
  default     = "Require"
}

variable "environments" {
  description = "Ambientes da API: namespace do Secret, database, role da aplicação e role da Lambda."
  type = map(object({
    namespace   = string
    database    = string
    app_role    = string
    lambda_role = string
  }))

  validation {
    condition = alltrue(flatten([
      for env in values(var.environments) : [
        for name in [env.database, env.app_role, env.lambda_role] : can(regex("^[a-z][a-z0-9_]{0,62}$", name))
      ]
    ]))
    error_message = "Database e roles devem usar somente letras minúsculas, dígitos e _ (identificadores PostgreSQL sem aspas)."
  }

  validation {
    condition     = alltrue([for key in keys(var.environments) : can(regex("^[a-z][a-z0-9]*$", key))])
    error_message = "As chaves dos ambientes devem usar somente letras minúsculas e dígitos."
  }
}

variable "image" {
  description = "Imagem com o psql usada pelos Jobs."
  type        = string
  default     = "postgres:17.11-alpine"
}

variable "auth_clients_migration" {
  description = "Migration do EF Core que precisa estar aplicada antes de criar a view auth_clients."
  type        = string
  default     = "20260629015755_UseSingleClienteDocumento"
}

variable "auth_clients_wait_minutes" {
  description = "Tempo máximo que o Job da view auth_clients espera as migrations da API."
  type        = number
  default     = 60
}

variable "api_secret_name" {
  description = "Nome do Secret da API em cada namespace."
  type        = string
  default     = "techchallenge-api-secrets"
}

variable "smtp_host" {
  description = "Host SMTP da API (Mailpit em cada namespace)."
  type        = string
  default     = "mailpit"
}

variable "smtp_port" {
  description = "Porta SMTP da API."
  type        = number
  default     = 1025
}
