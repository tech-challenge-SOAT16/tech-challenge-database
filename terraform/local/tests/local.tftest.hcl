# terraform test com providers simulados: não acessa o cluster kind.
mock_provider "kubernetes" {}

mock_provider "random" {
  mock_resource "random_password" {
    defaults = {
      result = "senha-simulada"
    }
  }
}

mock_provider "tls" {}

run "kind" {
  command = apply

  assert {
    condition     = kubernetes_stateful_set_v1.postgres.spec[0].template[0].spec[0].container[0].image == "postgres:17.11-alpine"
    error_message = "O PostgreSQL local deve usar a mesma major do RDS (17)."
  }

  assert {
    condition     = contains(kubernetes_stateful_set_v1.postgres.spec[0].template[0].spec[0].container[0].args, "ssl=on")
    error_message = "O PostgreSQL local deve aceitar só TLS, como o RDS."
  }

  assert {
    condition     = module.bootstrap.api_secret_names == { homolog = "techchallenge-homolog/techchallenge-api-secrets", production = "techchallenge/techchallenge-api-secrets" }
    error_message = "O Secret da API deve existir nos dois namespaces."
  }

  assert {
    condition     = module.bootstrap.environments["homolog"].app_role == "techchallenge_homolog_app"
    error_message = "Cada ambiente deve ter a própria role da aplicação."
  }
}
