
--INCLUI SCRIPTS PARA CRIAÇÃO DE MILHARES DE DADOS NA TABELAS A PARTIR DA LINHA 340 


SET search_path TO bd048_schema, public;

--Interrogação 1--
EXPLAIN ANALYZE
SELECT Recurso.titulo,
       CONCAT(Autor.primeiro_nome_autor, ' ', Autor.ultimo_nome_autor) AS nome_autor,
       CASE 
           WHEN Livro.ID_recurso IS NOT NULL THEN 'Livro'  
           WHEN EBook.ID_recurso IS NOT NULL THEN 'EBook'  
           WHEN Periodico.ID_recurso IS NOT NULL THEN 'Periodico' 
       END AS tipo_recurso
FROM Recurso
LEFT OUTER JOIN Livro ON Recurso.ID_recurso = Livro.ID_recurso 
LEFT OUTER JOIN EBook ON Recurso.ID_recurso = EBook.ID_recurso 
LEFT OUTER JOIN Periodico ON Recurso.ID_recurso = Periodico.ID_recurso 
JOIN Autor ON Recurso.ID_autor = Autor.ID_autor 
WHERE Recurso.disponibilidade = 'disponível'
ORDER BY Recurso.titulo;


--Interrogação 2--
EXPLAIN ANALYZE
SELECT Categoria.nome_categoria, COUNT(Recurso.ID_recurso) AS disponiveis
FROM Recurso 
JOIN Categoria ON Recurso.ID_categoria = Categoria.ID_categoria
WHERE Recurso.disponibilidade = 'disponível'
GROUP BY Categoria.nome_categoria;
--Mesmo com todos os índices criados, PostgreSQL ainda usa Seq Scan devido ao tamanho pequeno das tabelas. No entanto, o custo e tempo de execução melhoraram significativamente, demonstrando o efeito positivo da indexação


--Interrogação 3--
EXPLAIN ANALYZE
SELECT Recurso.titulo, COUNT(Emprestimo.ID_emprestimo) AS total_emprestimos
FROM Recurso
JOIN Emprestimo ON Recurso.ID_recurso = Emprestimo.ID_recurso
GROUP BY Recurso.titulo
ORDER BY total_emprestimos DESC


--Interrogaççao 4
EXPLAIN ANALYZE
SELECT Multa.ID_multa, CONCAT(Utilizador.primeiro_nome, ' ', Utilizador.ultimo_nome) AS utilizador, Multa.valor, Multa.data_aplicacao
FROM Multa 
JOIN Emprestimo ON Multa.ID_emprestimo = Emprestimo.ID_emprestimo
JOIN Utilizador ON Emprestimo.ID_utilizador = Utilizador.ID_utilizador
WHERE Multa.estado_multa = 'pendente';

--INTERROGAÇAO 5
EXPLAIN ANALYZE
SELECT Utilizador.id_utilizador, CONCAT(Utilizador.primeiro_nome, ' ', Utilizador.ultimo_nome) AS nome, 
COUNT(*) AS total_atrasos, RANK() OVER (ORDER BY COUNT(*) DESC) AS ranking_atrasados
FROM Emprestimo 
JOIN Utilizador ON Utilizador.id_utilizador = Emprestimo.id_utilizador
WHERE Emprestimo.data_devolucao_efetiva IS NOT NULL
  AND Emprestimo.data_devolucao_efetiva > Emprestimo.data_devolucao_prevista
GROUP BY Utilizador.id_utilizador, Utilizador.primeiro_nome, Utilizador.ultimo_nome;



--INTERROGAÇAO 6
EXPLAIN ANALYZE
SELECT Recurso.titulo, CONCAT(Utilizador.primeiro_nome, ' ',  Utilizador.ultimo_nome) AS nome_utilizador, 
Emprestimo.data_emprestimo, Emprestimo.data_devolucao_prevista
FROM Emprestimo 
JOIN Recurso ON Emprestimo.ID_recurso = Recurso.ID_recurso
JOIN Utilizador ON Emprestimo.ID_utilizador = Utilizador.ID_utilizador
WHERE Emprestimo.estado_emprestimo = 'em curso'
ORDER BY Emprestimo.data_emprestimo DESC;



-- INTERROGAÇAO 7
EXPLAIN ANALYZE
SELECT Recurso.titulo, CONCAT(Autor.primeiro_nome_autor, ' ', Autor.ultimo_nome_autor) AS autor,
Editora.nome_editora, Categoria.nome_categoria, Recurso.disponibilidade
FROM Recurso 
LEFT OUTER JOIN Autor ON Recurso.ID_autor = Autor.ID_autor
LEFT OUTER JOIN Editora ON Recurso.ID_editora = Editora.ID_editora
LEFT OUTER JOIN Categoria ON Recurso.ID_categoria = Categoria.ID_categoria
WHERE Recurso.estado = 'Bom'
ORDER BY Recurso.titulo;



--INTERROGAÇAO 8
EXPLAIN ANALYZE
SELECT Utilizador.ID_utilizador, CONCAT(Utilizador.primeiro_nome, ' ', Utilizador.ultimo_nome) AS nome_utilizador,
    MAX(Emprestimo.data_emprestimo) AS ultimo_emprestimo,
    CURRENT_DATE - MAX(Emprestimo.data_emprestimo) AS dias_desde_ultimo_emprestimo
FROM Utilizador
LEFT OUTER JOIN Emprestimo ON Utilizador.ID_utilizador = Emprestimo.ID_utilizador
GROUP BY Utilizador.ID_utilizador, Utilizador.primeiro_nome, Utilizador.ultimo_nome
ORDER BY dias_desde_ultimo_emprestimo DESC;



-- INTERROGAÇAO 9
EXPLAIN ANALYZE
SELECT Recurso.titulo, COUNT(Reserva.ID_reserva) AS total_reservas_pendentes
FROM Recurso
JOIN Reserva ON Recurso.ID_recurso = Reserva.ID_recurso
WHERE Reserva.estado_reserva = 'ativa'
GROUP BY Recurso.ID_recurso, Recurso.titulo
ORDER BY total_reservas_pendentes DESC



-- INTERROGAÇAO 10
EXPLAIN ANALYZE
SELECT Utilizador.ID_utilizador, CONCAT(Utilizador.primeiro_nome, ' ', Utilizador.ultimo_nome) AS nome_utilizador,
    COUNT(DISTINCT Emprestimo.ID_emprestimo) AS total_emprestimos,
    COUNT(DISTINCT Reserva.ID_reserva) AS total_reservas
FROM Utilizador
FULL OUTER JOIN Emprestimo ON Utilizador.ID_utilizador = Emprestimo.ID_utilizador
FULL OUTER JOIN Reserva ON Utilizador.ID_utilizador = Reserva.ID_utilizador
GROUP BY Utilizador.ID_utilizador, Utilizador.primeiro_nome, Utilizador.ultimo_nome
HAVING COUNT(DISTINCT Emprestimo.ID_emprestimo) > 0 OR COUNT(DISTINCT Reserva.ID_reserva) > 0
ORDER BY total_emprestimos DESC, total_reservas DESC;



-- INTERROGAÇAO 11
EXPLAIN ANALYZE
SELECT Utilizador.ID_utilizador, CONCAT(Utilizador.primeiro_nome, ' ', Utilizador.ultimo_nome) AS nome_utilizador, Reserva.ID_reserva,
Reserva.data_reserva, Reserva.data_limite_levantamento, Reserva.data_levantamento
FROM Utilizador
JOIN Reserva ON Utilizador.ID_utilizador = Reserva.ID_utilizador
WHERE Reserva.data_levantamento IS NULL        
  AND Reserva.data_limite_levantamento < CURRENT_DATE  
ORDER BY Reserva.data_limite_levantamento ASC;



-- INTERROGAÇAO 12
EXPLAIN ANALYZE
SELECT Recurso.titulo, CONCAT(Autor.primeiro_nome_autor, ' ', Autor.ultimo_nome_autor) AS autor, Categoria.nome_categoria
FROM Recurso 
LEFT OUTER JOIN Emprestimo ON Recurso.ID_recurso = Emprestimo.ID_recurso
LEFT OUTER JOIN Reserva ON Recurso.ID_recurso = Reserva.ID_recurso
LEFT OUTER JOIN Autor ON Recurso.ID_autor = Autor.ID_autor
LEFT OUTER JOIN Categoria ON Recurso.ID_categoria = Categoria.ID_categoria
WHERE Emprestimo.ID_emprestimo IS NULL AND Reserva.ID_reserva IS NULL
ORDER BY Recurso.titulo;



--INTERROGAÇAO 13
EXPLAIN ANALYZE
SELECT Recurso.idioma, COUNT(Emprestimo.id_emprestimo) AS total_emprestimos,
    ROUND(100.0 * COUNT(Emprestimo.id_emprestimo) / SUM(COUNT(Emprestimo.id_emprestimo)) OVER (), 2) AS percentagem_emprestimos
FROM Emprestimo
JOIN Recurso ON Emprestimo.ID_recurso = Recurso.ID_recurso
GROUP BY Recurso.idioma
ORDER BY total_emprestimos DESC;


--INTERROGAÇAO 14
EXPLAIN ANALYZE
SELECT TO_CHAR(date_trunc('month', data_emprestimo), 'YYYY-MM') AS mes, COUNT(*) AS total_emprestimos
FROM Emprestimo
WHERE data_emprestimo >= (CURRENT_DATE - INTERVAL '12 months')
GROUP BY date_trunc('month', data_emprestimo)
ORDER BY mes;


--INTERROGAÇAO 15
EXPLAIN ANALYZE
SELECT Autor.ID_autor, CONCAT(Autor.primeiro_nome_autor, ' ',Autor.ultimo_nome_autor )AS nome_autor,
    COUNT(Emprestimo.ID_emprestimo) AS total_emprestimos
FROM Autor
JOIN Recurso ON Autor.ID_autor = Recurso.ID_autor
JOIN Emprestimo ON Recurso.ID_recurso = Emprestimo.ID_recurso
GROUP BY Autor.ID_autor, nome_autor
ORDER BY total_emprestimos DESC;




--INTERROGAÇAO 16
EXPLAIN ANALYZE
SELECT 
    CASE 
        WHEN Emprestimo.data_devolucao_efetiva < Emprestimo.data_devolucao_prevista THEN 'Adiantado'
        WHEN Emprestimo.data_devolucao_efetiva = Emprestimo.data_devolucao_prevista THEN 'No dia da devolução prevista'
        ELSE 'Atrasado'
    END AS tipo_devolucao,
    COUNT(*) AS total,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentagem
FROM Emprestimo
WHERE Emprestimo.data_devolucao_efetiva IS NOT NULL
GROUP BY tipo_devolucao;


--INTERROGAÇAO 17
EXPLAIN ANALYZE
SELECT Aluno.curso,
    COUNT(Emprestimo.ID_emprestimo) AS total_emprestimos,
    CONCAT(ROUND((COUNT(Emprestimo.ID_emprestimo)::DECIMAL / (SELECT COUNT(*) FROM Emprestimo)) * 100, 2),' %') AS percentagem_total
FROM Emprestimo
JOIN Utilizador ON Emprestimo.ID_utilizador = Utilizador.ID_utilizador
JOIN Aluno ON Aluno.ID_utilizador = Utilizador.ID_utilizador
GROUP BY Aluno.curso
ORDER BY total_emprestimos DESC;


--INTERROGAÇAO 18
EXPLAIN ANALYZE
SELECT cargo,
    ROUND(AVG(salario), 2) AS salario_medio,
    ROUND(MIN(salario), 2) AS salario_minimo,
    ROUND(MAX(salario), 2) AS salario_maximo,
    COUNT(*) AS numero_funcionarios
FROM Funcionario
GROUP BY cargo
ORDER BY salario_medio DESC;




--INTERROGAÇAO 19
EXPLAIN ANALYZE
SELECT 
    CASE 
        WHEN idade BETWEEN 15 AND 20 THEN '15-20 anos'
        WHEN idade BETWEEN 21 AND 25 THEN '21-25 anos'
        WHEN idade BETWEEN 26 AND 35 THEN '26-35 anos'
        WHEN idade BETWEEN 36 AND 45 THEN '36-45 anos'
        WHEN idade BETWEEN 46 AND 55 THEN '46-55 anos'
        WHEN idade BETWEEN 56 AND 65 THEN '56-65 anos'
        WHEN idade > 65 THEN '65+ anos'
        ELSE 'Idade desconhecida'
    END AS faixa_etaria,
    COUNT(*) AS total_utilizadores,
    CONCAT(ROUND((COUNT(*)::DECIMAL / (SELECT COUNT(*) FROM Utilizador)) * 100, 2),' %') AS percentagem_total
FROM Utilizador
GROUP BY faixa_etaria
ORDER BY faixa_etaria;




--INTERROGAÇAO 20 
EXPLAIN ANALYZE
SELECT tipo_recurso, titulo, total_emprestimos
FROM (SELECT 'Livro' AS tipo_recurso, Recurso.titulo,
        COUNT(Emprestimo.ID_emprestimo) AS total_emprestimos,
        ROW_NUMBER() OVER (PARTITION BY 'Livro' ORDER BY COUNT(Emprestimo.ID_emprestimo) DESC) AS lista
    FROM Emprestimo
    JOIN Recurso ON Emprestimo.ID_recurso = Recurso.ID_recurso
    JOIN Livro ON Livro.ID_recurso = Recurso.ID_recurso
    GROUP BY Recurso.titulo
    UNION ALL
    SELECT 'EBook' AS tipo_recurso, Recurso.titulo,
        COUNT(Emprestimo.ID_emprestimo) AS total_emprestimos,
        ROW_NUMBER() OVER (PARTITION BY 'EBook' ORDER BY COUNT(Emprestimo.ID_emprestimo) DESC) AS lista
    FROM Emprestimo
    JOIN Recurso ON Emprestimo.ID_recurso = Recurso.ID_recurso
    JOIN EBook ON EBook.ID_recurso = Recurso.ID_recurso
    GROUP BY Recurso.titulo
    UNION ALL
    SELECT 
        'Periódico' AS tipo_recurso,
        Recurso.titulo,
        COUNT(Emprestimo.ID_emprestimo) AS total_emprestimos,
        ROW_NUMBER() OVER (PARTITION BY 'Periódico' ORDER BY COUNT(Emprestimo.ID_emprestimo) DESC) AS lista
    FROM Emprestimo
    JOIN Recurso ON Emprestimo.ID_recurso = Recurso.ID_recurso
    JOIN Periodico ON Periodico.ID_recurso = Recurso.ID_recurso
    GROUP BY Recurso.titulo
) AS dados
WHERE lista = 1
ORDER BY total_emprestimos DESC;



--INTERROGAÇAO 21
EXPLAIN ANALYZE
SELECT tipo_utilizador,
    COUNT(*) AS total_emprestimos,
    SUM(CASE WHEN numero_renovacoes > 0 THEN 1 ELSE 0 END) AS emprestimos_renovados,
    CONCAT(ROUND((SUM(CASE WHEN numero_renovacoes > 0 THEN 1 ELSE 0 END)::DECIMAL / COUNT(*)) * 100, 2),'%') AS percentagem_renovacao
FROM (
    SELECT Emprestimo.ID_emprestimo, Emprestimo.numero_renovacoes,
        CASE 
            WHEN Aluno.ID_utilizador IS NOT NULL THEN 'Aluno'
            WHEN Professor.ID_utilizador IS NOT NULL THEN 'Professor'
            WHEN Funcionario.ID_utilizador IS NOT NULL THEN 'Funcionario'
            ELSE 'Outro'
        END AS tipo_utilizador
    FROM Emprestimo
    LEFT JOIN Aluno ON Emprestimo.ID_utilizador = Aluno.ID_utilizador
    LEFT JOIN Professor ON Emprestimo.ID_utilizador = Professor.ID_utilizador
    LEFT JOIN Funcionario ON Emprestimo.ID_utilizador = Funcionario.ID_utilizador
) AS dados
GROUP BY tipo_utilizador
ORDER BY tipo_utilizador;



--INTERROGAÇAO 22
EXPLAIN ANALYZE
SELECT tipo_recurso, titulo, total_reservas
FROM (
    SELECT 'Livro' AS tipo_recurso, Recurso.titulo,
        COUNT(Reserva.ID_reserva) AS total_reservas,
        ROW_NUMBER() OVER (PARTITION BY 'Livro' ORDER BY COUNT(Reserva.ID_reserva) DESC) AS lista
    FROM Reserva
    JOIN Recurso ON Reserva.ID_recurso = Recurso.ID_recurso
    JOIN Livro ON Livro.ID_recurso = Recurso.ID_recurso
    GROUP BY Recurso.titulo
    UNION ALL
    SELECT 'EBook' AS tipo_recurso, Recurso.titulo,
        COUNT(Reserva.ID_reserva) AS total_reservas,
        ROW_NUMBER() OVER (PARTITION BY 'EBook' ORDER BY COUNT(Reserva.ID_reserva) DESC) AS lista
    FROM Reserva 
    JOIN Recurso ON Reserva.ID_recurso = Recurso.ID_recurso
    JOIN EBook ON EBook.ID_recurso = Recurso.ID_recurso
    GROUP BY Recurso.titulo
    UNION ALL
    SELECT 
        'Periódico' AS tipo_recurso,
        Recurso.titulo,
        COUNT(Reserva.ID_reserva) AS total_reservas,
        ROW_NUMBER() OVER (PARTITION BY 'Periódico' ORDER BY COUNT(Reserva.ID_reserva) DESC) AS lista
    FROM Reserva
    JOIN Recurso ON Reserva.ID_recurso = Recurso.ID_recurso
    JOIN Periodico ON Periodico.ID_recurso = Recurso.ID_recurso
    GROUP BY Recurso.titulo
) AS dados
WHERE lista = 1
ORDER BY total_reservas DESC;




-- SCRIPTS AUTOMATIZADOS PARA GERAR MILHARES DE DADOS NECESSÁRIOS PARA TESTAR ÍNDICES E OTIMIZAÇÕES



-- Ajustar a sequência do SERIAL para que comece após o último ID existente
SELECT setval('editora_id_editora_seq', (SELECT MAX(ID_editora) FROM Editora));

-- 500 editoras
-- Gerar mais 5000 editoras
INSERT INTO Editora(nome_editora, email_editora, website)
SELECT 
    'Editora ' || (20 + gs),
    'editora' || (20 + gs) || '@exemplo.com',
    'www.editora' || (20 + gs) || '.com'
FROM generate_series(1,5000) AS gs;



-- Arrays de nomes por nacionalidade
-- Ajusta a sequência do SERIAL de Autor para começar após o último ID existente
SELECT setval('autor_id_autor_seq', (SELECT MAX(ID_autor) FROM Autor));
-- Gera 20000 autores com primeiro, (opcional) segundo nome vindo da lista de apelidos, e apelido.
INSERT INTO Autor(
    primeiro_nome_autor,
    segundo_nome_autor,
    ultimo_nome_autor,
    nacionalidade,
    email_autor,
    data_nascimento_autor,
    data_falecimento_autor
)
SELECT
    'Autor' || gs AS primeiro_nome_autor,
    NULL AS segundo_nome_autor,
    'Sobrenome' || gs AS ultimo_nome_autor,
    (ARRAY['Portugal','Inglaterra','Estados Unidos','Espanha','França'])[FLOOR(random()*5)::int + 1] AS nacionalidade,
    'autor' || gs || '@exemplo.com' AS email_autor,
    date '1940-01-01' + (random() * (date '2008-12-31' - date '1940-01-01'))::int AS data_nascimento_autor,
    NULL AS data_falecimento_autor
FROM generate_series(101,20100) AS gs;





-- Adjust the sequence for the Recurso table to start after the last existing ID
SELECT setval('recurso_id_recurso_seq', (SELECT MAX(ID_recurso) FROM Recurso));

-- ...existing code...

WITH random_authors AS (
    SELECT 
        ID_autor, 
        data_nascimento_autor
    FROM Autor
    WHERE ID_autor BETWEEN 101 AND 20100
    ORDER BY random()
    LIMIT 20000
)
INSERT INTO Recurso(
    titulo, ano_publicacao, idioma, disponibilidade, estado,
    ID_categoria, ID_editora, ID_autor
)
SELECT
    'Recurso ' || row_number() OVER () AS titulo,
    (EXTRACT(YEAR FROM ra.data_nascimento_autor)::int + FLOOR(random() * (2022 - EXTRACT(YEAR FROM ra.data_nascimento_autor)::int + 1)))::int AS ano_publicacao,
    (ARRAY['Português','Inglês','Espanhol','Francês','Alemão'])[FLOOR(random()*5)::int + 1] AS idioma,
    'disponível' AS disponibilidade,
    'Bom' AS estado,
    FLOOR(random()*25)::int + 1 AS ID_categoria,
    FLOOR(random()*500)::int + 1 AS ID_editora,
    ra.ID_autor
FROM random_authors ra;











-- Assign recursos with ID_recurso BETWEEN 203 AND 20202 (no overlaps) into Livro, EBook, Periodico

CREATE TEMP TABLE tmp_recurso_partitioned AS
SELECT
  r.*,
  ROW_NUMBER() OVER (ORDER BY r.ID_recurso) AS rn,
  COUNT(*) OVER () AS total
FROM Recurso r
WHERE r.ID_recurso BETWEEN 203 AND 20202
  AND r.ID_recurso NOT IN (
    SELECT ID_recurso FROM Livro
    UNION
    SELECT ID_recurso FROM EBook
    UNION
    SELECT ID_recurso FROM Periodico
  );

-- Livro: first third
INSERT INTO Livro(ID_recurso, ISBN, edicao, volume, localizacao)
SELECT
  ID_recurso,
  'ISBN' || ID_recurso,
  FLOOR(1 + random()*5)::int,
  FLOOR(1 + random()*10)::int,
  'Estante ' || FLOOR(1 + random()*100)::int
FROM tmp_recurso_partitioned
WHERE rn <= FLOOR(total::numeric / 3);

-- EBook: second third
INSERT INTO EBook(ID_recurso, link_acesso, formato, tamanho_ficheiro)
SELECT
  ID_recurso,
  'https://ebook/' || ID_recurso,
  (ARRAY['PDF','EPUB','MOBI'])[FLOOR(random()*3)::int + 1],
  FLOOR(1 + random()*100)::int || 'MB'
FROM tmp_recurso_partitioned
WHERE rn > FLOOR(total::numeric / 3)
  AND rn <= FLOOR(total::numeric * 2 / 3);

-- Periodico: last third
INSERT INTO Periodico(ID_recurso, ISSN, frequencia_publicacao, numero_edicao)
SELECT
  ID_recurso,
  'ISSN' || ID_recurso,
  (ARRAY['Mensal','Semestral','Anual'])[FLOOR(random()*3)::int + 1],
  FLOOR(1 + random()*20)::int
FROM tmp_recurso_partitioned
WHERE rn > FLOOR(total::numeric * 2 / 3);

DROP TABLE tmp_recurso_partitioned;



-- TABELA UTILIZADOR

SELECT setval(
    'bd048_schema.utilizador_id_utilizador_seq',
    COALESCE((SELECT MAX(ID_utilizador) FROM bd048_schema.Utilizador), 1),
    TRUE
);


BEGIN;

WITH v AS (SELECT COALESCE(MAX(ID_utilizador),0) AS maxid FROM bd048_schema.Utilizador)
INSERT INTO bd048_schema.Utilizador(
  primeiro_nome, segundo_nome, ultimo_nome, email, numero_telemovel,
  nome_rua, numero_casa, cidade, codigo_postal, data_nascimento
)
SELECT
  -- first name
  (ARRAY['Ana','João','Maria','Tiago','Helena','Miguel','Sofia','Rui','Carla','Tomás'])[FLOOR(random()*10)::int + 1],
  -- optional middle name (NULL ~ 50% of rows)
  CASE WHEN random() < 0.5 THEN NULL ELSE (ARRAY['Paulo','Inês','Pedro','Luís','Mariana','Beatriz','Pedro','Filipa','André','Rita'])[FLOOR(random()*10)::int + 1] END,
  -- last name
  (ARRAY['Silva','Santos','Pereira','Costa','Ferreira','Rodrigues','Martins','Gomes','Almeida','Rocha'])[FLOOR(random()*10)::int + 1],
  -- unique email
  'user' || (v.maxid + gs) || '@uni.com',
  -- unique phone
  ('9' || (10000000 + v.maxid + gs)::text),
  -- street
  (ARRAY['Avenida de Berna','Rua da Liberdade','Avenida do Sol','Rua Carmen Miranda','Travessa do Comércio','Rua Vale da Sobreira','Avenida de Roma','Rua do Limoeiro','Rua das Flores','Avenida do Brasil'])[FLOOR(random()*10)::int + 1],
  -- house number
  (FLOOR(random()*200) + 1)::text,
  -- city
  (ARRAY['Lisboa','Porto','Coimbra','Braga','Faro','Aveiro','Setúbal','Almada','Cascais','Leiria'])[FLOOR(random()*10)::int + 1],
  -- postal code NNNN-NNN
  LPAD((FLOOR(random()*9000)+1000)::text,4,'0') || '-' || LPAD((FLOOR(random()*900)+100)::text,3,'0'),
  -- birthdate between 1950-01-01 and 2006-12-31
  date '1950-01-01' + (random() * (date '2006-12-31' - date '1950-01-01'))::int
FROM v
CROSS JOIN generate_series(1,50000) AS gs;

COMMIT;





DROP TABLE IF EXISTS tmp_users_materialized;
DROP TABLE IF EXISTS tmp_counts;


CREATE TEMP TABLE tmp_users_materialized AS
SELECT
  u.ID_utilizador,
  row_number() OVER (ORDER BY random()) AS rn,
  COUNT(*) OVER () AS total
FROM bd048_schema.Utilizador u
WHERE u.ID_utilizador NOT IN (
  SELECT ID_utilizador FROM bd048_schema.Aluno
  UNION
  SELECT ID_utilizador FROM bd048_schema.Professor
  UNION
  SELECT ID_utilizador FROM bd048_schema.Funcionario
);

CREATE TEMP TABLE tmp_counts AS
SELECT
  total,
  floor(total * 0.50)::int AS n_aluno,
  floor(total * 0.35)::int AS n_prof,
  (floor(total * 0.50)::int + floor(total * 0.35)::int) AS p_cut
FROM (SELECT DISTINCT total FROM tmp_users_materialized) t;

-- Aluno: first 50%
INSERT INTO Aluno(ID_utilizador, numero_aluno, ano, curso, ano_ingresso)
SELECT
  tu.ID_utilizador,
  'ALU' || lpad(tu.ID_utilizador::text, 6, '0'),
  (FLOOR(random()*4) + 1)::int, -- ano 1..4
  (ARRAY['LEI','MAT','FIS','QUI','ENG','MED','DIR','PSI','ECO'])[FLOOR(random()*9)::int + 1],
  (FLOOR(2016 + random()*9))::int
FROM tmp_users_materialized tu
CROSS JOIN tmp_counts c
WHERE tu.rn <= c.n_aluno;

-- Professor: next 35%
INSERT INTO bd048_schema.Professor(ID_utilizador, departamento, especializacao, disciplinas_lecionadas)
SELECT
  tu.ID_utilizador,
  (ARRAY['Matemática','Física','Informática','Química','Biologia','Direito','Economia','Letras'])[FLOOR(random()*8)::int + 1],
  (ARRAY['Teoria Avançada','Didática','Investigação','Computação Científica','Gestão'])[FLOOR(random()*5)::int + 1],
  array_to_string(ARRAY[
    (ARRAY['Álgebra','Cálculo','Estatística','Programação','Redes','Química Orgânica','Anatomia','Direito Civil'])[FLOOR(random()*8)::int + 1],
    (ARRAY['Optativo A','Optativo B','Optativo C','Optativo D'])[FLOOR(random()*4)::int + 1]
  ], ', ')
FROM tmp_users_materialized tu
CROSS JOIN tmp_counts c
WHERE tu.rn > c.n_aluno AND tu.rn <= c.p_cut;

-- Funcionario: remaining (~15%)
INSERT INTO Funcionario(ID_utilizador, cargo, data_contratacao, salario, horario_trabalho, pode_emprestar)
SELECT
  tu.ID_utilizador,
  cargo,
  date '2010-01-01' + (random() * (CURRENT_DATE - date '2010-01-01'))::int,
  ROUND( (800 + random() * 3200)::numeric, 2),
  (ARRAY['Diurno','Noturno','Part-time'])[FLOOR(random()*3)::int + 1],
  CASE 
      WHEN cargo = 'Bibliotecario' THEN true
      ELSE false
  END
FROM (
    SELECT 
        tu.*,
        (ARRAY['Bibliotecario','Técnico','Administrador','Assistente'])[FLOOR(random()*4)::int + 1] AS cargo
    FROM tmp_users_materialized tu
) tu
CROSS JOIN tmp_counts c
WHERE tu.rn > c.p_cut;


-- cleanup
DROP TABLE tmp_users_materialized;
DROP TABLE tmp_counts;

UPDATE Funcionario
SET pode_emprestar = (cargo = 'Bibliotecario');


ALTER TABLE Funcionario
DROP CONSTRAINT IF EXISTS func_pode_emprestar_check;


ALTER TABLE Funcionario
ADD CONSTRAINT func_pode_emprestar_check
CHECK (pode_emprestar = false OR cargo = 'Bibliotecario');







ALTER TABLE Emprestimo ENABLE TRIGGER trigger_data_devolucao;
ALTER TABLE Emprestimo DISABLE TRIGGER trigger_atualizar_disponibilidade;



DROP TABLE IF EXISTS recursos_ativos;
BEGIN;

-- materialize active recursos reserved for in-progress / atrasado
CREATE TEMP TABLE recursos_ativos AS
SELECT ID_recurso
FROM bd048_schema.Recurso
WHERE disponibilidade = 'disponível'
ORDER BY random()
LIMIT 12000;

-- candidates for concluded loans (shuffled)
CREATE TEMP TABLE concl_candidates AS
SELECT ID_recurso, row_number() OVER (ORDER BY random()) AS rn
FROM Recurso
WHERE ID_recurso NOT IN (SELECT ID_recurso FROM recursos_ativos);

WITH
emprestimos_em_curso AS (
  SELECT
    (SELECT ID_utilizador FROM Utilizador ORDER BY random() LIMIT 1) AS u_id,
    (SELECT ID_utilizador FROM Funcionario WHERE pode_emprestar = TRUE ORDER BY random() LIMIT 1) AS f_id,
    r.ID_recurso AS r_id,
    (CURRENT_DATE - (floor(random() * 15)::int))::date AS emprestimo_date,
    NULL::date AS data_devolucao_efetiva,
    'em curso' AS estado_emprestimo
  FROM recursos_ativos r
  LIMIT 8000
),
emprestimos_atrasados AS (
  SELECT
    (SELECT ID_utilizador FROM Utilizador ORDER BY random() LIMIT 1) AS u_id,
    (SELECT ID_utilizador FROM Funcionario WHERE pode_emprestar = TRUE ORDER BY random() LIMIT 1) AS f_id,
    r.ID_recurso AS r_id,
    (CURRENT_DATE - (16 + floor(random() * 30)::int))::date AS emprestimo_date,
    NULL::date AS data_devolucao_efetiva,
    'atrasado' AS estado_emprestimo
  FROM recursos_ativos r
  OFFSET 8000 LIMIT 4000
),
cnt AS (
  SELECT GREATEST(COUNT(*),1) AS m FROM concl_candidates
),
emprestimos_concluidos AS (
  SELECT
    (SELECT ID_utilizador FROM Utilizador ORDER BY random() LIMIT 1) AS u_id,
    (SELECT ID_utilizador FROM Funcionario WHERE pode_emprestar = TRUE ORDER BY random() LIMIT 1) AS f_id,
    c.ID_recurso AS r_id,
    d.emprestimo_date,
    CASE WHEN random() < 0.7 THEN (d.emprestimo_date + (floor(random() * 14)::int))::date
         ELSE (d.emprestimo_date + (15 + floor(random() * 30)::int))::date
    END AS data_devolucao_efetiva,
    CASE WHEN random() < 0.7 THEN 'concluído' ELSE 'concluído com atraso' END AS estado_emprestimo
  FROM generate_series(1,28000) gs
  CROSS JOIN LATERAL (SELECT (CURRENT_DATE - (floor(random() * 730)::int))::date AS emprestimo_date) d
  CROSS JOIN cnt
  JOIN concl_candidates c ON c.rn = ((gs - 1) % cnt.m) + 1
)

INSERT INTO Emprestimo (
  ID_utilizador, ID_funcionario, ID_recurso,
  data_emprestimo, data_devolucao_efetiva, estado_emprestimo
)
SELECT u_id, f_id, r_id, emprestimo_date, data_devolucao_efetiva, estado_emprestimo FROM emprestimos_em_curso
UNION ALL
SELECT u_id, f_id, r_id, emprestimo_date, data_devolucao_efetiva, estado_emprestimo FROM emprestimos_atrasados
UNION ALL
SELECT u_id, f_id, r_id, emprestimo_date, data_devolucao_efetiva, estado_emprestimo FROM emprestimos_concluidos;

COMMIT;

-- cleanup
DROP TABLE IF EXISTS concl_candidates;
DROP TABLE IF EXISTS recursos_ativos;




-- 3. (Optional) Re-enable triggers

ALTER TABLE Emprestimo ENABLE TRIGGER trigger_data_devolucao;
ALTER TABLE Emprestimo ENABLE TRIGGER trigger_atualizar_disponibilidade;


-- 4. Fix any wrong records with your UPDATEs if needed
UPDATE Emprestimo
SET data_devolucao_efetiva = NULL,
    data_emprestimo = CURRENT_DATE - (random() * 14)::int
WHERE estado_emprestimo = 'em curso'
  AND (data_devolucao_efetiva IS NOT NULL OR data_emprestimo < CURRENT_DATE - INTERVAL '15 days');

UPDATE Emprestimo
SET data_devolucao_efetiva = data_emprestimo + INTERVAL '16 days' + ((random() * 30)::int || ' days')::interval
WHERE estado_emprestimo = 'concluído com atraso'
  AND (data_devolucao_efetiva IS NULL OR data_devolucao_efetiva <= data_emprestimo + INTERVAL '15 days');

UPDATE Recurso
SET disponibilidade = 'emprestado'
WHERE ID_recurso IN (
    SELECT ID_recurso
    FROM Emprestimo
    WHERE estado_emprestimo IN ('em curso', 'atrasado')
);


UPDATE Emprestimo
SET data_devolucao_efetiva = data_emprestimo + (floor(random() * 14)::int || ' days')::interval
WHERE estado_emprestimo = 'concluído'
  AND (data_devolucao_efetiva IS NULL OR data_devolucao_efetiva > data_emprestimo + INTERVAL '15 days');





CREATE TEMP TABLE IF NOT EXISTS tmp_bad_recs AS
SELECT DISTINCT r.id_recurso
FROM bd048_schema.Recurso r
JOIN bd048_schema.Emprestimo e ON e.id_recurso = r.id_recurso
WHERE r.disponibilidade = 'disponível'
  AND e.estado_emprestimo IN ('em curso','atrasado');

DO $$
DECLARE
  batch_size INT := 5000;
  rows_affected INT;
BEGIN
  LOOP
    CREATE TEMP TABLE tmp_batch ON COMMIT DROP AS
    SELECT id_recurso FROM tmp_bad_recs LIMIT batch_size;

    EXIT WHEN NOT EXISTS (SELECT 1 FROM tmp_batch);

    UPDATE bd048_schema.Recurso r
    SET disponibilidade = 'emprestado'
    FROM tmp_batch b
    WHERE r.id_recurso = b.id_recurso
      AND r.disponibilidade = 'disponível';

    GET DIAGNOSTICS rows_affected = ROW_COUNT;
    RAISE NOTICE 'Updated % rows in this batch', rows_affected;

    DELETE FROM tmp_bad_recs t USING tmp_batch b WHERE t.id_recurso = b.id_recurso;

    DROP TABLE IF EXISTS tmp_batch;

    PERFORM pg_sleep(0.05);
  END LOOP;
END$$;



-- Set to 'disponível' for resources whose loans are returned
-- (Only if they have NO active loans)
UPDATE bd048_schema.Recurso
SET disponibilidade = 'disponível'
WHERE disponibilidade = 'emprestado'
  AND NOT EXISTS (
    SELECT 1 FROM bd048_schema.Emprestimo e
    WHERE e.ID_recurso = Recurso.ID_recurso
      AND e.estado_emprestimo IN ('em curso', 'atrasado')
  );

-- Cleanup temp tables
DROP TABLE IF EXISTS tmp_bad_recs;

END;

ROLLBACK;

-- Delete duplicate emprestimos, keeping only the one with the lowest ID
DELETE FROM bd048_schema.Emprestimo e1
USING bd048_schema.Emprestimo e2
WHERE e1.ID_emprestimo > e2.ID_emprestimo  -- Keep the first one
  AND e1.ID_recurso = e2.ID_recurso
  AND e1.ID_utilizador = e2.ID_utilizador
  AND e1.data_emprestimo = e2.data_emprestimo
  AND e1.data_devolucao_prevista = e2.data_devolucao_prevista;
  



-- TABELA MULTA

SELECT setval(
    'bd048_schema.multa_id_multa_seq',
    COALESCE((SELECT MAX(ID_multa) FROM bd048_schema.Multa), 1),
    TRUE
);

WITH multas_geradas AS (
    SELECT
        e.ID_emprestimo,
        -- Data de aplicação aleatória entre data_emprestimo + 1 e hoje
        e.data_emprestimo + 1 + (floor(random() * (GREATEST(1, CURRENT_DATE - e.data_emprestimo)))::int) AS data_aplicacao,
        e.estado_emprestimo
    FROM bd048_schema.Emprestimo e
    WHERE e.estado_emprestimo IN ('atrasado', 'concluído com atraso')
)
INSERT INTO bd048_schema.Multa (ID_emprestimo, data_aplicacao, estado_multa, data_pagamento)
SELECT
    ID_emprestimo,
    data_aplicacao,
    CASE 
        WHEN estado_emprestimo = 'atrasado' THEN 'pendente'
        WHEN estado_emprestimo = 'concluído com atraso' THEN 'pago'
    END AS estado_multa,
    CASE
        WHEN estado_emprestimo = 'concluído com atraso' THEN
            data_aplicacao + 1 + (floor(random() * (GREATEST(1, CURRENT_DATE - data_aplicacao - 1)))::int)
        ELSE NULL
    END AS data_pagamento
FROM multas_geradas;


BEGIN;
UPDATE Multa
SET data_pagamento = data_aplicacao + INTERVAL '1 day'
WHERE estado_multa = 'pago'
  AND data_pagamento <= data_aplicacao
RETURNING ID_multa, ID_emprestimo, data_aplicacao, data_pagamento;
-- verify returned rows are correct
COMMIT;

ROLLBACK;



-- TABELA RESERVAS


DROP TABLE IF EXISTS recursos_emprestados;


-- Create ~50 distinct active reservas per recurso that is currently 'emprestado'.
BEGIN;

-- materialize emprestado recursos with current borrower + last emprestimo date
CREATE TEMP TABLE recursos_emprestados AS
SELECT r.ID_recurso,
       le.ID_utilizador AS current_borrower,
       le.data_emprestimo AS last_emprestimo
FROM Recurso r
JOIN LATERAL (
  SELECT e.ID_utilizador, e.data_emprestimo
  FROM Emprestimo e
  WHERE e.ID_recurso = r.ID_recurso
  ORDER BY e.data_emprestimo DESC
  LIMIT 1
) le ON TRUE
WHERE r.disponibilidade = 'emprestado';

-- Insert up to 50 distinct reservas per recurso (skips users that already have an active reserva for that recurso)
INSERT INTO Reserva (
  ID_utilizador,
  ID_funcionario,
  ID_recurso,
  estado_reserva,
  data_reserva
)
SELECT
  u.ID_utilizador,
  f.ID_utilizador,
  re.ID_recurso,
  'ativa',
  (re.last_emprestimo + INTERVAL '4 days') + ((floor(random()*30)::int) || ' days')::interval
FROM recursos_emprestados re
CROSS JOIN LATERAL (
  -- pick 50 distinct random users different from current borrower
  SELECT ID_utilizador
  FROM Utilizador
  WHERE ID_utilizador <> re.current_borrower
  ORDER BY random()
  LIMIT 50
) u
CROSS JOIN LATERAL (
  -- pick a random bibliotecário for each reserva
  SELECT ID_utilizador
  FROM Funcionario
  WHERE pode_emprestar = TRUE
  ORDER BY random()
  LIMIT 1
) f
WHERE NOT EXISTS (
  SELECT 1 FROM Reserva r2
  WHERE r2.ID_recurso = re.ID_recurso
    AND r2.ID_utilizador = u.ID_utilizador
    AND r2.estado_reserva = 'ativa'
);

COMMIT;

DROP TABLE IF EXISTS recursos_emprestados;







BEGIN;
WITH cancelled AS (
  UPDATE bd048_schema.Reserva
  SET estado_reserva = 'cancelada'
  WHERE estado_reserva = 'ativa'
    AND data_limite_levantamento IS NOT NULL
  RETURNING id_reserva
)
SELECT COUNT(*) AS cancelled_count FROM cancelled;
COMMIT;

-- 2) OR: cancel only if the deadline has passed (expired)
BEGIN;
WITH cancelled AS (
  UPDATE bd048_schema.Reserva
  SET estado_reserva = 'cancelada'
  WHERE estado_reserva = 'ativa'
    AND data_limite_levantamento < CURRENT_DATE
  RETURNING id_reserva
)
SELECT COUNT(*) AS cancelled_count FROM cancelled;
COMMIT;



