resource "random_password" "approval_signing_key" {
  for_each = var.environments

  length  = 64
  special = false
}

# Assinatura dos tokens de funcionários emitidos pelo login da API (HS256).
# Clientes usam o JWT RS256 da Lambda, que não depende desta chave.
resource "random_password" "jwt_signing_key" {
  for_each = var.environments

  length  = 64
  special = false
}

resource "random_password" "integration_api_key" {
  for_each = var.environments

  length  = 40
  special = false
}

resource "random_password" "seed_admin" {
  for_each = var.environments

  length  = 24
  special = false
}

resource "random_password" "smtp_username" {
  for_each = var.environments

  length  = 16
  special = false
  upper   = false
}

resource "random_password" "smtp_password" {
  for_each = var.environments

  length  = 32
  special = false
}

locals {
  app_connection_strings = {
    for key, env in var.environments : key => join(";", [
      "Host=${var.host}",
      "Port=${var.port}",
      "Database=${env.database}",
      "Username=${env.app_role}",
      "Password=${random_password.app[key].result}",
      "SSL Mode=${var.app_ssl_mode}",
    ])
  }
}

# Secret consumido pela API via envFrom (contrato com tech-challenge-k8s e
# tech-challenge-application). Criado depois do bootstrap: quando a API sobe,
# a role e o database já existem.
resource "kubernetes_secret_v1" "api" {
  for_each = var.environments

  metadata {
    name      = var.api_secret_name
    namespace = each.value.namespace

    labels = {
      "app.kubernetes.io/part-of"    = "techchallenge"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    ConnectionStrings__DefaultConnection = local.app_connection_strings[each.key]
    ApprovalLinks__SigningKey            = random_password.approval_signing_key[each.key].result
    Jwt__LocalSigningKey                 = random_password.jwt_signing_key[each.key].result
    IntegracaoExterna__ApiKey            = random_password.integration_api_key[each.key].result
    Seed__AdminPassword                  = random_password.seed_admin[each.key].result
    Smtp__Host                           = var.smtp_host
    Smtp__Port                           = tostring(var.smtp_port)
    Smtp__Username                       = random_password.smtp_username[each.key].result
    Smtp__Password                       = random_password.smtp_password[each.key].result
  }

  depends_on = [kubernetes_job_v1.bootstrap]
}
