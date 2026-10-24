-- Roles e database de um ambiente. Roda no database postgres com o usuário
-- master, que no RDS não é superusuário (CREATEROLE, CREATEDB e rds_superuser).
-- Idempotente: pode rodar de novo a qualquer momento e ressincroniza as senhas.
-- Variáveis psql: database, app_role, app_password, lambda_role, lambda_password.

SELECT format('CREATE ROLE %I LOGIN', :'app_role')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'app_role') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'app_role', :'app_password') \gexec

SELECT format('CREATE ROLE %I LOGIN', :'lambda_role')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'lambda_role') \gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'lambda_role', :'lambda_password') \gexec

-- Desde o PostgreSQL 16, criar um database para outro dono e agir em nome
-- dele (SET ROLE) exige ser membro da role. O master recebe só SET, sem
-- herdar os privilégios da aplicação.
SELECT format('GRANT %I TO %I WITH INHERIT FALSE, SET TRUE', :'app_role', current_user)
WHERE NOT pg_has_role(current_user, :'app_role', 'SET') \gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'database', :'app_role')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'database') \gexec

-- Grants feitos como dona do database. Sem CONNECT para PUBLIC, a aplicação e
-- a Lambda de um ambiente não acessam o database do outro.
SELECT current_user AS admin_role \gset
SET ROLE :"app_role";
REVOKE ALL ON DATABASE :"database" FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE :"database" TO :"admin_role";
GRANT CONNECT ON DATABASE :"database" TO :"lambda_role";
RESET ROLE;
