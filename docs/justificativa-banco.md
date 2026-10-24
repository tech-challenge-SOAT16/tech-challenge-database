# Justificativa: PostgreSQL no Amazon RDS

## Requisitos do domínio

A API da oficina controla ordens de serviço (OS) do recebimento à entrega:
cliente, veículo, orçamento com serviços e peças, aprovação externa, baixa de
estoque e notificações de mudança de status. Os dados têm estas
características:

- **Relacionais e com integridade forte**: uma OS referencia cliente, veículo e
  funcionário; itens referenciam catálogo; estoque é 1:1 com produto. Exclusões
  precisam ser bloqueadas (Restrict) quando há histórico, e itens precisam
  sumir junto com a OS (Cascade). Essas regras ficam no banco, por FKs, e não
  só na aplicação.
- **Transacionais**: finalizar uma OS muda o status, baixa o estoque de várias
  peças e grava o evento no outbox de notificações. Ou tudo é gravado ou nada
  (ACID), com concorrência otimista em `Estoque` e no outbox.
- **Unicidade e idempotência**: placa, CPF/CNPJ, código de acompanhamento e
  `EventoId` das decisões externas são únicos; o callback de aprovação pode
  chegar repetido e não pode duplicar a decisão.
- **Consultas por relacionamento**: listagem e acompanhamento de OS juntam OS,
  cliente, veículo e itens; métricas de tempo por status agregam por período.
- **Volume pequeno e previsível**: uma oficina gera milhares de OS por ano, não
  milhões por dia. Escala vertical simples é suficiente.

## Por que relacional

Um banco documental (DynamoDB, DocumentDB) obrigaria a duplicar cliente e
veículo dentro da OS ou a fazer as junções na aplicação, e a garantir FKs,
unicidades compostas e transações entre agregados no código. Um banco
chave-valor não atende as listagens e agregações. O modelo já existe como
schema relacional normalizado (ver [modelo de dados](modelo-de-dados.md)) e foi
validado nas fases anteriores.

## Por que PostgreSQL

| Critério | PostgreSQL | MySQL/MariaDB | SQL Server |
| --- | --- | --- | --- |
| Compatibilidade com o código atual | Provider Npgsql do EF Core já usado; migrations geradas para PostgreSQL | Exigiria regerar todas as migrations | Exigiria regerar migrations; licença |
| Tipos usados | `uuid`, `timestamptz`, `numeric`, índices parciais e por expressão (CPF normalizado da view `auth_clients`) | Sem índice parcial; UUID como texto/binário | Disponível, mas com custo de licença |
| Lambda de autenticação | Já escrita com Npgsql e `ON CONFLICT` | Reescrever as queries | Reescrever as queries |
| Custo | Open source; disponível no RDS free tier e no Learner Lab | Equivalente | Licença incluída no preço da instância |

Versão 17: major com suporte padrão no RDS e compatível com as `db.t3.micro`
do Academy. As migrations do EF Core não usam recurso específico de versão; o
ambiente local (kind) deste repositório roda a mesma major (`postgres:17`).

## Por que gerenciado (RDS)

O Tech Challenge pede banco gerenciado. Comparado a rodar PostgreSQL num
StatefulSet do EKS:

- **Backups e recuperação**: snapshots automáticos com retenção de 7 dias e
  restore *point-in-time*, sem operar ferramenta de backup.
- **Ciclo de vida independente do cluster**: no Academy os nós do EKS param ao
  fim de cada sessão e o cluster pode ser destruído para poupar crédito; o
  RDS mantém os dados.
- **Patches e versões menores**: `auto_minor_version_upgrade` na janela de
  manutenção.
- **Segurança**: subnets privadas, security group que só aceita o cluster e a
  Lambda, criptografia em repouso (KMS) e TLS obrigatório (`rds.force_ssl`).
- **Acesso da Lambda**: a Lambda roda fora do cluster; um endpoint gerenciado
  na VPC é o ponto comum aos dois.

Aurora PostgreSQL foi descartado: classe mínima maior que `db.t3.micro`,
custo por I/O e recursos (réplicas, Serverless v2) além da necessidade do
projeto.

## Configuração escolhida e limites do AWS Academy

| Item | Valor | Motivo |
| --- | --- | --- |
| Engine | PostgreSQL 17 | Ver acima |
| Classe | `db.t3.micro` | Academy limita a micro/small; carga da demo é baixa |
| Storage | 20 GB gp2, criptografado | gp3 e io1 não são permitidos no Academy |
| Multi-AZ | desligado | Não permitido no Academy; documentado como evolução para produção real |
| Backups | 7 dias | Recuperação de falhas da demo sem custo relevante |
| Enhanced Monitoring / Performance Insights | desligados | Exigem role IAM própria (Academy só tem a `LabRole`); ligáveis com `create_iam_roles = true` |
| Rede | Subnets privadas da VPC do `tech-challenge-k8s`, sem IP público | Acesso só pelo cluster e pela Lambda |
| TLS | `rds.force_ssl = 1` | Conexões sem TLS são recusadas |
| Senhas | Aleatórias (`random_password`), master no Secrets Manager | Nenhum segredo versionado |
