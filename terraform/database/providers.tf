provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project    = var.project_name
      Repository = "tech-challenge-database"
      ManagedBy  = "terraform"
    }
  }
}

data "aws_eks_cluster" "this" {
  name = local.cluster.cluster_name
}

# Token gerado a cada execução pelo AWS CLI (mesmas credenciais da sessão).
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster.cluster_name, "--region", var.region]
  }
}
