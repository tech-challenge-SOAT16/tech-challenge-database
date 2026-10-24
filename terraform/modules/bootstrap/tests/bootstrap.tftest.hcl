# terraform test com providers simulados: não acessa o cluster.
mock_provider "kubernetes" {}

mock_provider "random" {
  mock_resource "random_password" {
    defaults = {
      result = "senha-simulada"
    }
  }
}

variables {
  namespace      = "techchallenge-database"
  host           = "db.example.internal"
  admin_username = "techchallenge_admin"
  admin_password = "admin-simulado"
  ca_certificate = "-----BEGIN CERTIFICATE-----"
  environments = {
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

run "secrets_da_api" {
  command = apply

  assert {
    condition = toset(keys(kubernetes_secret_v1.api["production"].data)) == toset([
      "ConnectionStrings__DefaultConnection",
      "ApprovalLinks__SigningKey",
      "Jwt__LocalSigningKey",
      "IntegracaoExterna__ApiKey",
      "Seed__AdminPassword",
      "Smtp__Host",
      "Smtp__Port",
      "Smtp__Username",
      "Smtp__Password",
    ])
    error_message = "O Secret da API deve ter exatamente as chaves do contrato."
  }

  assert {
    condition     = kubernetes_secret_v1.api["production"].data["ConnectionStrings__DefaultConnection"] == "Host=db.example.internal;Port=5432;Database=techchallenge;Username=techchallenge_app;Password=senha-simulada;SSL Mode=Require"
    error_message = "Connection string de produção inesperada."
  }

  assert {
    condition     = kubernetes_secret_v1.api["homolog"].metadata[0].namespace == "techchallenge-homolog" && strcontains(kubernetes_secret_v1.api["homolog"].data["ConnectionStrings__DefaultConnection"], "Database=techchallenge_homolog;Username=techchallenge_homolog_app;")
    error_message = "Homologação deve usar o próprio database e a própria role."
  }

  assert {
    condition     = kubernetes_secret_v1.api["production"].data["Smtp__Host"] == "mailpit" && kubernetes_secret_v1.api["production"].data["Smtp__Port"] == "1025"
    error_message = "SMTP deve apontar para o Mailpit do namespace."
  }

  assert {
    condition     = random_password.jwt_signing_key["production"].length >= 32
    error_message = "Jwt__LocalSigningKey precisa de pelo menos 32 caracteres."
  }

  assert {
    condition     = random_password.approval_signing_key["production"].length >= 32
    error_message = "ApprovalLinks__SigningKey precisa de pelo menos 32 caracteres."
  }

  assert {
    condition     = kubernetes_job_v1.bootstrap.wait_for_completion && !kubernetes_job_v1.auth_clients.wait_for_completion
    error_message = "O apply espera só o bootstrap; a view aguarda as migrations da API."
  }

  assert {
    condition     = one([for e in kubernetes_job_v1.bootstrap.spec[0].template[0].spec[0].container[0].env : e.value if e.name == "PGSSLMODE"]) == "verify-full"
    error_message = "Os Jobs devem validar o certificado do servidor."
  }

  assert {
    condition     = one([for e in kubernetes_job_v1.bootstrap.spec[0].template[0].spec[0].container[0].env : e.value if e.name == "ENVIRONMENTS"]) == "homolog:techchallenge_homolog:techchallenge_homolog_app:lambda_auth_homolog production:techchallenge:techchallenge_app:lambda_auth"
    error_message = "Lista de ambientes passada aos scripts inesperada."
  }
}

run "nome_invalido" {
  command = plan

  variables {
    environments = {
      production = {
        namespace   = "techchallenge"
        database    = "tech-challenge"
        app_role    = "techchallenge_app"
        lambda_role = "lambda_auth"
      }
    }
  }

  expect_failures = [var.environments]
}
