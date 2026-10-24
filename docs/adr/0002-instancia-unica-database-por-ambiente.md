# ADR 0002 — Uma instância RDS com um database por ambiente

- Status: aceita
- Data: 2026-10-23

## Contexto

Há dois ambientes da API no mesmo cluster EKS: `techchallenge` (produção) e
`techchallenge-homolog` (homologação), conforme a ADR 0002 do
`tech-challenge-k8s`. Cada um precisa de dados isolados. Uma instância RDS por
ambiente dobraria o custo e o tempo de criação (cerca de 10 minutos cada) no
orçamento do Learner Lab.

## Decisão

- Uma instância RDS e um state Terraform.
- Um database por ambiente, cada um com a própria role da aplicação (dona do
  database) e a própria role da Lambda:

  | Ambiente | Namespace | Database | Role da API | Role da Lambda |
  | --- | --- | --- | --- | --- |
  | produção | `techchallenge` | `techchallenge` | `techchallenge_app` | `lambda_auth` |
  | homologação | `techchallenge-homolog` | `techchallenge_homolog` | `techchallenge_homolog_app` | `lambda_auth_homolog` |

- `CONNECT` revogado de `PUBLIC` em cada database: uma role de homologação não
  conecta em produção e vice-versa. Senhas diferentes por role.
- Um Secret `techchallenge-api-secrets` por namespace e um secret da Lambda por
  ambiente no Secrets Manager, cada um com as credenciais do próprio database.
- A pipeline aplica só a partir da `main`; homologação e produção mudam juntas
  porque a infraestrutura é compartilhada. A lista de ambientes é a variável
  `environments`.

## Consequências

- Custo de uma instância; o isolamento é lógico (database e roles), não de
  instância.
- Carga de homologação (testes, demos) disputa CPU, memória e conexões com
  produção. Na `db.t3.micro` o `max_connections` padrão fica perto de 80 para
  as réplicas dos dois ambientes somadas; suficiente para a demo, mas é o
  primeiro limite a observar se o HPA escalar.
- Manutenção, upgrade de versão e restore valem para os dois ambientes ao
  mesmo tempo. Restaurar só um ambiente exige restore para outra instância e
  cópia do database (`pg_dump`/`pg_restore`).
