
SET search_path TO bd048_schema, public;


--VIEWS

-- VIEW 1
CREATE OR REPLACE VIEW emprestimos_total AS
SELECT Recurso.titulo, CONCAT(Utilizador.primeiro_nome, ' ', Utilizador.ultimo_nome) AS utilizador, Emprestimo.data_devolucao_prevista,
    CASE 
        WHEN CURRENT_DATE > Emprestimo.data_devolucao_prevista THEN CURRENT_DATE - Emprestimo.data_devolucao_prevista
        ELSE 0
    END AS dias_atraso
FROM Emprestimo 
JOIN Recurso ON Emprestimo.ID_recurso = Recurso.ID_recurso
JOIN Utilizador ON Emprestimo.ID_utilizador = Utilizador.ID_utilizador
WHERE Emprestimo.estado_emprestimo IN ('em curso', 'atrasado')
ORDER BY dias_atraso DESC;

SELECT * FROM emprestimos_total;



--VIEW 2
CREATE OR REPLACE VIEW ranking_utilizadores AS
SELECT Utilizador.ID_utilizador, CONCAT(Utilizador.primeiro_nome, ' ', Utilizador.ultimo_nome) AS nome_utilizador,
    COUNT(Emprestimo.ID_emprestimo) AS total_emprestimos,
    RANK() OVER (ORDER BY COUNT(Emprestimo.ID_emprestimo) DESC) AS posicao_ranking
FROM Utilizador
LEFT JOIN Emprestimo ON Utilizador.ID_utilizador = Emprestimo.ID_utilizador
GROUP BY Utilizador.ID_utilizador, Utilizador.primeiro_nome, Utilizador.segundo_nome, Utilizador.ultimo_nome
ORDER BY total_emprestimos DESC

SELECT*FROM ranking_utilizadores;




--VIEW 3 
CREATE OR REPLACE VIEW emprestimos_por_categoria AS
SELECT Categoria.nome_categoria, COUNT(Emprestimo.ID_emprestimo) AS total_emprestimos
FROM Emprestimo 
JOIN Recurso ON Emprestimo.ID_recurso = Recurso.ID_recurso
LEFT JOIN Categoria ON Recurso.ID_categoria = Categoria.ID_categoria
GROUP BY Categoria.nome_categoria
ORDER BY total_emprestimos DESC;

SELECT*FROM emprestimos_por_categoria;



-- VIEW 4
CREATE OR REPLACE VIEW estatisticas_recursos AS
SELECT 'Livros' AS tipo,
    COUNT(Livro.ID_recurso) FILTER (WHERE Recurso.disponibilidade = 'disponível') AS disponiveis,
    COUNT(Livro.ID_recurso) AS total
FROM Livro
JOIN Recurso ON Livro.ID_recurso = Recurso.ID_recurso
UNION ALL
SELECT 'EBooks' AS tipo,
    COUNT(EBook.ID_recurso) FILTER (WHERE Recurso.disponibilidade = 'disponível') AS disponiveis,
    COUNT(EBook.ID_recurso) AS total
FROM EBook
JOIN Recurso ON EBook.ID_recurso = Recurso.ID_recurso
UNION ALL
SELECT 'Periódicos' AS tipo,
    COUNT(Periodico.ID_recurso) FILTER (WHERE Recurso.disponibilidade = 'disponível') AS disponiveis,
    COUNT(Periodico.ID_recurso) AS total
FROM Periodico
JOIN Recurso ON Periodico.ID_recurso = Recurso.ID_recurso;

SELECT*FROM estatisticas_recursos;




-- VIEW 5
CREATE OR REPLACE VIEW utilizadores_maior_atraso_5dias AS
SELECT Utilizador.ID_utilizador, CONCAT(Utilizador.primeiro_nome, ' ', Utilizador.ultimo_nome) AS nome_utilizador,
    MAX(Emprestimo.data_devolucao_efetiva - Emprestimo.data_devolucao_prevista) AS maior_atraso_dias
FROM Emprestimo
JOIN Utilizador ON Emprestimo.ID_utilizador = Utilizador.ID_utilizador
WHERE Emprestimo.data_devolucao_efetiva IS NOT NULL
  AND (Emprestimo.data_devolucao_efetiva - Emprestimo.data_devolucao_prevista) >= 5
  AND (Emprestimo.estado_emprestimo = 'concluído com atraso' OR Emprestimo.estado_emprestimo = 'atrasado')
GROUP BY Utilizador.ID_utilizador, Utilizador.primeiro_nome, Utilizador.segundo_nome, Utilizador.ultimo_nome
ORDER BY maior_atraso_dias DESC;

SELECT*FROM utilizadores_maior_atraso_5dias





-- VIEW 6
CREATE OR REPLACE VIEW bibliotecarios_atividade AS
SELECT Funcionario.ID_utilizador, CONCAT(Utilizador.primeiro_nome, ' ', Utilizador.ultimo_nome) AS nome_funcionario, Funcionario.cargo,
    COUNT(DISTINCT Emprestimo.ID_emprestimo) AS total_emprestimos,
    COUNT(DISTINCT Reserva.ID_reserva) AS total_reservas
FROM Funcionario
JOIN Utilizador ON Funcionario.ID_utilizador = Utilizador.ID_utilizador
LEFT OUTER JOIN Emprestimo ON Emprestimo.ID_funcionario = Funcionario.ID_utilizador
LEFT OUTER JOIN Reserva ON Reserva.ID_funcionario = Funcionario.ID_utilizador
WHERE Funcionario.cargo = 'Bibliotecario'
GROUP BY Funcionario.ID_utilizador, Utilizador.primeiro_nome, Utilizador.segundo_nome, Utilizador.ultimo_nome, Funcionario.cargo
ORDER BY total_emprestimos DESC, total_reservas DESC;

SELECT*FROM bibliotecarios_atividade;





--INTERROGAÇOES


-- INTERROGACAO 1
--Seleciona o título, o autor, o estado e o tipo do recurso de todos disponíveis
SELECT Recurso.titulo, CONCAT(Autor.primeiro_nome_autor, ' ', Autor.ultimo_nome_autor) As nome_autor,
    CASE 
        WHEN Livro.ID_recurso IS NOT NULL THEN 'Livro'  
        WHEN EBook.ID_recurso IS NOT NULL THEN 'EBook'  
        WHEN Periodico.ID_recurso IS NOT NULL THEN 'Periodico' 
    END AS tipo_recurso FROM Recurso
LEFT OUTER JOIN Livro ON Recurso.ID_recurso = Livro.ID_recurso 
LEFT OUTER JOIN EBook ON Recurso.ID_recurso = EBook.ID_recurso 
LEFT OUTER JOIN Periodico ON Recurso.ID_recurso = Periodico.ID_recurso 
JOIN Autor ON Recurso.ID_autor = Autor.ID_autor 
WHERE Recurso.disponibilidade = 'disponível' 
ORDER BY Recurso.titulo;


--INTERROGAÇAO 2
--Recursos disponiveis por categoria 
SELECT Categoria.nome_categoria, COUNT(Recurso.ID_recurso) AS disponiveis
FROM Recurso 
JOIN Categoria ON Recurso.ID_categoria = Categoria.ID_categoria
WHERE Recurso.disponibilidade = 'disponível'
GROUP BY Categoria.nome_categoria;


--INTERROGAÇAO 3
--Mostra recursos mais emprestados
SELECT Recurso.titulo, COUNT(Emprestimo.ID_emprestimo) AS total_emprestimos
FROM Recurso
JOIN Emprestimo ON Recurso.ID_recurso = Emprestimo.ID_recurso
GROUP BY Recurso.titulo
ORDER BY total_emprestimos DESC

--INTERROGAÇAO 4
--Multas pendentes e o respetivo utilizador
SELECT Multa.ID_multa, CONCAT(Utilizador.primeiro_nome, ' ', Utilizador.ultimo_nome) AS utilizador, Multa.valor, Multa.data_aplicacao
FROM Multa 
JOIN Emprestimo ON Multa.ID_emprestimo = Emprestimo.ID_emprestimo
JOIN Utilizador ON Emprestimo.ID_utilizador = Utilizador.ID_utilizador
WHERE Multa.estado_multa = 'pendente';


--INTERROGAÇAO 5
SELECT Utilizador.id_utilizador, CONCAT(Utilizador.primeiro_nome, ' ', Utilizador.ultimo_nome) AS nome, 
COUNT(*) AS total_atrasos, RANK() OVER (ORDER BY COUNT(*) DESC) AS ranking_atrasados
FROM Emprestimo 
JOIN Utilizador ON Utilizador.id_utilizador = Emprestimo.id_utilizador
WHERE Emprestimo.data_devolucao_efetiva IS NOT NULL
  AND Emprestimo.data_devolucao_efetiva > Emprestimo.data_devolucao_prevista
GROUP BY Utilizador.id_utilizador, Utilizador.primeiro_nome, Utilizador.ultimo_nome;


--INTERROGAÇAO 6
--listar os recursos emprestados e quem os tem emprestado
SELECT Recurso.titulo, CONCAT(Utilizador.primeiro_nome, ' ',  Utilizador.ultimo_nome) AS nome_utilizador, 
Emprestimo.data_emprestimo, Emprestimo.data_devolucao_prevista
FROM Emprestimo 
JOIN Recurso ON Emprestimo.ID_recurso = Recurso.ID_recurso
JOIN Utilizador ON Emprestimo.ID_utilizador = Utilizador.ID_utilizador
WHERE Emprestimo.estado_emprestimo = 'em curso'
ORDER BY Emprestimo.data_emprestimo DESC;



-- INTERROGAÇAO 7
-- Listar todos os livros e eBooks com o nome do autor, editora e categoria
SELECT Recurso.titulo, CONCAT(Autor.primeiro_nome_autor, ' ', Autor.ultimo_nome_autor) AS autor,
Editora.nome_editora, Categoria.nome_categoria, Recurso.disponibilidade
FROM Recurso 
LEFT OUTER JOIN Autor ON Recurso.ID_autor = Autor.ID_autor
LEFT OUTER JOIN Editora ON Recurso.ID_editora = Editora.ID_editora
LEFT OUTER JOIN Categoria ON Recurso.ID_categoria = Categoria.ID_categoria
WHERE Recurso.estado = 'Bom'
ORDER BY Recurso.titulo;




--INTERROGAÇAO 8
--Último empréstimo de cada utilizador e quantos dias desde a data_emprestimo do ultimo emprestimo
SELECT Utilizador.ID_utilizador, CONCAT(Utilizador.primeiro_nome, ' ', Utilizador.ultimo_nome) AS nome_utilizador,
    MAX(Emprestimo.data_emprestimo) AS ultimo_emprestimo,
    CURRENT_DATE - MAX(Emprestimo.data_emprestimo) AS dias_desde_ultimo_emprestimo
FROM Utilizador
LEFT OUTER JOIN Emprestimo ON Utilizador.ID_utilizador = Emprestimo.ID_utilizador
GROUP BY Utilizador.ID_utilizador, Utilizador.primeiro_nome, Utilizador.ultimo_nome
ORDER BY dias_desde_ultimo_emprestimo DESC;


-- INTERROGAÇAO 9
--Recursos com maior número de reservas pendentes
SELECT Recurso.titulo, COUNT(Reserva.ID_reserva) AS total_reservas_pendentes
FROM Recurso
JOIN Reserva ON Recurso.ID_recurso = Reserva.ID_recurso
WHERE Reserva.estado_reserva = 'ativa'
GROUP BY Recurso.ID_recurso, Recurso.titulo
ORDER BY total_reservas_pendentes DESC




-- INTERROGAÇAO 10
--Lista completa de utilizadores e todas as suas atividades
--Só utilizadores que têm emprestimos ou reservas 
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
-- Utilizadores com reservas não levantadas após o prazo
SELECT Utilizador.ID_utilizador, CONCAT(Utilizador.primeiro_nome, ' ', Utilizador.ultimo_nome) AS nome_utilizador, Reserva.ID_reserva,
Reserva.data_reserva, Reserva.data_limite_levantamento, Reserva.data_levantamento
FROM Utilizador
JOIN Reserva ON Utilizador.ID_utilizador = Reserva.ID_utilizador
WHERE Reserva.data_levantamento IS NULL        
  AND Reserva.data_limite_levantamento < CURRENT_DATE  
ORDER BY Reserva.data_limite_levantamento ASC;


-- INTERROGAÇAO 12
-- Recursos nunca emprestados ou reservados
SELECT Recurso.titulo, CONCAT(Autor.primeiro_nome_autor, ' ', Autor.ultimo_nome_autor) AS autor, Categoria.nome_categoria
FROM Recurso 
LEFT OUTER JOIN Emprestimo ON Recurso.ID_recurso = Emprestimo.ID_recurso
LEFT OUTER JOIN Reserva ON Recurso.ID_recurso = Reserva.ID_recurso
LEFT OUTER JOIN Autor ON Recurso.ID_autor = Autor.ID_autor
LEFT OUTER JOIN Categoria ON Recurso.ID_categoria = Categoria.ID_categoria
WHERE Emprestimo.ID_emprestimo IS NULL AND Reserva.ID_reserva IS NULL
ORDER BY Recurso.titulo;



--INTERROGAÇAO 13
-- Total de emprestimos de cada idioma e a percentagem de emprestimos
SELECT Recurso.idioma, COUNT(Emprestimo.id_emprestimo) AS total_emprestimos,
    ROUND(100.0 * COUNT(Emprestimo.id_emprestimo) / SUM(COUNT(Emprestimo.id_emprestimo)) OVER (), 2) AS percentagem_emprestimos
FROM Emprestimo
JOIN Recurso ON Emprestimo.ID_recurso = Recurso.ID_recurso
GROUP BY Recurso.idioma
ORDER BY total_emprestimos DESC;


--INTERROGAÇAO 14
--emprestimos em cada mes
SELECT TO_CHAR(date_trunc('month', data_emprestimo), 'YYYY-MM') AS mes, COUNT(*) AS total_emprestimos
FROM Emprestimo
WHERE data_emprestimo >= (CURRENT_DATE - INTERVAL '12 months')
GROUP BY date_trunc('month', data_emprestimo)
ORDER BY mes;


--INTERROGAÇAO 15
--emprestimos por autor
SELECT Autor.ID_autor, CONCAT(Autor.primeiro_nome_autor, ' ',Autor.ultimo_nome_autor )AS nome_autor,
    COUNT(Emprestimo.ID_emprestimo) AS total_emprestimos
FROM Autor
JOIN Recurso ON Autor.ID_autor = Recurso.ID_autor
JOIN Emprestimo ON Recurso.ID_recurso = Emprestimo.ID_recurso
GROUP BY Autor.ID_autor, nome_autor
ORDER BY total_emprestimos DESC;




--INTERROGAÇAO 16
--
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
--Ve os cursos dos alunos com mais empréstimos e faz a percentagem--
SELECT Aluno.curso,
    COUNT(Emprestimo.ID_emprestimo) AS total_emprestimos,
    CONCAT(ROUND((COUNT(Emprestimo.ID_emprestimo)::DECIMAL / (SELECT COUNT(*) FROM Emprestimo)) * 100, 2),' %') AS percentagem_total
FROM Emprestimo
JOIN Utilizador ON Emprestimo.ID_utilizador = Utilizador.ID_utilizador
JOIN Aluno ON Aluno.ID_utilizador = Utilizador.ID_utilizador
GROUP BY Aluno.curso
ORDER BY total_emprestimos DESC;


--INTERROGAÇAO 18
--Salários medios dos funcionários por cargo
SELECT cargo,
    ROUND(AVG(salario), 2) AS salario_medio,
    ROUND(MIN(salario), 2) AS salario_minimo,
    ROUND(MAX(salario), 2) AS salario_maximo,
    COUNT(*) AS numero_funcionarios
FROM Funcionario
GROUP BY cargo
ORDER BY salario_medio DESC;




--INTERROGAÇAO 19
--utilizadores por faixas de idade
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
--recurso com mais emprestimos de cada tipo de rescurso e o total de emprestimos
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
--Percentagem de renovação de empréstimos por tipo de utilizador--
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
-- Igual à 20 mas para os recursos
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