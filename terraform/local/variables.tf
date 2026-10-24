variable "kubeconfig_path" {
  description = "Kubeconfig do cluster kind criado por tech-challenge-k8s/terraform/local (caminho relativo a este diretório)."
  type        = string
  default     = "../../../tech-challenge-k8s/terraform/local/kubeconfig"
}

variable "namespace" {
  description = "Namespace do PostgreSQL local e dos Jobs de bootstrap."
  type        = string
  default     = "techchallenge-database"
}

variable "postgres_image" {
  description = "Imagem do PostgreSQL (mesma major do RDS)."
  type        = string
  default     = "postgres:17.11-alpine"
}

variable "storage_size" {
  description = "Volume do PostgreSQL local."
  type        = string
  default     = "1Gi"
}

variable "admin_username" {
  description = "Usuário administrador sem superusuário, equivalente ao master do RDS."
  type        = string
  default     = "techchallenge_admin"
}

variable "environments" {
  description = "Ambientes da API: namespace do Secret, database, role da aplicação e role da Lambda."
  type = map(object({
    namespace   = string
    database    = string
    app_role    = string
    lambda_role = string
  }))
  default = {
    production = {
      namespace   = "techchallenge"
      database    = "techchallenge"
      app_role    = "techchallenge_app"
      lambda_role = "lambda_auth"
    }
    homolog = {
      namespace   = "techchallenge-homolog"
      database    = "techchallenge_homolog"
      app_role    = "techchallenge_homolog_app"
      lambda_role = "lambda_auth_homolog"
    }
  }
}
