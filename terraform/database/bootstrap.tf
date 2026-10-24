# Bootstrap dentro da VPC: o RDS fica nas subnets privadas e só aceita
# conexões do security group do cluster, então os Jobs rodam no próprio EKS.
resource "kubernetes_namespace_v1" "database" {
  metadata {
    name = var.namespace
  }
}

module "bootstrap" {
  source = "../modules/bootstrap"

  namespace      = kubernetes_namespace_v1.database.metadata[0].name
  host           = aws_db_instance.this.address
  port           = aws_db_instance.this.port
  admin_username = aws_db_instance.this.username
  admin_password = random_password.master.result
  ca_certificate = file("${path.module}/certs/rds-global-bundle.pem")
  environments   = var.environments
}
