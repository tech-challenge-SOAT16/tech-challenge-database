# ADR 0001 — PostgreSQL gerenciado no Amazon RDS

- Status: aceita
- Data: 2026-10-23

## Contexto

A Fase 3 exige um banco gerenciado provisionado por Terraform. A API .NET já
usa PostgreSQL (EF Core + Npgsql, migrations geradas para ele) e a Lambda de
autenticação também foi escrita com Npgsql. O ambiente é o AWS Academy
Learner Lab: sem criação de roles IAM, RDS limitado a classes micro/small, gp2,
sem Multi-AZ e sem Enhanced Monitoring.

## Decisão

- Amazon RDS for PostgreSQL 17, `db.t3.micro`, 20 GB gp2 criptografado,
  Single-AZ, backups de 7 dias, sem Performance Insights nem Enhanced
  Monitoring (`create_iam_roles = false`). Fora do Academy, `create_iam_roles
  = true` cria a role e liga o Enhanced Monitoring.
- Instância nas subnets privadas e com o security group `database` criados pelo
  `tech-challenge-k8s` (lidos do state remoto `tech-challenge-k8s/cluster.tfstate`),
  que aceita 5432 só do cluster EKS e da Lambda.
- TLS obrigatório (`rds.force_ssl = 1`). A API conecta com `SSL Mode=Require`
  (a imagem não traz a CA da AWS); a Lambda e os Jobs de bootstrap validam o
  certificado (`VerifyFull`/`verify-full`) com o bundle global do RDS.
- Senha master aleatória no Secrets Manager. Secrets com
  `recovery_window_in_days = 0`, porque o Academy recria o ambiente com
  frequência.

Justificativa completa em [justificativa-banco.md](../justificativa-banco.md).

## Consequências

- Mesma engine em todos os ambientes (Docker Compose, kind e RDS) e mesma major
  no kind e no RDS; nenhuma migration precisa ser regerada.
- Single-AZ: uma falha da AZ derruba o banco até a recuperação. Aceitável na
  demo; em produção real, Multi-AZ e classe maior.
- `deletion_protection = false` e `skip_final_snapshot = true` por padrão para
  que o destroy da pipeline funcione no Academy; em produção real os dois
  devem ser invertidos.
