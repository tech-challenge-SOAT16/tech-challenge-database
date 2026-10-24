-- Tabelas de estado da Lambda (002-auth-state.sql, copiado do repositório da
-- Lambda) e grants da role dela. Roda dentro do database do ambiente, como
-- dona do database, para que as tabelas pertençam à role da aplicação.
-- Variáveis psql: app_role, lambda_role.

SET ROLE :"app_role";

\ir 002-auth-state.sql

GRANT USAGE ON SCHEMA public TO :"lambda_role";
GRANT SELECT, INSERT, UPDATE, DELETE ON auth_challenges, auth_rate_limits TO :"lambda_role";

RESET ROLE;
