
SET search_path TO bd048_schema, public;


--PROCEDURE 1
-- atualiza o valor da multa
CREATE OR REPLACE PROCEDURE atualizar_valor_multas()
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE Multa
    SET valor = (CURRENT_DATE - Emprestimo.data_devolucao_prevista) * 0.50
    FROM Emprestimo
    WHERE Multa.ID_emprestimo = Emprestimo.ID_emprestimo
      AND Multa.estado_multa = 'pendente'
      AND Emprestimo.data_devolucao_efetiva IS NULL
      AND CURRENT_DATE > Emprestimo.data_devolucao_prevista;
    UPDATE Multa
    SET valor = (Emprestimo.data_devolucao_efetiva - Emprestimo.data_devolucao_prevista) * 0.50
    FROM Emprestimo
    WHERE Multa.ID_emprestimo = Emprestimo.ID_emprestimo
      AND Multa.estado_multa = 'pago'
      AND Emprestimo.data_devolucao_efetiva IS NOT NULL
      AND Emprestimo.data_devolucao_efetiva > Emprestimo.data_devolucao_prevista;

    RAISE NOTICE 'Multas atualizadas com sucesso.';
END;
$$;




--PROCEDURE 2
-- Renova emprestimo e verifica se existem todas as condiçoes para tal
CREATE OR REPLACE PROCEDURE renovar_emprestimo(p_id_emprestimo INT)
LANGUAGE plpgsql AS $$
DECLARE n_renovacoes INT; estado TEXT;
BEGIN
    SELECT numero_renovacoes, estado_emprestimo
    INTO n_renovacoes, estado
    FROM Emprestimo
    WHERE ID_emprestimo = p_id_emprestimo;
    IF NOT FOUND THEN
        RAISE NOTICE 'Empréstimo não existe.';
        RETURN;
    END IF;
    IF estado <> 'em curso' THEN
        RAISE NOTICE 'Não é possível renovar um empréstimo que não está em curso.';
        RETURN;
    ELSIF n_renovacoes >= 2 THEN
        RAISE NOTICE 'Não é possível renovar mais de 2 vezes.';
        RETURN;
    ELSE
        UPDATE Emprestimo
        SET data_emprestimo = CURRENT_DATE,
            data_devolucao_prevista = CURRENT_DATE + INTERVAL '15 days',
            numero_renovacoes = numero_renovacoes + 1
        WHERE ID_emprestimo = p_id_emprestimo;
        RAISE NOTICE 'Empréstimo renovado com sucesso!';
    END IF;
END;
$$;




--PROCEDURE 3
--Realiza um emprestimo. 
CREATE OR REPLACE PROCEDURE fazer_emprestimo(p_id_utilizador INT, p_id_recurso INT, p_id_funcionario INT)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO Emprestimo (ID_utilizador, ID_funcionario, ID_recurso, data_emprestimo)
    VALUES (p_id_utilizador, p_id_funcionario, p_id_recurso, CURRENT_DATE);
    RAISE NOTICE 'Empréstimo realizado com sucesso.';
END;
$$;



--PROCEDURE 4
--Cancela reservas automaticamente se não forem levantar o recurso no prazo 
CREATE OR REPLACE PROCEDURE cancelar_reservas_expiradas()
LANGUAGE plpgsql AS $$
DECLARE
    total_canceladas INT;
BEGIN
    UPDATE Reserva
    SET estado_reserva = 'cancelado'
    WHERE estado_reserva = 'ativa'
      AND data_limite_levantamento < CURRENT_DATE
      AND data_levantamento IS NULL;
    GET DIAGNOSTICS total_canceladas = ROW_COUNT;
    IF total_canceladas = 0 THEN
        RAISE NOTICE 'Não há reservas expiradas para cancelar.';
    ELSE
        RAISE NOTICE '% reserva(s) expiradas foram canceladas.', total_canceladas;
    END IF;
END;
$$;


 
--FUNCTION 1
-- Retorna os emprestimos, os emprestimos atrasados e multas pendentes
CREATE OR REPLACE FUNCTION estatisticas_biblioteca()
RETURNS TABLE (
    total_emprestimos INT,
    emprestimos_atrasados INT,
    total_multas_pendentes INT
) AS $$
BEGIN
    SELECT COUNT(*) INTO total_emprestimos
    FROM Emprestimo;
    SELECT COUNT(*) INTO emprestimos_atrasados
    FROM Emprestimo
    WHERE data_devolucao_efetiva IS NULL
      AND data_devolucao_prevista < CURRENT_DATE;
    SELECT COUNT(*) INTO total_multas_pendentes
    FROM Multa
    WHERE estado_multa = 'pendente';
    RETURN NEXT; 
END;
$$ LANGUAGE plpgsql;





--FUNCTION 2 
-- Regista um novo utilizador no sistema
CREATE OR REPLACE FUNCTION registar_utilizador(
    p_primeiro_nome VARCHAR,
    p_segundo_nome VARCHAR,
    p_ultimo_nome VARCHAR,
    p_email VARCHAR,
    p_numero_telemovel VARCHAR,
    p_nome_rua VARCHAR,
    p_numero_casa VARCHAR,
    p_cidade VARCHAR,
    p_codigo_postal VARCHAR,
    p_data_nascimento DATE,
    p_tipo VARCHAR,
    -- Aluno
    p_numero_aluno VARCHAR DEFAULT NULL,
    p_ano INTEGER DEFAULT NULL,
    p_curso VARCHAR DEFAULT NULL,
    p_ano_ingresso INTEGER DEFAULT NULL,
    -- Professor
    p_departamento VARCHAR DEFAULT NULL,
    p_especializacao VARCHAR DEFAULT NULL,
    p_disciplinas_lecionadas VARCHAR DEFAULT NULL,
    -- Funcionário
    p_cargo VARCHAR DEFAULT NULL,
    p_data_contratacao DATE DEFAULT NULL,
    p_salario NUMERIC(10,2) DEFAULT NULL,
    p_horario_trabalho VARCHAR DEFAULT NULL,
    p_pode_emprestar BOOLEAN DEFAULT TRUE
)
RETURNS TEXT AS $$
DECLARE
    v_id INT;
BEGIN
    IF p_tipo NOT IN ('aluno', 'professor', 'funcionario') THEN
        RETURN format('Tipo inválido: %s. Deve ser aluno, professor ou funcionario.', p_tipo);
    END IF;
    IF p_primeiro_nome IS NULL OR p_ultimo_nome IS NULL OR p_email IS NULL OR p_numero_telemovel IS NULL THEN
        RETURN 'Campos obrigatórios em falta (nome, email ou número de telemóvel).';
    END IF;
    IF EXISTS (SELECT 1 FROM Utilizador WHERE email = p_email) THEN
        RETURN format('Já existe um utilizador com o email "%s".', p_email);
    END IF;
    IF EXISTS (SELECT 1 FROM Utilizador WHERE numero_telemovel = p_numero_telemovel) THEN
        RETURN format('Já existe um utilizador com o número "%s".', p_numero_telemovel);
    END IF;

    IF p_tipo = 'aluno' THEN
        IF p_numero_aluno IS NULL OR p_curso IS NULL THEN
            RETURN 'Para alunos é necessário indicar número de aluno e curso.';
        END IF;
    ELSIF p_tipo = 'professor' THEN
        IF p_departamento IS NULL THEN
            RETURN 'Para professores é necessário indicar o departamento.';
        END IF;
    ELSIF p_tipo = 'funcionario' THEN
        IF p_cargo IS NULL THEN
            RETURN 'Para funcionários é necessário indicar o cargo.';
        END IF;
    END IF;

    INSERT INTO Utilizador (primeiro_nome, segundo_nome, ultimo_nome, email, numero_telemovel, nome_rua, numero_casa, cidade, codigo_postal, data_nascimento)
    VALUES (p_primeiro_nome, p_segundo_nome, p_ultimo_nome, p_email, p_numero_telemovel, p_nome_rua, p_numero_casa, p_cidade, p_codigo_postal, p_data_nascimento)
    RETURNING ID_utilizador INTO v_id;

    IF p_tipo = 'aluno' THEN
        INSERT INTO Aluno (ID_utilizador, numero_aluno, ano, curso, ano_ingresso)
        VALUES (v_id, p_numero_aluno, COALESCE(p_ano, 1), p_curso, COALESCE(p_ano_ingresso, EXTRACT(YEAR FROM CURRENT_DATE)));
    ELSIF p_tipo = 'professor' THEN
        INSERT INTO Professor (ID_utilizador, departamento, especializacao, disciplinas_lecionadas)
        VALUES (v_id, p_departamento, p_especializacao, p_disciplinas_lecionadas);
    ELSE
        INSERT INTO Funcionario (ID_utilizador, cargo, data_contratacao, salario, horario_trabalho, pode_emprestar)
        VALUES (v_id, p_cargo, COALESCE(p_data_contratacao, CURRENT_DATE), COALESCE(p_salario, 0), p_horario_trabalho, COALESCE(p_pode_emprestar, TRUE));
    END IF;

    RETURN format('%s registado com sucesso. ID Utilizador: %s . Nome: %s %s %s',
        INITCAP(p_tipo), v_id, p_primeiro_nome, COALESCE(p_segundo_nome, ''), p_ultimo_nome);
END;
$$ LANGUAGE plpgsql;

  


-- FUNCTION 3
--Mostra a prioridade de emprestimos pelo tempo de reserva
CREATE OR REPLACE FUNCTION prioridade_reserva(p_id_recurso INTEGER)
RETURNS TABLE(
    prioridade INTEGER,
    nome_utilizador VARCHAR,
    titulo_recurso VARCHAR,
    data_reserva DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY Reserva.data_reserva ASC)::INTEGER AS prioridade,
        (Utilizador.primeiro_nome || ' ' ||  Utilizador.ultimo_nome)::VARCHAR AS nome_utilizador,
        Recurso.titulo,
        Reserva.data_reserva
    FROM Reserva 
    JOIN Utilizador ON Reserva.ID_utilizador = Utilizador.ID_utilizador
    JOIN Recurso ON Reserva.ID_recurso = Recurso.ID_recurso
    WHERE Reserva.ID_recurso = p_id_recurso
      AND Reserva.estado_reserva = 'ativa'
    ORDER BY Reserva.data_reserva ASC;
END;
$$ LANGUAGE plpgsql;



--FUNCTION 4
-- Atualiza emprestimos que tenham passado da data prevista de devolução e acrescenta na multa
CREATE OR REPLACE FUNCTION atualizar_atrasos_e_multas()
RETURNS VOID AS $$
BEGIN
    UPDATE Emprestimo
    SET estado_emprestimo = 'atrasado'
    WHERE estado_emprestimo = 'em curso'
      AND data_devolucao_prevista < CURRENT_DATE;

    INSERT INTO Multa (ID_emprestimo, data_aplicacao, data_pagamento, estado_multa)
    SELECT e.ID_emprestimo, e.data_devolucao_prevista, NULL, 'pendente'
    FROM Emprestimo e
    WHERE e.estado_emprestimo = 'atrasado'
      AND NOT EXISTS (
          SELECT 1 
          FROM Multa m 
          WHERE m.ID_emprestimo = e.ID_emprestimo
      );
END;
$$ LANGUAGE plpgsql;

