-- View auth_clients consultada pela Lambda (SELECT id, active, email FROM
-- auth_clients WHERE cpf = $1). Depende da tabela "Cliente" criada pelas
-- migrations do EF Core da API, então só roda depois delas.
-- Variáveis psql: app_role, lambda_role.

SET ROLE :"app_role";

-- Índice para a busca por CPF normalizado: mesma expressão e mesmo filtro da
-- view, único como pede o contrato da Lambda.
CREATE UNIQUE INDEX IF NOT EXISTS "IX_Cliente_CpfNormalizado"
  ON "Cliente" ((regexp_replace("Documento", '\D', '', 'g')))
  WHERE "TipoDocumento" = 0;

-- Somente clientes com CPF (TipoDocumento.Cpf = 0), com 11 dígitos. A API não
-- tem status de cliente nem verificação de e-mail: todo cliente cadastrado é
-- ativo e o e-mail é o do cadastro.
CREATE OR REPLACE VIEW auth_clients AS
SELECT
  c."Id"::varchar(36)                          AS id,
  regexp_replace(c."Documento", '\D', '', 'g') AS cpf,
  true                                         AS active,
  c."Email"                                    AS email
FROM "Cliente" c
WHERE c."TipoDocumento" = 0
  AND length(regexp_replace(c."Documento", '\D', '', 'g')) = 11;

GRANT SELECT ON auth_clients TO :"lambda_role";

RESET ROLE;
