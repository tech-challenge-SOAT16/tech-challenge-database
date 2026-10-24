# PostgreSQL 17 no kind no lugar do RDS: TLS obrigatório (como rds.force_ssl)
# e um administrador sem superusuário (como o master do RDS), para que o
# bootstrap rode aqui com as mesmas restrições da AWS.
locals {
  postgres_host = "postgres.${var.namespace}.svc.cluster.local"
}

resource "random_password" "superuser" {
  length  = 32
  special = false
}

resource "random_password" "admin" {
  length  = 32
  special = false
}

resource "tls_private_key" "postgres" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Autoassinado: o mesmo certificado serve de CA para o sslmode=verify-full.
resource "tls_self_signed_cert" "postgres" {
  private_key_pem       = tls_private_key.postgres.private_key_pem
  validity_period_hours = 24 * 365
  is_ca_certificate     = true

  subject {
    common_name = local.postgres_host
  }

  dns_names = [
    "postgres",
    "postgres.${var.namespace}",
    "postgres.${var.namespace}.svc",
    local.postgres_host,
  ]

  allowed_uses = ["cert_signing", "digital_signature", "key_encipherment", "server_auth"]
}

resource "kubernetes_secret_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.database.metadata[0].name
  }

  data = {
    POSTGRES_PASSWORD = random_password.superuser.result
    ADMIN_PASSWORD    = random_password.admin.result
  }
}

resource "kubernetes_secret_v1" "postgres_tls" {
  metadata {
    name      = "postgres-tls"
    namespace = kubernetes_namespace_v1.database.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.postgres.cert_pem
    "tls.key" = tls_private_key.postgres.private_key_pem
  }
}

resource "kubernetes_config_map_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.database.metadata[0].name
  }

  data = {
    # Conexões TCP só com TLS; o socket local fica para o entrypoint da imagem.
    "pg_hba.conf" = <<-EOT
      local   all all             trust
      hostssl all all 0.0.0.0/0   scram-sha-256
      hostssl all all ::/0        scram-sha-256
    EOT

    # Executado (source) pelo entrypoint da imagem só na criação do volume.
    "10-admin.sh" = <<-EOT
      psql -v ON_ERROR_STOP=1 --username postgres --no-psqlrc \
        -v admin="${var.admin_username}" -v password="$ADMIN_PASSWORD" <<'SQL'
      SELECT format('CREATE ROLE %I LOGIN CREATEDB CREATEROLE PASSWORD %L', :'admin', :'password') \gexec
      SQL
    EOT
  }
}

resource "kubernetes_service_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.database.metadata[0].name
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "postgres"
    }

    port {
      name        = "postgres"
      port        = 5432
      target_port = "postgres"
    }
  }
}

resource "kubernetes_stateful_set_v1" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.database.metadata[0].name
  }

  spec {
    service_name = kubernetes_service_v1.postgres.metadata[0].name
    replicas     = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "postgres"
        }

        # Recria o pod quando a configuração muda.
        annotations = {
          "checksum/config" = sha256(jsonencode(kubernetes_config_map_v1.postgres.data))
          "checksum/tls"    = sha256(tls_self_signed_cert.postgres.cert_pem)
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 70
          run_as_group    = 70
          fs_group        = 70

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "postgres"
          image = var.postgres_image
          args = [
            "-c", "ssl=on",
            "-c", "ssl_cert_file=/tls/tls.crt",
            "-c", "ssl_key_file=/tls/tls.key",
            "-c", "hba_file=/config/pg_hba.conf",
          ]

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.postgres.metadata[0].name
            }
          }

          port {
            name           = "postgres"
            container_port = 5432
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-q", "-U", "postgres"]
            }
            period_seconds = 5
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
            limits = {
              memory = "512Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false

            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }

          volume_mount {
            name       = "tls"
            mount_path = "/tls"
            read_only  = true
          }

          volume_mount {
            name       = "config"
            mount_path = "/config/pg_hba.conf"
            sub_path   = "pg_hba.conf"
            read_only  = true
          }

          volume_mount {
            name       = "config"
            mount_path = "/docker-entrypoint-initdb.d/10-admin.sh"
            sub_path   = "10-admin.sh"
            read_only  = true
          }

          volume_mount {
            name       = "run"
            mount_path = "/var/run/postgresql"
          }
        }

        volume {
          name = "tls"

          secret {
            secret_name = kubernetes_secret_v1.postgres_tls.metadata[0].name
            # Dono root e grupo postgres (fsGroup): o PostgreSQL aceita 0640.
            default_mode = "0640"
          }
        }

        volume {
          name = "config"

          config_map {
            name = kubernetes_config_map_v1.postgres.metadata[0].name
          }
        }

        volume {
          name = "run"
          empty_dir {}
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }

      spec {
        access_modes = ["ReadWriteOnce"]

        resources {
          requests = {
            storage = var.storage_size
          }
        }
      }
    }
  }

  wait_for_rollout = true
}
