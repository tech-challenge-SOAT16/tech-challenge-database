data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# Rede e cluster criados pelo tech-challenge-k8s (terraform/cluster).
data "terraform_remote_state" "cluster" {
  backend = "s3"

  config = {
    bucket = local.state_bucket
    key    = var.cluster_state_key
    region = var.region
  }
}

locals {
  state_bucket = coalesce(var.state_bucket, "techchallenge-tfstate-${data.aws_caller_identity.current.account_id}")
  cluster      = data.terraform_remote_state.cluster.outputs
}
