# terraform test com providers simulados: não acessa AWS nem Kubernetes.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_eks_cluster" {
    defaults = {
      endpoint = "https://example.eks.amazonaws.com"
      certificate_authority = [{
        data = "Y2E="
      }]
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      address  = "techchallenge-postgres.abc123.us-east-1.rds.amazonaws.com"
      endpoint = "techchallenge-postgres.abc123.us-east-1.rds.amazonaws.com:5432"
      port     = 5432
      username = "techchallenge_admin"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock"
    }
  }
}

mock_provider "kubernetes" {}

mock_provider "random" {
  mock_resource "random_password" {
    defaults = {
      result = "senha-simulada"
    }
  }
}

# Outputs do tech-challenge-k8s (terraform/cluster).
override_data {
  target = data.terraform_remote_state.cluster
  values = {
    outputs = {
      cluster_name               = "techchallenge-eks"
      vpc_id                     = "vpc-0123456789abcdef0"
      private_subnet_ids         = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
      database_security_group_id = "sg-0123456789abcdef0"
    }
  }
}

run "padrao_academy" {
  command = apply

  assert {
    condition     = data.terraform_remote_state.cluster.config.bucket == "techchallenge-tfstate-123456789012" && data.terraform_remote_state.cluster.config.key == "tech-challenge-k8s/cluster.tfstate"
    error_message = "O remote state deve ler tech-challenge-k8s/cluster.tfstate no bucket padrão da conta."
  }

  assert {
    condition     = aws_db_instance.this.engine == "postgres" && aws_db_instance.this.engine_version == "17" && aws_db_parameter_group.this.family == "postgres17"
    error_message = "O banco deve ser PostgreSQL 17."
  }

  assert {
    condition     = aws_db_instance.this.instance_class == "db.t3.micro" && aws_db_instance.this.storage_type == "gp2" && aws_db_instance.this.allocated_storage == 20
    error_message = "Instância esperada: db.t3.micro com 20 GB gp2 (limites do AWS Academy)."
  }

  assert {
    condition     = !aws_db_instance.this.multi_az && !aws_db_instance.this.publicly_accessible && aws_db_instance.this.storage_encrypted
    error_message = "RDS deve ser privado, criptografado e sem Multi-AZ."
  }

  assert {
    condition     = aws_db_instance.this.monitoring_interval == 0 && !aws_db_instance.this.performance_insights_enabled && length(aws_iam_role.monitoring) == 0
    error_message = "No AWS Academy não há Enhanced Monitoring, Performance Insights nem role IAM."
  }

  assert {
    condition     = aws_db_instance.this.backup_retention_period == 7
    error_message = "Backups automáticos devem ser retidos por 7 dias."
  }

  assert {
    condition     = one([for p in aws_db_parameter_group.this.parameter : p.value if p.name == "rds.force_ssl"]) == "1"
    error_message = "O parameter group deve exigir TLS (rds.force_ssl = 1)."
  }

  assert {
    condition     = toset(aws_db_subnet_group.this.subnet_ids) == toset(["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]) && aws_db_instance.this.vpc_security_group_ids == toset(["sg-0123456789abcdef0"])
    error_message = "O RDS deve usar as subnets privadas e o security group do tech-challenge-k8s."
  }

  assert {
    condition     = jsondecode(aws_secretsmanager_secret_version.master.secret_string).password == "senha-simulada"
    error_message = "A senha master deve ficar no Secrets Manager."
  }

  assert {
    condition     = keys(aws_secretsmanager_secret.lambda) == ["homolog", "production"] && aws_secretsmanager_secret.lambda["production"].name == "techchallenge/lambda-auth/production"
    error_message = "Deve existir um secret da Lambda por ambiente."
  }

  assert {
    condition     = jsondecode(aws_secretsmanager_secret_version.lambda["production"].secret_string).database_connection == "Host=techchallenge-postgres.abc123.us-east-1.rds.amazonaws.com;Port=5432;Database=techchallenge;Username=lambda_auth;Password=senha-simulada;SSL Mode=VerifyFull;Root Certificate=/var/task/certs/rds-global-bundle.crt"
    error_message = "database_connection da Lambda deve apontar para o database do ambiente com SSL Mode=VerifyFull."
  }

  assert {
    condition     = jsondecode(aws_secretsmanager_secret_version.lambda["homolog"].secret_string).database_connection == "Host=techchallenge-postgres.abc123.us-east-1.rds.amazonaws.com;Port=5432;Database=techchallenge_homolog;Username=lambda_auth_homolog;Password=senha-simulada;SSL Mode=VerifyFull;Root Certificate=/var/task/certs/rds-global-bundle.crt"
    error_message = "Homologação deve usar o próprio database e a própria role da Lambda."
  }

  assert {
    condition     = output.api_secrets == { homolog = "techchallenge-homolog/techchallenge-api-secrets", production = "techchallenge/techchallenge-api-secrets" }
    error_message = "O Secret techchallenge-api-secrets deve existir em techchallenge e techchallenge-homolog."
  }

  assert {
    condition     = module.bootstrap.environments["production"].database == "techchallenge" && module.bootstrap.environments["homolog"].database == "techchallenge_homolog"
    error_message = "Databases esperados: techchallenge e techchallenge_homolog."
  }
}

run "fora_do_academy" {
  command = apply

  variables {
    create_iam_roles = true
  }

  assert {
    condition     = length(aws_iam_role.monitoring) == 1 && aws_db_instance.this.monitoring_interval == 60 && aws_db_instance.this.monitoring_role_arn == aws_iam_role.monitoring[0].arn
    error_message = "create_iam_roles = true deve criar a role e ligar o Enhanced Monitoring."
  }
}
