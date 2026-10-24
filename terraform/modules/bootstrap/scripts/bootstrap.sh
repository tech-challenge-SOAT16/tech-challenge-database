#!/bin/sh
# Job db-bootstrap: roles, databases, tabelas de estado da Lambda e grants de
# cada ambiente. Conexão pelas variáveis PG* (sslmode=verify-full).
# ENVIRONMENTS: lista "chave:database:app_role:lambda_role" separada por espaço;
# senhas em APP_PASSWORD_<CHAVE> e LAMBDA_PASSWORD_<CHAVE>.
set -eu

until pg_isready -q -d postgres; do
  echo "Aguardando $PGHOST:$PGPORT"
  sleep 5
done

for env in $ENVIRONMENTS; do
  IFS=: read -r key database app_role lambda_role <<EOF
$env
EOF
  upper=$(echo "$key" | tr '[:lower:]' '[:upper:]')
  app_password=$(printenv "APP_PASSWORD_$upper")
  lambda_password=$(printenv "LAMBDA_PASSWORD_$upper")

  echo "[$key] roles $app_role, $lambda_role e database $database"
  psql -X -q -v ON_ERROR_STOP=1 -d postgres \
    -v database="$database" -v app_role="$app_role" -v app_password="$app_password" \
    -v lambda_role="$lambda_role" -v lambda_password="$lambda_password" \
    -f /bootstrap/001-roles-database.sql

  echo "[$key] tabelas de estado da Lambda"
  psql -X -q -v ON_ERROR_STOP=1 -d "$database" \
    -v app_role="$app_role" -v lambda_role="$lambda_role" \
    -f /bootstrap/003-auth-grants.sql
done

echo "Bootstrap concluído"
