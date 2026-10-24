variable "region" {
  description = "Região AWS (AWS Academy Learner Lab usa us-east-1)."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo dos recursos."
  type        = string
  default     = "techchallenge"
}

variable "state_bucket" {
  description = "Bucket dos states. Vazio usa techchallenge-tfstate-<account-id>, o mesmo do tech-challenge-k8s."
  type        = string
  default     = ""
}

variable "cluster_state_key" {
  description = "State do tech-challenge-k8s com a VPC, o security group do banco e o cluster."
  type        = string
  default     = "tech-challenge-k8s/cluster.tfstate"
}

variable "engine_version" {
  description = "Versão do PostgreSQL. Só a major: o RDS escolhe e atualiza a minor."
  type        = string
  default     = "17"
}

variable "instance_class" {
  description = "Classe da instância (o AWS Academy limita a micro e small)."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Armazenamento gp2 em GB."
  type        = number
  default     = 20
}

variable "master_username" {
  description = "Usuário master do RDS, usado só pelo bootstrap."
  type        = string
  default     = "techchallenge_admin"
}

variable "backup_retention_days" {
  description = "Dias de retenção dos backups automáticos."
  type        = number
  default     = 7
}

variable "create_iam_roles" {
  description = "Cria a role do Enhanced Monitoring e liga o monitoring. Com false (AWS Academy) nenhuma role é criada."
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "Intervalo do Enhanced Monitoring em segundos quando create_iam_roles = true."
  type        = number
  default     = 60
}

variable "performance_insights_enabled" {
  description = "Liga o Performance Insights (indisponível no AWS Academy)."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Impede o destroy da instância."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Não cria snapshot final no destroy (AWS Academy)."
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Namespace dos Jobs de bootstrap no EKS."
  type        = string
  default     = "techchallenge-database"
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
