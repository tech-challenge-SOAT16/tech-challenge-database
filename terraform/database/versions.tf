terraform {
  required_version = ">= 1.11"

  # Bucket informado no init: terraform init -backend-config="bucket=<bucket>"
  backend "s3" {
    key          = "tech-challenge-database/database.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}
