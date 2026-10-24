# Usa o cluster kind de tech-challenge-k8s/terraform/local, que já cria os
# namespaces techchallenge e techchallenge-homolog.
provider "kubernetes" {
  config_path = var.kubeconfig_path
}

resource "kubernetes_namespace_v1" "database" {
  metadata {
    name = var.namespace
  }
}

module "bootstrap" {
  source = "../modules/bootstrap"

  namespace      = kubernetes_namespace_v1.database.metadata[0].name
  host           = local.postgres_host
  admin_username = var.admin_username
  admin_password = random_password.admin.result
  ca_certificate = tls_self_signed_cert.postgres.cert_pem
  environments   = var.environments

  depends_on = [kubernetes_stateful_set_v1.postgres]
}
