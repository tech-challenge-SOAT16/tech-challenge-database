#!/bin/sh
# Job db-auth-clients: espera a API aplicar as migrations do EF Core em cada
# database e cria a view auth_clients. O prazo do Job (activeDeadlineSeconds)
# limita a espera.
# ENVIRONMENTS: lista "chave:database:app_role:lambda_role" separada por espaço.
set -eu

for env in $ENVIRONMENTS; do
  IFS=: read -r key database app_role lambda_role <<EOF
$env
EOF

  until [ "$(psql -X -q -At -v ON_ERROR_STOP=1 -d "$database" \
    -v app_role="$app_role" -v migration="$AUTH_CLIENTS_MIGRATION" \
    -f /bootstrap/ef-migration-applied.sql)" = "t" ]; do
    echo "[$key] aguardando a migration $AUTH_CLIENTS_MIGRATION da API em $database"
    sleep 15
  done

  echo "[$key] view auth_clients em $database"
  psql -X -q -v ON_ERROR_STOP=1 -d "$database" \
    -v app_role="$app_role" -v lambda_role="$lambda_role" \
    -f /bootstrap/004-auth-clients.sql
done

echo "View auth_clients criada em todos os ambientes"
