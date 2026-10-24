# ADR 0003 — Bootstrap do banco por Jobs no cluster EKS

- Status: aceita
- Data: 2026-10-23

## Contexto

Depois de criar a instância é preciso criar roles, databases, as tabelas de
estado da Lambda, a view `auth_clients` e os grants. O RDS está em subnets
privadas e o security group só aceita o cluster EKS e a Lambda, então o runner
do GitHub Actions não alcança o banco. As alternativas eram:

- provider `postgresql` do Terraform: exige conexão direta do runner (IP
  público ou bastion), o que o Academy e a regra de rede não permitem;
- uma Lambda ou instância EC2 de bootstrap: mais um artefato para empacotar e
  mais uma role IAM (indisponível no Academy);
- migrations da API: as tabelas e a view da Lambda não são do domínio da API, e
  as roles precisam existir antes de a API conectar.

## Decisão

- O Terraform cria, no namespace `techchallenge-database` do EKS, dois Jobs com
  a imagem `postgres:17` que rodam scripts SQL idempotentes com o usuário
  master. O provider `kubernetes` autentica com `aws eks get-token`, com as
  mesmas credenciais da pipeline.
- `db-bootstrap` (o apply espera terminar): roles com senha aleatória
  (ressincronizada a cada execução), databases, `002-auth-state.sql` da Lambda e
  grants. Roda de novo quando um script, a CA ou uma senha muda
  (`replace_triggered_by`).
- `db-auth-clients` (o apply não espera): aguarda a migration do EF Core que
  cria o formato atual de `Cliente` aparecer em `__EFMigrationsHistory` de cada
  database e só então cria o índice do CPF normalizado e a view
  `auth_clients`. Prazo de 60 minutos.
- O Secret `techchallenge-api-secrets` é criado depois do `db-bootstrap`: a API
  só sobe quando a role e o database dela já existem.
- Os Jobs conectam com `sslmode=verify-full` usando o bundle de CAs do RDS
  versionado no repositório.
- O mesmo módulo (`terraform/modules/bootstrap`) roda no kind contra um
  PostgreSQL local com um administrador sem superusuário, para reproduzir as
  restrições do master do RDS.

## Consequências

- Nenhum acesso de rede novo ao banco; o bootstrap usa o caminho que a API já
  usa.
- O banco depende do cluster para ser configurado: a ordem é
  `tech-challenge-k8s` → `tech-challenge-database` → deploy da API. Para
  destruir, é o inverso (o destroy deste repositório remove os Secrets do
  cluster).
- A senha master fica num Secret do Kubernetes no namespace
  `techchallenge-database`, além do Secrets Manager.
- A view depende das migrations da API. Se a API demorar mais que o prazo, o Job
  precisa ser recriado (`terraform apply -replace=...`); uma migration que
  altere as colunas usadas pela view precisa removê-la antes.
