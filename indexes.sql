-- ÍNDICES ESSENCIAIS 
-- 22 Índices validados com EXPLAIN ANALYZE


SET search_path TO bd048_schema, public;


-- 1. Índices covering (Index-Only Scans)

-- Query 1: Recursos disponíveis
-- Índice criado para permitir Index Only Scan filtrando por disponibilidade e ordenando por título, eliminando Seq Scan e reduzindo o custo do sort.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_recurso_disponivel_titulo_covering
ON bd048_schema.recurso (disponibilidade, titulo)
INCLUDE (ID_recurso, ID_autor)
WHERE disponibilidade = 'disponível';

-- Query 6: Empréstimos ativos ordenados por data
-- Índice criado para filtrar rapidamente por estado_emprestimo e ordenar por data_emprestimo DESC, eliminando Seq Scan e permitindo Index Only Scan mais eficiente.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_emprestimo_estado_data_covering
ON bd048_schema.emprestimo (estado_emprestimo, data_emprestimo DESC)
INCLUDE (id_recurso, id_utilizador, data_devolucao_prevista);

-- Query 7: Recursos por estado='Bom'
-- Índice criado para acelerar o ORDER BY titulo e permitir Index Only Scan, reduzindo o Seq Scan completo em Recurso e diminuindo o custo dos LEFT JOINs.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_recurso_titulo_covering
ON bd048_schema.recurso (titulo)
INCLUDE (id_autor, id_editora, id_categoria, disponibilidade, estado);

-- Query 12: Ordenação por título + JOINs com Autor/Categoria
-- Covering index entrega dados ordenados sem heap access
-- Índice criado para evitar Seq Scans massivos em Recurso e permitir acesso ordenado por titulo, reduzindo o custo dos Joins com Emprestimo e Reserva.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_recurso_titulo_covering_joins
ON bd048_schema.recurso (titulo, ID_recurso)
INCLUDE (ID_autor, ID_categoria);

-- Query 20: Busca de título em JOINs
-- Permite selecionar ID e título diretamente do índice
-- Índice criado para acelerar joins por ID_recurso, reduzindo Seq Scans em Recurso e entregando título via covering index durante as agregações da query.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_recurso_id_titulo_covering
ON bd048_schema.recurso (ID_recurso)
INCLUDE (titulo);



-- 2. Índices parciais

-- Query 4: Multas pendentes
-- Índice parcial criado para evitar Seq Scan em multa, filtrando apenas multas pendentes e acelerando o join por ID_emprestimo.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_multa_estado_pendente
ON bd048_schema.multa (ID_emprestimo)
WHERE estado_multa = 'pendente';

-- Query 5: Devoluções atrasadas
-- Índice parcial criado para evitar Seq Scan em emprestimo, filtrando apenas devoluções atrasadas e acelerando o agrupamento e a contagem por utilizador.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_emprestimo_atrasos
ON bd048_schema.emprestimo (data_devolucao_efetiva, data_devolucao_prevista)
WHERE data_devolucao_efetiva IS NOT NULL 
  AND data_devolucao_efetiva > data_devolucao_prevista;

-- Query 11: Reservas não levantadas
-- Índice parcial criado para eliminar o Parallel Seq Scan na tabela reserva, filtrando apenas reservas pendentes (data_levantamento IS NULL).
-- Permite localizar rapidamente as reservas expiradas, reduzindo milhares de linhas lidas para apenas as realmente relevantes.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reserva_nao_levantadas
ON bd048_schema.reserva (data_limite_levantamento)
WHERE data_levantamento IS NULL;

-- Query 2: Recursos por disponibilidade e categoria 
-- Bitmap Index Scan
-- Índice criado para eliminar o Seq Scan na tabela recurso ao filtrar por disponibilidade = 'disponível'.
-- O primeiro atributo do índice (disponibilidade) permite usar um Bitmap Index Scan altamente seletivo, reduzindo drasticamente o número de linhas lidas antes do JOIN.
-- O segundo atributo (ID_categoria) melhora o agrupamento por categoria, alimentando o Hash Join e o HashAggregate com menos dados.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_recurso_disponibilidade_categoria
ON bd048_schema.recurso (disponibilidade, ID_categoria);

-- Query 16: Cálculo de devoluções (atrasadas vs no prazo)
-- Partial index com ambas as datas para CASE sem acesso à tabela
-- Índice parcial criado sobre (data_devolucao_efetiva, data_devolucao_prevista) para acelerar o filtro data_devolucao_efetiva IS NOT NULL.
-- Embora o Seq Scan ainda seja necessário para agregar por tipo de devolução, o índice permite acesso direto apenas às linhas relevantes.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_emprestimo_dates_calc
ON bd048_schema.emprestimo (data_devolucao_efetiva, data_devolucao_prevista)
WHERE data_devolucao_efetiva IS NOT NULL;



-- 3. Índices Compostos

-- Query 8, 14: Empréstimos por utilizador ordenados
--QUERY 8:
-- Índice criado para acelerar a consulta de empréstimos por utilizador
-- Permite obter rapidamente o último empréstimo de cada utilizador e reduzir o custo do ORDER BY sobre dias desde o último empréstimo
--QUERY 14:
-- Índice criado para acelerar consultas que filtram ou agregam empréstimos por data
-- Permite agilizar o acesso às datas de empréstimo recentes, reduzindo o custo do Seq Scan
-- Facilita consultas com agregações por mês e ordenação temporal sem ler toda a tabela
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_emprestimo_usuario_data_desc
ON bd048_schema.emprestimo (ID_utilizador, data_emprestimo DESC);

-- Query 17: Percentagem de empréstimos por funcionário
-- Índice criado para agilizar consultas que acessam a tabela Emprestimo por ID_funcionario
-- No caso desta query, os maiores custos vêm de Seq Scans massivos em Emprestimo e Aluno
-- O índice ajuda apenas a otimizar subqueries ou filtros futuros por ID_funcionario, mas não reduz significativamente o custo principal de agregações sobre toda a tabela
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_emprestimo_funcionario
ON bd048_schema.emprestimo (ID_funcionario);

-- Query 20, 22: UNION ALL top recursos por tipo
-- Hash Join optimization
-- Índices criados para otimizar os joins entre Emprestimo/reserva e cada tipo de recurso (Livro, EBook, Periódico)
-- A query realiza muitos Seq Scans e Hash Joins sobre grandes volumes de dados
-- Com estes índices, a leitura sequencial das tabelas de tipo de recurso é reduzida, acelerando os joins
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_livro_id_recurso
ON bd048_schema.livro (ID_recurso);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ebook_id_recurso
ON bd048_schema.ebook (ID_recurso);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_periodico_id_recurso
ON bd048_schema.periodico (ID_recurso);

-- Query 12: Anti-join optimization
-- Índice criado sobre emprestimo.id_recurso para otimizar a identificação de recursos não emprestados
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_emprestimo_id_recurso
ON bd048_schema.emprestimo (ID_recurso);

-- Query 20: Window function agregação por recurso
-- Ajuda COUNT(*) OVER (PARTITION BY ID_recurso)
-- O índice permite:
--   1. Acesso direto aos empréstimos de cada recurso, evitando leitura sequencial completa
--   2. Agregação mais rápida por ID_recurso para a ROW_NUMBER() e COUNT
--   3. Redução do custo de Hash Join com Recurso/Livro/EBook/Periódico
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_emprestimo_recurso_agregado
ON bd048_schema.emprestimo (ID_recurso, ID_emprestimo);

-- Query 22: Agregação de reservas por recurso
-- Crítico para evitar 3× Seq Scan
-- O índice permite:
--   1. Acesso direto às reservas de cada recurso, evitando leitura sequencial completa
--   2. Agregação mais rápida por ID_recurso para a ROW_NUMBER() e COUNT
--   3. Redução do custo de Hash Join com Recurso/Livro/EBook/Periódico
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reserva_id_recurso
ON bd048_schema.reserva (ID_recurso);



-- 4. Índice de Restrição Única (Regra de negócio)


-- Regra de negócio: 1 reserva ativa por utilizador por recurso
-- Índice único parcial para garantir regra de negócio.
-- Justificação:
-- 1. O índice é UNIQUE, então impede automaticamente a inserção de múltiplas reservas ativas
--    do mesmo utilizador para o mesmo recurso, garantindo a regra de negócio no nível do BD.
-- 2. É parcial (WHERE estado_reserva = 'ativa'), assim:
--    - Só mantém as reservas relevantes (ativas), ignorando as concluídas/canceladas.
--    - Reduz o tamanho do índice e melhora a performance de verificações de inserção.
-- 3. Permite consultas rápidas para verificar se um utilizador já tem reserva ativa de um recurso
--    evitando Seq Scans na tabela reserva para esta validação.
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_reserva_unq_recurso_utilizador_ativa
ON bd048_schema.reserva (ID_recurso, ID_utilizador)
WHERE estado_reserva = 'ativa';




-- 5.Índices de FOREIGN KEY 


-- FK Recurso → Categoria (Query 1, 2, 7, 15)
-- Otimiza JOINs entre Recurso e Categoria (frequente em Queries 1, 2, 7, 15).
-- Permite filtros rápidos por categoria sem precisar de Seq Scan.
-- Melhora performance em agregações e ordenações baseadas na categoria.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_recurso_id_categoria
ON bd048_schema.recurso (ID_categoria);

-- FK Recurso → Editora 
-- Otimiza verificações de integridade referencial quando uma editora é deletada.
-- Permite consultas filtrando por editora mais eficientes.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_recurso_id_editora
ON bd048_schema.recurso (ID_editora);

-- FK Recurso → Autor (Query 1, 7, 15 JOINs)
-- Otimiza JOINs entre Recurso e Autor (frequente em Queries 1, 7, 15).
-- Permite filtrar ou agrupar por autor sem precisar de Seq Scan.
-- Reduz custo de consultas que retornam dados do autor para cada recurso.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_recurso_id_autor
ON bd048_schema.recurso (ID_autor);




ANALYZE bd048_schema.emprestimo;
ANALYZE bd048_schema.reserva;
ANALYZE bd048_schema.recurso;
ANALYZE bd048_schema.utilizador;
ANALYZE bd048_schema.multa;
ANALYZE bd048_schema.livro;
ANALYZE bd048_schema.ebook;
ANALYZE bd048_schema.periodico;
ANALYZE bd048_schema.autor;



-- ANALISE PARA TRADE OFFS

-- Tabela Emprestimo 

--INSERT

BEGIN;
EXPLAIN ANALYZE
INSERT INTO Emprestimo (ID_utilizador, ID_recurso, ID_funcionario, 
                        data_emprestimo, data_devolucao_prevista, 
                        estado_emprestimo, numero_renovacoes)
SELECT 
    (random() * 1000)::int + 1,
    (random() * 10000)::int + 1,
    45425,
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '14 days',
    'em curso',
    0
FROM generate_series(1, 1000);
ROLLBACK;

-- Com índices: 431.111ms 
-- Sem índices: 243.903 ms 


-- UPDATE

BEGIN;
EXPLAIN ANALYZE
UPDATE Emprestimo 
SET data_devolucao_prevista = CURRENT_DATE + INTERVAL '15 days',
    numero_renovacoes = numero_renovacoes + 1 
WHERE ID_emprestimo BETWEEN 40000 AND 41000
  AND numero_renovacoes < 2;  
ROLLBACK;
-- Com índices: 356.056 ms
-- Sem índices: 314.358 ms



-- DELETE


BEGIN;
EXPLAIN ANALYZE
DELETE FROM Emprestimo 
WHERE ID_emprestimo BETWEEN 1000 AND 2000;
ROLLBACK;


-- Sem indices: 7225 ms
-- Com índices:  315.988 ms




-- Tabela Recurso (8 índices)


-- INSERT

BEGIN;
EXPLAIN ANALYZE
INSERT INTO Recurso (titulo, ano_publicacao, idioma, ID_autor, ID_editora, 
                     ID_categoria, disponibilidade, estado)
SELECT 
    'Livro Teste ' || i,
    2000 + (random() * 24)::int,
    'Português',
    (random() * 50)::int + 1,
    (random() * 20)::int + 1,
    (random() * 10)::int + 1,
    CASE WHEN random() < 0.7 THEN 'disponível' ELSE 'emprestado' END,
    'Bom'
FROM generate_series(1, 1000) i;
ROLLBACK;

-- Com índices: 60.957 ms
-- Sem índices: 29.907 ms


-- UPDATE

BEGIN;
EXPLAIN ANALYZE
UPDATE Recurso 
SET disponibilidade = 'disponível',
    estado = 'Bom'
WHERE ID_recurso BETWEEN 5000 AND 6000;
ROLLBACK;

-- Com índices: 58.162 ms
-- Sem índices: 6.997 ms


-- DELETE 

BEGIN;
EXPLAIN ANALYZE
DELETE FROM Recurso 
WHERE ID_recurso BETWEEN 100 AND 200;
ROLLBACK;

-- Sem índices: 6007.860 ms
-- Com índices: 5820.450 ms





-- Tabela Reserva (3 índices)


-- INSERT

BEGIN;
EXPLAIN ANALYZE
INSERT INTO Reserva (ID_utilizador, ID_recurso, ID_funcionario, estado_reserva, 
                     data_reserva, data_limite_levantamento)
SELECT 
    (random() * 1000)::int + 1,
    (random() * 10000)::int + 1,
    45425,
    'ativa',
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '3 days'
FROM generate_series(1, 1000);
ROLLBACK;

-- Com índices: 46.134 ms
-- Sem índices: 33.531 ms


-- UPDATE

BEGIN;
EXPLAIN ANALYZE
UPDATE Reserva 
SET estado_reserva = 'cancelada',
    data_limite_levantamento = NULL
WHERE ID_reserva BETWEEN 1000 AND 2000;
ROLLBACK;

-- Com índices: 14.010 ms
-- Sem índices: 7.711 ms


-- DELETE

BEGIN;
EXPLAIN ANALYZE
DELETE FROM Reserva 
WHERE ID_reserva BETWEEN 500 AND 1500;
ROLLBACK;

-- Sem índices: 2.425 ms
-- Com índices: 1.091 ms




-- Tabela Multa (1 índice partial)


-- INSERT

BEGIN;
EXPLAIN ANALYZE
INSERT INTO Multa (ID_emprestimo, valor, data_aplicacao, estado_multa)
SELECT 
    e.ID_emprestimo,
    (random() * 50)::numeric(10,2) + 5.00,
    CURRENT_DATE,
    'pendente'
FROM (
    SELECT ID_emprestimo 
    FROM Emprestimo 
    WHERE ID_emprestimo NOT IN (SELECT ID_emprestimo FROM Multa)
    LIMIT 1000
) e;
ROLLBACK;

-- Com índices: 48.789 ms
-- Sem índices: 37.345 ms


-- UPDATE

BEGIN;
EXPLAIN ANALYZE
UPDATE Multa 
SET estado_multa = 'pago',
    data_pagamento = CURRENT_DATE
WHERE ID_multa BETWEEN 1000 AND 2000;
ROLLBACK;

-- Com índices: 15.633 ms
-- Sem índices: 9.334 ms


-- DELETE

BEGIN;
EXPLAIN ANALYZE
DELETE FROM Multa 
WHERE ID_multa BETWEEN 500 AND 1500;
ROLLBACK;

-- Sem índices: 0.864 ms
-- Com índices: 0.836 ms





-- Tabela Livro (1 índice FK)

-- INSERT 

BEGIN;
EXPLAIN ANALYZE
INSERT INTO Livro (ID_recurso, ISBN, edicao, volume, localizacao)
SELECT 
    ID_recurso,
    'ISBN-' || ID_recurso,
    1,
    1,
    'Estante A'
FROM temp_recursos;

DROP TABLE temp_recursos;
ROLLBACK;

-- Com índices: 19.826 ms
-- Sem índices: 17.280 ms


-- UPDATE

BEGIN;
EXPLAIN ANALYZE
UPDATE Livro 
SET edicao = 2,
    localizacao = 'Estante B'
WHERE ID_recurso BETWEEN 1000 AND 2000;
ROLLBACK;

-- Com índices: 14.728 ms
-- Sem índices: 11.842 ms


-- DELETE

BEGIN;
EXPLAIN ANALYZE
DELETE FROM Livro 
WHERE ID_recurso BETWEEN 500 AND 1500;
ROLLBACK;

-- Sem índices: 0.850 ms
-- Com índices: 1.437 ms




-- Tabela EBook (1 índice FK)

-- INSERT

BEGIN;
EXPLAIN ANALYZE
INSERT INTO EBook (ID_recurso, link_acesso, formato, tamanho_ficheiro)
SELECT 
    ID_recurso,
    'https://biblioteca.pt/ebook/' || ID_recurso,
    'PDF',
    5.5
FROM temp_recursos_ebook;

DROP TABLE temp_recursos_ebook;
ROLLBACK;

-- Com índices: 13.318 ms
-- Sem índices: 12.408 ms 


-- UPDATE

BEGIN;
EXPLAIN ANALYZE
UPDATE EBook 
SET formato = 'EPUB',
    tamanho_ficheiro = 3.2
WHERE ID_recurso BETWEEN 1000 AND 2000;
ROLLBACK;

-- Com índices: 0.046 ms
-- Sem índices: 0.032 ms


-- DELETE

BEGIN;
EXPLAIN ANALYZE
DELETE FROM EBook 
WHERE ID_recurso BETWEEN 500 AND 1500;
ROLLBACK;

-- Sem índices: 0.023 ms
-- Com índices: 0.023 ms




-- Tabela Periodico (1 índice FK)


-- INSERT 


EXPLAIN ANALYZE
INSERT INTO Periodico (ID_recurso, ISSN, frequencia_publicacao, numero_edicao)
SELECT 
    ID_recurso,
    'ISSN-' || ID_recurso,
    'Mensal',
    1
FROM temp_recursos_periodico;

DROP TABLE temp_recursos_periodico;
ROLLBACK;

-- Com índices: 19.434 ms
-- Sem índices: 16.543 ms


-- UPDATE

BEGIN;
EXPLAIN ANALYZE
UPDATE Periodico 
SET frequencia_publicacao = 'Semanal',
    numero_edicao = 2
WHERE ID_recurso BETWEEN 1000 AND 2000;
ROLLBACK;

-- Com índices: 0.033 ms
-- Sem índices: 0.023 ms


-- DELETE

BEGIN;
EXPLAIN ANALYZE
DELETE FROM Periodico 
WHERE ID_recurso BETWEEN 500 AND 1500;
ROLLBACK;

-- Sem índices: 0.032 ms
-- Com índices: 0.023 ms










