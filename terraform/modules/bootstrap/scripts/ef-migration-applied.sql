-- Imprime t quando a migration informada já foi aplicada pela API, f caso
-- contrário. O histórico pertence à role da aplicação.
-- Variáveis psql: app_role, migration.

SET ROLE :"app_role";

SELECT to_regclass('public."__EFMigrationsHistory"') IS NOT NULL AS has_history \gset
\if :has_history
SELECT EXISTS (SELECT FROM "__EFMigrationsHistory" WHERE "MigrationId" = :'migration') AS applied \gset
\else
\set applied f
\endif
\echo :applied
