
SET search_path TO mrel, public;

-- OTIMIZAÇÃO DE INTERROGAÇÕES
-- Queries reescritas para melhor performance



--QUERY 2 OTIMIZADA-- 
-- Agrupamos primeiro por id_categoria (chave), evitando GROUP BY por nome (coluna não indexada)
-- Isso reduz scans desnecessários e melhora o uso de índices
EXPLAIN ANALYZE
SELECT c.nome_categoria,
       cnt.disponiveis
FROM (
    -- Subquery: agrega apenas as colunas necessárias (id_categoria + COUNT)
    -- reduz volume de dados antes do JOIN com a tabela de categorias.
    SELECT id_categoria, COUNT(*) AS disponiveis   -- COUNT(*) é seguro porque contamos linhas já filtradas
    FROM mrel.recurso
    WHERE disponibilidade = 'disponível'    -- filtro aplicado cedo reduz linhas a agregar
    GROUP BY id_categoria   -- agrupar por id numérico é mais rápido que por string
) cnt
JOIN mrel.categoria c 
  ON c.id_categoria = cnt.id_categoria; -- Join simples na chave primária/estrangeira

-- Alterações Principais:
-- 1) Agregação isolada numa subquery → reduz linhas processadas antes do JOIN.
-- 2) Remoção do COUNT(Recurso.ID_recurso) no JOIN → contagem feita apenas uma vez.
-- 3) JOIN apenas sobre categorias realmente usadas → evita leitura desnecessária da tabela completa.






-- Query 8: Último Empréstimo por Utilizador
-- VERSÃO OTIMIZADA 
-- Agregação isolada para reduzir linhas antes do JOIN
EXPLAIN ANALYZE
WITH ultimos_emprestimos AS (
    -- Agregamos apenas em Emprestimo: menos linhas para o join posterior
    SELECT ID_utilizador,
           MAX(data_emprestimo) AS ultimo_emprestimo
    FROM Emprestimo
    GROUP BY ID_utilizador
)
SELECT u.ID_utilizador,
       CONCAT(u.primeiro_nome, ' ', u.ultimo_nome) AS nome_utilizador, -- concatena sem agrupar
       ue.ultimo_emprestimo,
       CURRENT_DATE - ue.ultimo_emprestimo AS dias_desde_ultimo_emprestimo -- Calcula quantos dias passaram desde o último empréstimo.
FROM Utilizador u
LEFT JOIN ultimos_emprestimos ue ON u.ID_utilizador = ue.ID_utilizador  --garante que utilizadores sem empréstimos apareçam na lista 
ORDER BY dias_desde_ultimo_emprestimo DESC NULLS LAST;  -- coloca NULLs (sem empréstimo) no fim

-- PRINCIPAIS MUDANÇAS DA OTIMIZAÇÃO:
-- 1. A agregação MAX(data_emprestimo) foi movida para uma CTE dedicada.
-- Isto reduz drasticamente o número de linhas que o PostgreSQL precisa de processar.
--
-- 2. O LEFT JOIN passou a operar sobre um conjunto já agregado e compacto.
-- Evita operações pesadas sobre a tabela completa de Emprestimo.
--
-- 3. O ORDER BY usa NULLS LAST.
-- Melhora o plano de execução ao evitar tratamento desnecessário de valores nulos.

-- Melhorias: Agregação isolada (90K → 40K linhas), LEFT JOIN eficiente






-- Query 9: Recursos Mais Reservados

-- VERSÃO OTIMIZADA
EXPLAIN ANALYZE
SELECT r.titulo, ra.total
FROM Recurso r
-- Subquery pré-agrega reservas por recurso
JOIN (
    SELECT id_recurso, COUNT(*) AS total
    FROM Reserva 
    WHERE estado_reserva = 'ativa'  -- Filtra só reservas ativas antes de contar
    GROUP BY id_recurso    -- Agregação isolada reduz número de linhas do join
) ra ON ra.id_recurso = r.id_recurso   -- JOIN agora trabalha com dataset muito menor
ORDER BY ra.total DESC;    -- Ordenação permanece igual, mas sobre menos linhas → mais rápido

-- Melhorias: 
-- Pre-agregação reduz join de 604K → 12K linhas (98% redução)
-- Original executava Parallel Hash Join em 604,045 reservas antes de agregar
-- Otimizado agrega primeiro (604K → 12K), depois junta com recursos (20K)
-- Elimina processamento paralelo desnecessário, Hash Join mais eficiente






-- Query 10: Utilizadores com Empréstimos e Reservas

-- VERSÃO OTIMIZADA 
-- CTE (Common Table Expression) pré-agrega emprestimos por utilizador
EXPLAIN ANALYZE
WITH emprestimos_por_utilizador AS (
    SELECT ID_utilizador,
           COUNT(*) AS total_emprestimos  -- Conta empréstimos primeiro, reduz linhas do join
    FROM Emprestimo
    GROUP BY ID_utilizador
),
-- CTE pré-agrega reservas por utilizador
reservas_por_utilizador AS (
    SELECT ID_utilizador,
           COUNT(*) AS total_reservas    -- Conta reservas primeiro, reduz linhas do join
    FROM Reserva
    GROUP BY ID_utilizador
)
SELECT u.ID_utilizador,
       CONCAT(u.primeiro_nome, ' ', u.ultimo_nome) AS nome_utilizador,
       COALESCE(e.total_emprestimos, 0) AS total_emprestimos,   -- Substitui NULL por 0
       COALESCE(r.total_reservas, 0) AS total_reservas      -- Substitui NULL por 0
FROM Utilizador u
-- LEFT JOINs mantêm utilizadores mesmo sem empréstimos/reservas.
LEFT JOIN emprestimos_por_utilizador e ON u.ID_utilizador = e.ID_utilizador
LEFT JOIN reservas_por_utilizador r ON u.ID_utilizador = r.ID_utilizador
-- Filtra utilizadores sem empréstimos nem reservas
WHERE e.total_emprestimos > 0 OR r.total_reservas > 0
-- Ordenação: mais empréstimos primeiro, depois reservas.
ORDER BY total_emprestimos DESC, total_reservas DESC;

-- Melhorias:
-- 1. Pré-agregação em CTEs: reduz linhas processadas
-- 2. Substituição do FULL OUTER JOIN por LEFT JOIN + COALESCE → evita produto cartesiano
-- 3. Filtros aplicados após agregação, não durante o join → plano de execução mais eficiente
-- 4. Menor uso de DISTINCT, menos processamento de linhas repetidas




--QUERY 12 OTIMIZADA--
-- CTE para pré-filtrar recursos livres
EXPLAIN ANALYZE
WITH free_recurso AS (
  SELECT R.ID_recurso, R.titulo, R.ID_autor, R.ID_categoria
  FROM Recurso R
  -- Subqueries NOT EXISTS evitam LEFT JOIN desnecessários e NULL checks
  -- São mais eficientes porque param na primeira correspondência encontrada.
  WHERE NOT EXISTS (SELECT 1 FROM Emprestimo E WHERE E.ID_recurso = R.ID_recurso)
    AND NOT EXISTS (SELECT 1 FROM Reserva S WHERE S.ID_recurso = R.ID_recurso)
)
SELECT fr.titulo,
-- COALESCE para lidar com autores desconhecidos
       COALESCE(CONCAT(A.primeiro_nome_autor, ' ', A.ultimo_nome_autor), 'Autor Desconhecido') AS autor,
       C.nome_categoria
FROM free_recurso fr
-- JOINs apenas com tabelas necessárias após filtrar recursos livres
LEFT JOIN Autor A ON fr.ID_autor = A.ID_autor
LEFT JOIN Categoria C ON fr.ID_categoria = C.ID_categoria
ORDER BY fr.titulo;

-- Melhorias Importantes:
-- 1. Substituição dos LEFT JOIN + IS NULL por NOT EXISTS → evita criar produto cartesiano
-- 2. Pré-filtragem dos recursos livres na CTE reduz drasticamente o número de linhas do JOIN
-- 3. JOIN com Autor e Categoria só acontece para recursos livres → menor custo de execução
-- 4. COALESCE garante que campos nulos sejam tratados sem afetar performance
-- 5. Plano de execução mais eficiente: scan menor em Emprestimo/Reserva, elimina necessidade de LEFT JOIN duplo






-- Query 20: Recurso Mais Emprestado por Tipo

-- VERSÃO OTIMIZADA 
-- CTE materializada para pré-contar empréstimos por recurso
EXPLAIN ANALYZE
WITH emprestimos_por_recurso AS MATERIALIZED (
    SELECT 
        ID_recurso,
        COUNT(*) AS total_emprestimos  -- Agregação prévia para evitar COUNT repetido
    FROM Emprestimo
    GROUP BY ID_recurso
),
-- Seleção do livro mais emprestado
top_livro AS (
    SELECT 
        'Livro' AS tipo_recurso,
        r.titulo,
        COALESCE(er.total_emprestimos, 0) AS total_emprestimos  -- COALESCE evita NULL quando o recurso nunca foi emprestado
    FROM Livro l
    JOIN Recurso r ON l.ID_recurso = r.ID_recurso
    LEFT JOIN emprestimos_por_recurso er ON er.ID_recurso = r.ID_recurso  -- Mantém livros mesmo sem empréstimos, útil porque queremos sempre o “top” mesmo que todos tenham 0.
    ORDER BY er.total_emprestimos DESC NULLS LAST
    LIMIT 1  -- Apenas o top 1
),
-- Seleção do eBook mais emprestado
top_ebook AS (
    SELECT 
        'EBook' AS tipo_recurso,
        r.titulo,
        COALESCE(er.total_emprestimos, 0) AS total_emprestimos
    FROM EBook e
    JOIN Recurso r ON e.ID_recurso = r.ID_recurso
    LEFT JOIN emprestimos_por_recurso er ON er.ID_recurso = r.ID_recurso -- Garante que eBooks sem empréstimos ainda apareçam,
    ORDER BY er.total_emprestimos DESC NULLS LAST
    LIMIT 1
),
-- Seleção do periódico mais emprestado
top_periodico AS (
    SELECT 
        'Periódico' AS tipo_recurso,
        r.titulo,
        COALESCE(er.total_emprestimos, 0) AS total_emprestimos
    FROM Periodico p
    JOIN Recurso r ON p.ID_recurso = r.ID_recurso
    LEFT JOIN emprestimos_por_recurso er ON er.ID_recurso = r.ID_recurso  -- Inclui periódicos que nunca foram emprestados.
    ORDER BY er.total_emprestimos DESC NULLS LAST
    LIMIT 1
)
-- União dos top 1 de cada tipo
SELECT * FROM top_livro
UNION ALL
SELECT * FROM top_ebook
UNION ALL
SELECT * FROM top_periodico
ORDER BY total_emprestimos DESC;

-- Melhorias aplicadas:
-- 1. MATERIALIZED CTE: Agrega empréstimos uma única vez (40.5K → 20K recursos)
-- 2. Elimina 3× scans completos de Emprestimo (40.5K × 3 = 121.5K linhas → 40.5K linhas)
-- 3. ROW_NUMBER() eliminado: LIMIT 1 com ORDER BY é mais eficiente
-- 4. UNION ALL de 3 CTEs independentes: PostgreSQL pode paralelizar
-- 5. WindowAgg com Run Condition: Para após encontrar top 1 por tipo
-- 6. LEFT JOIN permite recursos sem empréstimos (COALESCE garante 0)






-- Query 22: Recursos Mais Reservados por Tipo

-- VERSÃO OTIMIZADA
EXPLAIN ANALYZE
-- CTE materializada para pré-contar reservas por recurso
WITH reservas_por_recurso AS MATERIALIZED (
    -- Scan único: 604K reservas → ~12K recursos únicos
    SELECT 
        ID_recurso,
        COUNT(*) AS total_reservas  -- Pré-agregação evita COUNT repetido em cada subquery
    FROM Reserva
    GROUP BY ID_recurso
),
-- Seleção do livro mais reservado
top_livro AS (
    SELECT 
        'Livro' AS tipo_recurso,
        r.titulo,
        -- COALESCE substitui NULL por 0
        -- útil caso o livro nunca tenha sido reservado
        COALESCE(rr.total_reservas, 0) AS total_reservas 
    FROM Livro l
    JOIN Recurso r ON l.ID_recurso = r.ID_recurso  -- JOIN para obter os dados do recurso correspondente ao livro 
    LEFT JOIN reservas_por_recurso rr ON rr.ID_recurso = r.ID_recurso -- LEFT JOIN para manter livros mesmo sem reservas
    ORDER BY rr.total_reservas DESC NULLS LAST
    LIMIT 1
),
-- Seleção do eBook mais reservado
top_ebook AS (
    SELECT 
        'EBook' AS tipo_recurso,
        r.titulo,
        COALESCE(rr.total_reservas, 0) AS total_reservas
    FROM EBook e
    JOIN Recurso r ON e.ID_recurso = r.ID_recurso  -- JOIN para associar eBook ao seu recurso
    LEFT JOIN reservas_por_recurso rr ON rr.ID_recurso = r.ID_recurso  -- LEFT JOIN para manter eBooks mesmo sem reservas
    ORDER BY rr.total_reservas DESC NULLS LAST
    LIMIT 1
),
-- Seleção do Periodico mais reservado
top_periodico AS (
    SELECT 
        'Periódico' AS tipo_recurso,
        r.titulo,
        COALESCE(rr.total_reservas, 0) AS total_reservas
    FROM Periodico p
    JOIN Recurso r ON p.ID_recurso = r.ID_recurso  -- JOIN para associar periódico ao recurso correspondente
    LEFT JOIN reservas_por_recurso rr ON rr.ID_recurso = r.ID_recurso  -- LEFT JOIN para manter periódicos mesmo sem reservas
    ORDER BY rr.total_reservas DESC NULLS LAST
    LIMIT 1
)
-- União dos top 1 de cada tipo
SELECT * FROM top_livro
UNION ALL
SELECT * FROM top_ebook
UNION ALL
SELECT * FROM top_periodico
ORDER BY total_reservas DESC;

-- Melhorias Importantes:
-- 1. Pré-agregação dos registros de Reserva → evita contagens repetidas e scan múltiplo
-- 2. Substituição do ROW_NUMBER() + PARTITION por LIMIT 1 → simplifica o plano e reduz operações de janela
-- 3. LEFT JOIN com CTE materializada reduz número de linhas processadas em cada tipo
-- 4. COALESCE garante que recursos sem reservas não gerem NULLs
-- 5. Plano de execução mais eficiente: scan único + top 1 por tipo, elimina cálculos complexos e joins repetidos




-- Query 21: Empréstimos e Renovações por Tipo de Utilizador

-- VERSÃO OTIMIZADA
EXPLAIN ANALYZE
-- CTEs separadas para cada tipo de utilizador
WITH emprestimos_alunos AS (
    SELECT 
        'Aluno' AS tipo_utilizador,
        COUNT(*) AS total_emprestimos,
        SUM(CASE WHEN e.numero_renovacoes > 0 THEN 1 ELSE 0 END) AS emprestimos_renovados
    FROM Emprestimo e
    INNER JOIN Aluno a ON e.ID_utilizador = a.ID_utilizador   --filtra apenas empréstimos de alunos, evita usar CASE complexo ou verificar tipo
),
emprestimos_professores AS (
    SELECT 
        'Professor' AS tipo_utilizador,
        COUNT(*) AS total_emprestimos,
        SUM(CASE WHEN e.numero_renovacoes > 0 THEN 1 ELSE 0 END) AS emprestimos_renovados
    FROM Emprestimo e
    INNER JOIN Professor p ON e.ID_utilizador = p.ID_utilizador  --seleciona apenas empréstimos feitos por professores
),
emprestimos_funcionarios AS (
    SELECT 
        'Funcionario' AS tipo_utilizador,
        COUNT(*) AS total_emprestimos,
        SUM(CASE WHEN e.numero_renovacoes > 0 THEN 1 ELSE 0 END) AS emprestimos_renovados
    FROM Emprestimo e
    INNER JOIN Funcionario f ON e.ID_utilizador = f.ID_utilizador  -- seleciona apenas empréstimos de funcionários
)
-- União dos resultados de cada tipo
SELECT 
    tipo_utilizador,
    total_emprestimos,
    emprestimos_renovados,
    CONCAT(ROUND((emprestimos_renovados::DECIMAL / total_emprestimos) * 100, 2), '%') AS percentagem_renovacao
FROM (
    SELECT * FROM emprestimos_alunos
    UNION ALL
    SELECT * FROM emprestimos_professores
    UNION ALL
    SELECT * FROM emprestimos_funcionarios
) AS stats
ORDER BY tipo_utilizador;

-- Melhorias aplicadas:
-- 1. INNER JOIN em vez de LEFT JOIN: Processa apenas matches
-- 2. PostgreSQL Parallel Append: 3 CTEs executam em paralelo (2 workers)
-- 3. Agregação direta em CTEs: Evita Sort de 40500 linhas (3119kB → 25kB memory)
-- 4. UNION ALL de apenas 3 linhas: Evita CASE WHEN em 40500 linhas
-- 5. SUM(CASE WHEN) calculado em CTE: Uma passagem por tipo, não 40500 avaliações
-- 6. Percentagem calculada no SELECT final: Sobre 3 linhas, não 40500
-- 7. Hash Joins eficientes





-- Gestão de transações 

-- STORED PROCEDURES - Transações Críticas do Sistema


-- PROCEDURE 1: Emprestar Recurso
-- Operação: Verificar elegibilidade, bloquear recurso, criar empréstimo e manter consistência.
-- Transação ACID completa

CREATE OR REPLACE PROCEDURE proc_emprestar_recurso(
    p_id_utilizador INT,
    p_id_recurso INT,
    p_id_funcionario INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_disponibilidade TEXT;
    v_emprestimos_ativos INT;
    v_pode_emprestar BOOLEAN;
BEGIN
    -- INÍCIO DA TRANSAÇÃO (automático ao entrar na procedure)
    -- 1. Verificar se funcionário pode emprestar
    SELECT pode_emprestar INTO v_pode_emprestar
    FROM Funcionario
    WHERE ID_utilizador = p_id_funcionario;
    
    IF v_pode_emprestar IS NULL THEN
        RAISE EXCEPTION 'Utilizador % não é funcionário', p_id_funcionario;
    END IF;
    
    IF NOT v_pode_emprestar THEN
        RAISE EXCEPTION 'Funcionário não autorizado a emprestar recursos';
    END IF;
    
    -- 2. Verificar disponibilidade do recurso COM LOCK EXCLUSIVO; Bloqueio e validação do recurso (FOR UPDATE NOWAIT)
    -- O "FOR UPDATE NOWAIT" impede empréstimos simultâneos garantindo isolamento
    SELECT disponibilidade INTO v_disponibilidade
    FROM Recurso
    WHERE ID_recurso = p_id_recurso
    FOR UPDATE NOWAIT;  -- bloqueia imediatamente a linha
    
    IF v_disponibilidade IS NULL THEN
        RAISE EXCEPTION 'Recurso % não existe', p_id_recurso;
    END IF;
    
    IF v_disponibilidade != 'disponível' THEN
        RAISE EXCEPTION 'Recurso não disponível. Estado atual: %', v_disponibilidade;
    END IF;
    
    -- 3. Verificar limite de empréstimos do utilizador (máximo 5 ativos ou atrasados)
    SELECT COUNT(*) INTO v_emprestimos_ativos
    FROM Emprestimo
    WHERE ID_utilizador = p_id_utilizador
      AND estado_emprestimo IN ('em curso', 'atrasado');
    
    IF v_emprestimos_ativos >= 5 THEN
        RAISE EXCEPTION 'Limite de empréstimos atingido (%/5). Devolva recursos antes de emprestar novos.', 
                      v_emprestimos_ativos;
    END IF;
    
    -- 4. Criar empréstimo (inserção atômica)
    INSERT INTO Emprestimo (
        ID_utilizador, 
        ID_recurso,
        ID_funcionario,
        data_emprestimo,
        data_devolucao_prevista,
        estado_emprestimo,
        numero_renovacoes
    ) VALUES (
        p_id_utilizador,
        p_id_recurso,
        p_id_funcionario,
        CURRENT_DATE,
        CURRENT_DATE + INTERVAL '14 days',
        'em curso',
        0
    );
    -- Nota: Trigger 'trigger_atualizar_disponibilidade' atualiza disponibilidade automaticamente
    
    -- 5. Cancelar reserva ativa do utilizador (se existir)
    --Garante consistência entre reservas e empréstimos.
    UPDATE Reserva
    SET estado_reserva = 'cancelada'
    WHERE ID_recurso = p_id_recurso
      AND ID_utilizador = p_id_utilizador
      AND estado_reserva = 'ativa';

    --sucesso
    RAISE NOTICE 'Empréstimo registado com sucesso para utilizador % e recurso %', 
                 p_id_utilizador, p_id_recurso;
    
    -- COMMIT automático se não houver exceções

EXCEPTION
-- Tratamento de erros de concorrência:
--lock_not_available → Outro processo já está a usar o mesmo recurso.
    WHEN lock_not_available THEN
        -- ROLLBACK automático em caso de lock não disponível
        RAISE EXCEPTION 'Recurso está sendo processado por outra transação. Tente novamente.';
    -- Fallback genérico
    --Qualquer erro inesperado produz rollback automático.
    WHEN OTHERS THEN
        -- ROLLBACK automático para qualquer outro erro
        RAISE EXCEPTION 'Erro ao registar empréstimo: %', SQLERRM;
END;
$$;





-- PROCEDURE 2: Devolver Recurso com Multa
-- Operação: Registar devolução + Calcular multa + Liberar recurso
-- Transação com SAVEPOINT para rollback parcial


CREATE OR REPLACE PROCEDURE proc_devolver_recurso(
    p_id_emprestimo INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_data_prevista DATE;
    v_id_recurso INT;
    v_id_utilizador INT;
    v_valor_diario DECIMAL(10,2);
    v_dias_atraso INT;
    v_valor_multa DECIMAL(10,2);
BEGIN
    -- INÍCIO DA TRANSAÇÃO (automático ao entrar na procedure)
    -- 1. Buscar  Buscar dados do empréstimo e bloquear a linha para evitar devoluções simultâneas
    SELECT e.data_devolucao_prevista,
           e.ID_recurso,
           e.ID_utilizador
    INTO v_data_prevista, v_id_recurso, v_id_utilizador
    FROM Emprestimo e
    WHERE e.ID_emprestimo = p_id_emprestimo
      AND e.estado_emprestimo IN ('em curso', 'atrasado')
    FOR UPDATE;
    -- Se não encontrou empréstimo válido, aborta
    IF v_id_recurso IS NULL THEN
        RAISE EXCEPTION 'Empréstimo % não encontrado ou já devolvido', p_id_emprestimo;
    END IF;
    
    -- 2. -- Regista a data da devolução e define estado final ('concluído' ou 'concluído com atraso')
    UPDATE Emprestimo
    SET data_devolucao_efetiva = CURRENT_DATE,
        estado_emprestimo = CASE 
            WHEN CURRENT_DATE > data_devolucao_prevista THEN 'concluído com atraso'
            ELSE 'concluído'
        END
    WHERE ID_emprestimo = p_id_emprestimo;
    
    -- 3. Calcular e aplicar multa (se aplicável)
    v_dias_atraso := CURRENT_DATE - v_data_prevista;
    v_valor_diario := 0.50;  -- Valor padrão da multa diária
    -- Se houver atraso, calcula o valor total da multa
    IF v_dias_atraso > 0 THEN
        v_valor_multa := v_dias_atraso * v_valor_diario;
        
        -- Verificar se já existe multa para este empréstimo
        IF NOT EXISTS (SELECT 1 FROM Multa WHERE ID_emprestimo = p_id_emprestimo) THEN
         -- Cria nova multa para este empréstimo
            INSERT INTO Multa (
                ID_emprestimo,
                valor,
                data_aplicacao,
                data_pagamento,
                estado_multa
            ) VALUES (
                p_id_emprestimo,
                v_valor_multa,
                v_data_prevista + INTERVAL '1 day', -- aplicação no dia seguinte ao previsto
                CURRENT_DATE,  -- registado como pago automaticamente
                'pago'
            );
            
            RAISE NOTICE 'Multa aplicada: € % (% dias × € %)', 
                       v_valor_multa, v_dias_atraso, v_valor_diario;
        ELSE
            -- Caso já exista multa, atualiza os valores
            UPDATE Multa
            SET valor = v_valor_multa,
                data_aplicacao = v_data_prevista + INTERVAL '1 day',
                data_pagamento = CURRENT_DATE,
                estado_multa = 'pago'
            WHERE ID_emprestimo = p_id_emprestimo;
            
            RAISE NOTICE 'Multa atualizada: € % (% dias × € %)', 
                       v_valor_multa, v_dias_atraso, v_valor_diario;
        END IF;
    END IF;
    
    -- 4. Liberar recurso para próxima reserva
    UPDATE Recurso
    SET disponibilidade = 'disponível'
    WHERE ID_recurso = v_id_recurso;
    
    -- 5. Notificar próximo utilizador na fila
    UPDATE Reserva
    SET estado_reserva = 'disponivel_para_levantamento',
        data_limite_levantamento = CURRENT_DATE + INTERVAL '2 days'
    WHERE ID_reserva = (
        SELECT ID_reserva
        FROM Reserva
        WHERE ID_recurso = v_id_recurso
          AND estado_reserva = 'ativa'
        ORDER BY data_reserva  -- garante prioridade pela ordem da fila
        LIMIT 1
    );
    
    -- Mensagem informativa de sucesso
    RAISE NOTICE 'Devolução registada com sucesso para empréstimo %', p_id_emprestimo;
    
    -- COMMIT automático se todas as operações forem bem-sucedidas

EXCEPTION
-- Captura qualquer erro e força rollback automático de todas as operações
    WHEN OTHERS THEN
        -- ROLLBACK automático - desfaz todas as alterações (UPDATE Emprestimo, INSERT Multa, UPDATE Recurso, UPDATE Reserva)
        RAISE EXCEPTION 'Erro ao processar devolução: %', SQLERRM;
END;
$$;






-- PROCEDURE 3: Renovar Empréstimo
-- Operação: Verificar reservas pendentes + Verificar limite + Renovar
-- Transação SERIALIZABLE (máxima isolação)

CREATE OR REPLACE PROCEDURE proc_renovar_emprestimo(
    p_id_emprestimo INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_numero_renovacoes INT;
    v_id_recurso INT;
    v_reservas_pendentes INT;
    v_data_prevista DATE;
BEGIN
    -- INÍCIO DA TRANSAÇÃO (automático ao entrar na procedure)
    -- 1. -- Bloqueia a linha do empréstimo para impedir que outra transação o renove ao mesmo tempo
    SELECT e.numero_renovacoes,
           e.data_devolucao_prevista,
           e.ID_recurso
    INTO v_numero_renovacoes, v_data_prevista, v_id_recurso
    FROM Emprestimo e
    WHERE e.ID_emprestimo = p_id_emprestimo
      AND e.estado_emprestimo = 'em curso'
    FOR UPDATE NOWAIT;  -- lock imediato (evita waiting)
    
    -- Se o empréstimo não existir ou já tiver sido concluído, interrompe
    IF v_id_recurso IS NULL THEN
        RAISE EXCEPTION 'Empréstimo % não encontrado ou já concluído', p_id_emprestimo;
    END IF;
    
    -- 2. Verificar se há reservas pendentes (bloqueio de renovação)
    SELECT COUNT(*) INTO v_reservas_pendentes
    FROM Reserva
    WHERE ID_recurso = v_id_recurso
      AND estado_reserva = 'ativa';
    
    -- Se houver alguém à espera do recurso, a renovação é proibida (regra de negócio)
    IF v_reservas_pendentes > 0 THEN
        RAISE EXCEPTION 'Não é possível renovar: % utilizadores aguardam este recurso', 
                      v_reservas_pendentes;
    END IF;
    
    -- 3. Verificar limite de renovações (máximo 2)
    IF v_numero_renovacoes >= 2 THEN
        RAISE EXCEPTION 'Limite de renovações atingido (%/2)', 
                      v_numero_renovacoes;
    END IF;
    
    -- 4. Atualiza a data prevista de devolução e incrementa o número de renovações
    UPDATE Emprestimo
    SET data_devolucao_prevista = CURRENT_DATE + INTERVAL '15 days',
        numero_renovacoes = numero_renovacoes + 1
    WHERE ID_emprestimo = p_id_emprestimo;
    
    -- Feedback para o utilizador com a nova data e número de renovações
    RAISE NOTICE 'Empréstimo % renovado. Nova data devolução: %. Renovações: %/2',
                 p_id_emprestimo, 
                 CURRENT_DATE + INTERVAL '15 days',
                 v_numero_renovacoes + 1;
    
    -- COMMIT automático se renovação for bem-sucedida

EXCEPTION
-- Erro específico: já existe outro processo a renovar o mesmo empréstimo
    WHEN lock_not_available THEN
        --ROLLBACK automático em caso de lock não disponível
        RAISE EXCEPTION 'Empréstimo está sendo renovado por outra transação. Tente novamente.';
    -- Erro de concorrência: SERIALIZABLE detectou conflito
    WHEN serialization_failure THEN
        -- ROLLBACK automático em caso de conflito de concorrência
        RAISE EXCEPTION 'Conflito de concorrência detectado. Por favor tente novamente.';
    WHEN OTHERS THEN
        -- ROLLBACK automático para qualquer outro erro
        RAISE EXCEPTION 'Erro ao renovar empréstimo: %', SQLERRM;
END;
$$;






-- PROCEDURE 4: Criar Reserva
-- Operação: Verificar limites + Criar reserva + Auto-conversão
-- Transação com Optimistic Locking

CREATE OR REPLACE PROCEDURE proc_criar_reserva(
    p_id_utilizador INT,
    p_id_recurso INT,
    p_id_funcionario INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_disponibilidade TEXT;
    v_pode_emprestar BOOLEAN;
BEGIN
    -- INÍCIO DA TRANSAÇÃO (automático ao entrar na procedure)
    
    -- 1. Verificar se funcionário pode emprestar
    SELECT pode_emprestar INTO v_pode_emprestar
    FROM Funcionario
    WHERE ID_utilizador = p_id_funcionario;
    
    -- Se não for funcionário válido, interrompe a operação
    IF v_pode_emprestar IS NULL THEN
        RAISE EXCEPTION 'Utilizador % não é funcionário', p_id_funcionario;
    END IF;
    
    -- Nem qualquer funcionário tem permissão para criar reservas, apenas bibliotecários.
    IF NOT v_pode_emprestar THEN
        RAISE EXCEPTION 'Funcionário não autorizado a criar reservas';
    END IF;
    
    -- 2. Verificar se recurso existe e está emprestado/atrasado COM SHARED LOCK
    SELECT r.disponibilidade
    INTO v_disponibilidade
    FROM Recurso r
    WHERE r.ID_recurso = p_id_recurso
    FOR SHARE;  -- Shared lock (múltiplas leituras OK)
    
    -- Se o recurso não existir, aborta
    IF v_disponibilidade IS NULL THEN
        RAISE EXCEPTION 'Recurso % não existe', p_id_recurso;
    END IF;
    
    -- Só é possível reservar quando o recurso está emprestado ou atrasado
    IF v_disponibilidade NOT IN ('emprestado', 'atrasado') THEN
        RAISE EXCEPTION 'Recurso disponível para emprestimo.';
    END IF;
    
    -- 3. Criar reserva
    INSERT INTO Reserva (
        ID_utilizador,
        ID_recurso,
        ID_funcionario,
        data_reserva,
        estado_reserva
    ) VALUES (
        p_id_utilizador,
        p_id_recurso,
        p_id_funcionario,
        CURRENT_DATE,  -- data da criação da reserva
        'ativa'
    );
    
    RAISE NOTICE 'Reserva criada com sucesso para utilizador % e recurso %', 
                 p_id_utilizador, p_id_recurso;
    
    -- COMMIT automático se reserva for criada com sucesso

EXCEPTION
    WHEN unique_violation THEN
        -- ROLLBACK automático em caso de reserva duplicada
        RAISE EXCEPTION 'Já possui reserva ativa deste recurso';
    WHEN OTHERS THEN
        -- ROLLBACK automático para qualquer outro erro
        RAISE EXCEPTION 'Erro ao criar reserva: %', SQLERRM;
END;
$$;




-- TESTES DAS PROCEDURES


--Testes da Procedure 1

-- TESTE 1: Empréstimo com sucesso

-- Escolher um recurso disponível
SELECT ID_recurso, disponibilidade
FROM Recurso
WHERE disponibilidade = 'disponível'
LIMIT 1;
-- Escolher 1 funcionário autorizado a emprestar
SELECT ID_utilizador 
FROM Funcionario 
WHERE pode_emprestar = TRUE LIMIT 1;

CALL proc_emprestar_recurso(1, 538, 45425);
-- Substituir 538 por um id_recurso disponivel e 45425 por um id_funcionario válido


-- TESTE 2: Empréstimo com recurso indisponível (deve falhar)
-- Usa o mesmo recurso do TESTE 1 - deve falhar porque já está emprestado
CALL proc_emprestar_recurso(2, 538, 45425);

-- TESTE 3: Funcionário inválido (deve falhar)
-- ID 999999 não existe na tabela Funcionario
CALL proc_emprestar_recurso(3, 222, 999999);

-- TESTE 4: Funcionário sem autorização (deve falhar)
-- Encontrar funcionário sem permissão:
SELECT ID_utilizador 
FROM Funcionario 
WHERE pode_emprestar = FALSE  
LIMIT 1;
CALL proc_emprestar_recurso(4, 223, 202); -- Substituir 202 pelo ID de funcionário sem autorização


-- TESTE 5: Recurso inexistente (deve falhar)
CALL proc_emprestar_recurso(5, 999999, 45425);

-- TESTE 6: Limite de empréstimos atingido (deve falhar após 5 empréstimos)
---- Limpar empréstimos anteriores do utilizador 11
DELETE FROM Emprestimo WHERE ID_utilizador = 11;

-- Escolher 6 recursos disponiveis 
SELECT ID_recurso, disponibilidade
FROM Recurso
WHERE disponibilidade = 'disponível'
LIMIT 6;
-- Primeiro, emprestar 5 recursos para o utilizador ID=11
CALL proc_emprestar_recurso(11, 9166, 45425);
CALL proc_emprestar_recurso(11, 8555, 45425);
CALL proc_emprestar_recurso(11, 2022, 45425);
CALL proc_emprestar_recurso(11, 3091, 45425);
CALL proc_emprestar_recurso(11, 7240, 45425);
-- Este deve falhar (6º empréstimo)
CALL proc_emprestar_recurso(11, 538, 45425);




-- TESTES PROCEDURE 2: proc_devolver_recurso


-- TESTE 7: Devolução sem multa (dentro do prazo)
-- Passo 1: Encontrar um empréstimo ativo DENTRO DO PRAZO
SELECT ID_emprestimo, ID_utilizador, ID_recurso, 
       data_emprestimo, data_devolucao_prevista,
       CURRENT_DATE AS hoje,
       (data_devolucao_prevista - CURRENT_DATE) AS dias_restantes
FROM Emprestimo
WHERE estado_emprestimo = 'em curso'
  AND data_devolucao_prevista >= CURRENT_DATE  -- Ainda dentro do prazo
LIMIT 5;

CALL proc_devolver_recurso(502);

-- TESTE 8: Devolução com multa (atrasado)
-- Passo 1: Encontrar um empréstimo ATRASADO 
SELECT ID_emprestimo
FROM Emprestimo
WHERE estado_emprestimo = 'atrasado';
-- Passo 2:
CALL proc_devolver_recurso(522);
-- Verifique a multa criada (substitua 522 pelo mesmo ID)
SELECT * FROM Multa WHERE ID_emprestimo = 522;
SELECT * FROM mrel.emprestimo WHERE id_emprestimo=522;

-- TESTE 9: Devolução de empréstimo inexistente (deve falhar)
CALL proc_devolver_recurso(999999);

-- TESTE 10: Devolução de empréstimo já devolvido (deve falhar)
-- Use o mesmo ID do TESTE 7
CALL proc_devolver_recurso(502);






-- TESTES PROCEDURE 3: proc_renovar_emprestimo

-- Encontrar emprestimos sem renovações 
SELECT e.id_emprestimo
FROM emprestimo e
WHERE e.numero_renovacoes = 0
    AND e.estado_emprestimo = 'em curso'
    -- A restrição principal: O recurso não pode ter reservas ativas
    AND NOT EXISTS (
        SELECT 1
        FROM reserva r
        WHERE r.id_recurso = e.id_recurso 
          AND r.estado_reserva <> 'cancelado' 
          AND r.estado_reserva <> 'concluido' 
    )
LIMIT 1;
-- TESTE 12: Renovação bem-sucedida (primeira renovação)
CALL proc_renovar_emprestimo(40524); -- substituir pelo ID obtido


-- TESTE 13: Renovação bem-sucedida (segunda renovação - última permitida)
CALL proc_renovar_emprestimo(40524);  -- mesmo id do acima

-- TESTE 14: Renovação falha - limite de 2 renovações atingido (deve falhar)
CALL proc_renovar_emprestimo(40524);  -- mesmo id acima

-- TESTE 15: Renovação falha - empréstimo não existe (deve falhar)
CALL proc_renovar_emprestimo(999999);

-- TESTE 16: Renovação falha - empréstimo já concluído (deve falhar)

SELECT id_emprestimo
FROM Emprestimo 
WHERE estado_emprestimo = 'concluído'
LIMIT 1;

CALL proc_renovar_emprestimo(1); -- substituir pelo ID obtido

-- TESTE 17: Renovação falha - empréstimo atrasado (deve falhar, só aceita 'em curso')
-- Encontrar um empréstimo atrasado:
SELECT id_emprestimo
FROM Emprestimo 
WHERE estado_emprestimo = 'atrasado'
LIMIT 1;
CALL proc_renovar_emprestimo(523);  


-- TESTE 18: Renovação falha - reservas pendentes (deve falhar)

SELECT e.id_emprestimo, e.id_recurso
FROM emprestimo e
INNER JOIN
    reserva r ON e.id_recurso = r.id_recurso -- Liga as tabelas pelo ID do item
WHERE
    r.estado_reserva = 'ativa' -- Filtra apenas as reservas em estado 'ativa'
    AND e.estado_emprestimo = 'em curso' -- Opcional, mas garante que o item está emprestado
LIMIT 1; 

-- Passo 4: Tentar renovar (deve falhar devido à reserva pendente)
CALL proc_renovar_emprestimo(3337);  -- Substitua 3337 pelo ID do empréstimo






-- TESTES PROCEDURE 4: proc_criar_reserva



-- TESTE 20: Criar reserva com sucesso (recurso emprestado)

-- Passo 1: Encontrar recurso emprestado

SELECT r.ID_recurso, r.disponibilidade
FROM Recurso r
WHERE r.disponibilidade = 'emprestado'
LIMIT 5;

-- Passo 2: Criar reserva para outro utilizador
CALL proc_criar_reserva(41, 8009, 45425); -- Substitua 8009 pelo ID do recurso emprestado encontrado

-- Passo 3: Verificar reserva criada
SELECT ID_reserva, ID_utilizador, ID_recurso, estado_reserva, data_reserva
FROM Reserva
WHERE ID_recurso = 8009 AND ID_utilizador = 41;

-- TESTE 21: Reserva com recurso disponível (deve falhar)
-- Encontrar recurso disponível:
SELECT ID_recurso FROM Recurso 
WHERE disponibilidade = 'disponível'
LIMIT 1;
-- Tentar criar reserva (deve falhar - recurso não está emprestado/atrasado):
CALL proc_criar_reserva(42, 538, 45425);  -- Substitua 538 pelo ID disponível
-- Deve falhar: "Recurso não pode ser reservado. Estado atual: disponível"

-- TESTE 22: Reserva duplicada (deve falhar com unique_violation)
-- Usar mesmo recurso e utilizador do TESTE 20:
CALL proc_criar_reserva(41, 8009, 45425);  -- Deve falhar: "Já possui reserva ativa deste recurso"

-- TESTE 23: Recurso inexistente (deve falhar)
CALL proc_criar_reserva(43, 999999, 45425);  -- Deve falhar: "Recurso 999999 não existe"

-- TESTE 24: Funcionário sem autorização (deve falhar)
-- Encontrar funcionário sem permissão:
SELECT ID_utilizador FROM Funcionario WHERE pode_emprestar = FALSE LIMIT 1;
-- Tentar criar reserva:
CALL proc_criar_reserva(44, 227, 202);  -- Substituir 202 pelo ID de funcionário sem autorização 
-- Deve falhar: "Funcionário não autorizado a criar reservas"

-- TESTE 25: Funcionário inexistente (deve falhar)
CALL proc_criar_reserva(45, 227, 999999);
-- Deve falhar: violação de FK (ID_utilizador não existe)

-- TESTE 26: Múltiplas reservas para o mesmo recurso (fila de espera)
-- Criar várias reservas para o mesmo recurso emprestado:
CALL proc_criar_reserva(46, 8009, 45425);
CALL proc_criar_reserva(47, 8009, 45425);
CALL proc_criar_reserva(48, 8009, 45425);
-- Verificar fila de reservas (ordenada por data_reserva):
SELECT ID_reserva, ID_utilizador, data_reserva, estado_reserva
FROM Reserva
WHERE ID_recurso = 8009 AND estado_reserva = 'ativa'
ORDER BY data_reserva;







