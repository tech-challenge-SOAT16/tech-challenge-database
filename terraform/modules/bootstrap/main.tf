locals {
  scripts = {
    for file in fileset("${path.module}/scripts", "*") : file => file("${path.module}/scripts/${file}")
  }

  # "chave:database:app_role:lambda_role" lido pelos scripts.
  environments = join(" ", [
    for key, env in var.environments : "${key}:${env.database}:${env.app_role}:${env.lambda_role}"
  ])

  connection_env = {
    PGHOST            = var.host
    PGPORT            = tostring(var.port)
    PGUSER            = var.admin_username
    PGSSLMODE         = "verify-full"
    PGSSLROOTCERT     = "/bootstrap-ca/ca.pem"
    PGAPPNAME         = "db-bootstrap"
    PGCONNECT_TIMEOUT = "10"
    PGOPTIONS         = "-c client_min_messages=warning"
    ENVIRONMENTS      = local.environments
  }
}

resource "random_password" "app" {
  for_each = var.environments

  length  = 32
  special = false
}

resource "random_password" "lambda" {
  for_each = var.environments

  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "bootstrap" {
  metadata {
    name      = "db-bootstrap"
    namespace = var.namespace
  }

  data = merge(
    { PGPASSWORD = var.admin_password },
    { for key, env in var.environments : "APP_PASSWORD_${upper(key)}" => random_password.app[key].result },
    { for key, env in var.environments : "LAMBDA_PASSWORD_${upper(key)}" => random_password.lambda[key].result },
  )
}

resource "kubernetes_config_map_v1" "scripts" {
  metadata {
    name      = "db-bootstrap-scripts"
    namespace = var.namespace
  }

  data = local.scripts
}

resource "kubernetes_config_map_v1" "ca" {
  metadata {
    name      = "db-bootstrap-ca"
    namespace = var.namespace
  }

  data = {
    "ca.pem" = var.ca_certificate
  }
}

# Roles, databases, tabelas de estado da Lambda e grants. O apply espera o Job
# terminar; ele roda de novo quando os scripts, a CA ou as senhas mudam.
resource "kubernetes_job_v1" "bootstrap" {
  metadata {
    name      = "db-bootstrap"
    namespace = var.namespace
  }

  spec {
    backoff_limit = 4

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "db-bootstrap"
        }
      }

      spec {
        restart_policy                  = "Never"
        automount_service_account_token = false

        security_context {
          run_as_non_root = true
          run_as_user     = 70
          run_as_group    = 70

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name    = "psql"
          image   = var.image
          command = ["sh", "/bootstrap/bootstrap.sh"]

          dynamic "env" {
            for_each = local.connection_env

            content {
              name  = env.key
              value = env.value
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.bootstrap.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "32Mi"
            }
            limits = {
              memory = "64Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true

            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "scripts"
            mount_path = "/bootstrap"
          }

          volume_mount {
            name       = "ca"
            mount_path = "/bootstrap-ca"
          }
        }

        volume {
          name = "scripts"

          config_map {
            name = kubernetes_config_map_v1.scripts.metadata[0].name
          }
        }

        volume {
          name = "ca"

          config_map {
            name = kubernetes_config_map_v1.ca.metadata[0].name
          }
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = "10m"
    update = "10m"
  }

  lifecycle {
    replace_triggered_by = [
      kubernetes_secret_v1.bootstrap,
      kubernetes_config_map_v1.scripts,
      kubernetes_config_map_v1.ca,
    ]
  }
}

# View auth_clients: depende da tabela "Cliente" criada pelas migrations da
# API, que só roda depois deste módulo criar o Secret dela. O apply não espera
# este Job; ele aguarda as migrations até auth_clients_wait_minutes.
resource "kubernetes_job_v1" "auth_clients" {
  metadata {
    name      = "db-auth-clients"
    namespace = var.namespace
  }

  spec {
    backoff_limit           = 4
    active_deadline_seconds = var.auth_clients_wait_minutes * 60

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "db-auth-clients"
        }
      }

      spec {
        restart_policy                  = "Never"
        automount_service_account_token = false

        security_context {
          run_as_non_root = true
          run_as_user     = 70
          run_as_group    = 70

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name    = "psql"
          image   = var.image
          command = ["sh", "/bootstrap/auth-clients.sh"]

          dynamic "env" {
            for_each = merge(local.connection_env, {
              PGAPPNAME              = "db-auth-clients"
              AUTH_CLIENTS_MIGRATION = var.auth_clients_migration
            })

            content {
              name  = env.key
              value = env.value
            }
          }

          env {
            name = "PGPASSWORD"

            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.bootstrap.metadata[0].name
                key  = "PGPASSWORD"
              }
            }
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "32Mi"
            }
            limits = {
              memory = "64Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true

            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "scripts"
            mount_path = "/bootstrap"
          }

          volume_mount {
            name       = "ca"
            mount_path = "/bootstrap-ca"
          }
        }

        volume {
          name = "scripts"

          config_map {
            name = kubernetes_config_map_v1.scripts.metadata[0].name
          }
        }

        volume {
          name = "ca"

          config_map {
            name = kubernetes_config_map_v1.ca.metadata[0].name
          }
        }
      }
    }
  }

  wait_for_completion = false

  lifecycle {
    replace_triggered_by = [
      kubernetes_config_map_v1.scripts,
      kubernetes_config_map_v1.ca,
    ]
  }

  depends_on = [kubernetes_job_v1.bootstrap]
}
