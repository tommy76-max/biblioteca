
SET search_path TO bd048_schema, public;


--TABELAS


CREATE TABLE Autor (
    ID_autor SERIAL PRIMARY KEY,
    primeiro_nome_autor VARCHAR(50) NOT NULL,
    segundo_nome_autor VARCHAR(50),
    ultimo_nome_autor VARCHAR(50) NOT NULL,
    nacionalidade VARCHAR(50),
    email_autor VARCHAR(100) UNIQUE,
    data_nascimento_autor DATE CHECK (data_nascimento_autor <= CURRENT_DATE),
    data_falecimento_autor DATE CHECK (data_falecimento_autor IS NULL OR data_falecimento_autor >= data_nascimento_autor),
    idade INTEGER
);



CREATE TABLE Categoria (
    ID_categoria SERIAL PRIMARY KEY,
    nome_categoria VARCHAR(100) NOT NULL UNIQUE
);


CREATE TABLE Utilizador (
    ID_utilizador SERIAL PRIMARY KEY,
    primeiro_nome VARCHAR(100) NOT NULL,
    segundo_nome VARCHAR(100),
    ultimo_nome VARCHAR(100) NOT NULL, 
    email VARCHAR(100) UNIQUE NOT NULL,
    numero_telemovel VARCHAR(20) UNIQUE NOT NULL,
    nome_rua VARCHAR(200),
    numero_casa VARCHAR(20),
    cidade VARCHAR(100),
    codigo_postal VARCHAR(20),
    data_registo DATE DEFAULT '2024-01-01',
    data_nascimento DATE CHECK (data_nascimento BETWEEN '1900-01-01' AND CURRENT_DATE),
    idade INTEGER
);



CREATE TABLE Editora (
    ID_editora SERIAL PRIMARY KEY,
    nome_editora VARCHAR(150) NOT NULL,
    email_editora VARCHAR(100) UNIQUE,
    website VARCHAR(100)
);


CREATE TABLE Aluno (
    ID_utilizador INTEGER PRIMARY KEY,
    numero_aluno VARCHAR(20) UNIQUE NOT NULL,
    ano INTEGER,
    curso VARCHAR(150) NOT NULL,
    ano_ingresso INTEGER,
    FOREIGN KEY (ID_utilizador) REFERENCES Utilizador(ID_utilizador) ON DELETE CASCADE
);


CREATE TABLE Professor (
    ID_utilizador INTEGER PRIMARY KEY,
    departamento VARCHAR(100),
    especializacao VARCHAR(200),
    disciplinas_lecionadas VARCHAR(200),
    FOREIGN KEY (ID_utilizador) REFERENCES Utilizador(ID_utilizador) ON DELETE CASCADE
);



CREATE TABLE Funcionario (
    ID_utilizador INTEGER PRIMARY KEY, 
    cargo VARCHAR(100) NOT NULL,
    data_contratacao DATE NOT NULL,
    salario NUMERIC(10,2) CHECK (salario >= 0),
    horario_trabalho VARCHAR(50),
    pode_emprestar BOOLEAN NOT NULL,
    FOREIGN KEY (ID_utilizador) REFERENCES Utilizador(ID_utilizador) ON DELETE CASCADE
);



CREATE TABLE Recurso (
    ID_recurso SERIAL PRIMARY KEY,
    titulo VARCHAR(300) NOT NULL,
    ano_publicacao INTEGER,
    idioma VARCHAR(50),
    disponibilidade VARCHAR(20) DEFAULT 'disponível' CHECK (disponibilidade IN ('disponível', 'emprestado', 'indisponível')), 
    estado VARCHAR(50) DEFAULT 'Bom' CHECK (estado IN ('Bom', 'Danificado')),
    ID_categoria INTEGER,
    ID_editora INTEGER,
    ID_autor INTEGER,
    FOREIGN KEY (ID_categoria) REFERENCES Categoria(ID_categoria) ON DELETE SET NULL,
    FOREIGN KEY (ID_editora) REFERENCES Editora(ID_editora) ON DELETE SET NULL,
    FOREIGN KEY (ID_autor) REFERENCES Autor(ID_autor) ON DELETE SET NULL
);



CREATE TABLE Livro (
    ID_recurso INTEGER PRIMARY KEY,
    ISBN VARCHAR(20) UNIQUE,
    edicao INTEGER CHECK (edicao >= 1),
    volume INTEGER,
    localizacao VARCHAR(100),
    FOREIGN KEY (ID_recurso) REFERENCES Recurso(ID_recurso) ON DELETE CASCADE
);


CREATE TABLE EBook (
    ID_recurso INTEGER PRIMARY KEY,
    link_acesso VARCHAR(500) NOT NULL,
    formato VARCHAR(20),
    tamanho_ficheiro VARCHAR(10),
    FOREIGN KEY (ID_recurso) REFERENCES Recurso(ID_recurso) ON DELETE CASCADE
);


CREATE TABLE Periodico (
    ID_recurso INTEGER PRIMARY KEY,
    ISSN VARCHAR(20) UNIQUE,
    frequencia_publicacao VARCHAR(20),
    numero_edicao INTEGER CHECK (numero_edicao >= 1),
    FOREIGN KEY (ID_recurso) REFERENCES Recurso(ID_recurso) ON DELETE CASCADE
);



CREATE TABLE Emprestimo(
    ID_emprestimo SERIAL PRIMARY KEY,
    ID_utilizador INTEGER NOT NULL,
    ID_funcionario INTEGER NOT NULL,
    ID_recurso INTEGER NOT NULL,
    data_emprestimo DATE NOT NULL, 
    data_devolucao_prevista DATE NOT NULL, 
    data_devolucao_efetiva DATE, 
    estado_emprestimo VARCHAR(100) DEFAULT 'em curso' CHECK (estado_emprestimo IN ('em curso', 'atrasado', 'concluído', 'concluído com atraso')),
    numero_renovacoes INTEGER DEFAULT 0 CHECK (numero_renovacoes <= 2 AND numero_renovacoes >=0),
    FOREIGN KEY (ID_utilizador) REFERENCES Utilizador(ID_utilizador) ON DELETE CASCADE,
    FOREIGN KEY (ID_funcionario) REFERENCES Funcionario(ID_utilizador) ON DELETE SET NULL,
    FOREIGN KEY (ID_recurso) REFERENCES Recurso(ID_recurso) ON DELETE CASCADE
);



CREATE TABLE Reserva (
    ID_reserva SERIAL PRIMARY KEY,
    ID_utilizador INTEGER NOT NULL,
    ID_funcionario INTEGER NOT NULL,
    ID_recurso INTEGER NOT NULL,
    estado_reserva VARCHAR(100) DEFAULT 'ativa',
    data_reserva DATE DEFAULT CURRENT_DATE,
    data_notificacao DATE,
    data_limite_levantamento DATE,
    data_levantamento DATE,
    FOREIGN KEY (ID_utilizador) REFERENCES Utilizador(ID_utilizador) ON DELETE CASCADE,
    FOREIGN KEY (ID_funcionario) REFERENCES Funcionario(ID_utilizador) ON DELETE SET NULL,
    FOREIGN KEY (ID_recurso) REFERENCES Recurso(ID_recurso) ON DELETE CASCADE
);



CREATE TABLE Multa (
    ID_multa SERIAL PRIMARY KEY,
    ID_emprestimo INTEGER NOT NULL,
    valor NUMERIC(10,2) CHECK (valor >= 0) DEFAULT 0,
    data_aplicacao DATE DEFAULT CURRENT_DATE,
    data_pagamento DATE,
    estado_multa VARCHAR(20) CHECK (estado_multa IN ('pago', 'pendente')),
    FOREIGN KEY (ID_emprestimo) REFERENCES Emprestimo(ID_emprestimo) ON DELETE CASCADE
);




--TRIGGERS


--TRIGGER 1
--calcular data de devoluçao previstaera 
CREATE OR REPLACE FUNCTION data_devolucao_prevista()
RETURNS TRIGGER AS $$
BEGIN
    NEW.data_devolucao_prevista := NEW.data_emprestimo + INTERVAL '15 days';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_data_devolucao
BEFORE INSERT ON Emprestimo
FOR EACH ROW
EXECUTE FUNCTION data_devolucao_prevista();



-- TRIGGER 2
--Atualizar disponibilidade
CREATE OR REPLACE FUNCTION atualizar_disponibilidade()
RETURNS TRIGGER AS $$
DECLARE
    id_recurso_afetado INTEGER;
    emprestimos_ativos_restantes INTEGER;
BEGIN
    IF TG_OP = 'DELETE' THEN
        id_recurso_afetado := OLD.ID_recurso;
    ELSE
        id_recurso_afetado := NEW.ID_recurso;
    END IF;
    IF (TG_OP = 'INSERT' AND NEW.estado_emprestimo IN ('em curso', 'atrasado'))
    OR (TG_OP = 'UPDATE' AND NEW.estado_emprestimo IN ('em curso', 'atrasado'))
    THEN
        UPDATE Recurso
        SET disponibilidade = 'emprestado'
        WHERE ID_recurso = id_recurso_afetado;
        RETURN NEW;
    END IF;

    SELECT COUNT(*)
    INTO emprestimos_ativos_restantes
    FROM Emprestimo
    WHERE ID_recurso = id_recurso_afetado
      AND estado_emprestimo IN ('em curso', 'atrasado');
    IF emprestimos_ativos_restantes = 0 THEN
        UPDATE Recurso
        SET disponibilidade = 'disponível'
        WHERE ID_recurso = id_recurso_afetado;
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE TRIGGER trigger_atualizar_disponibilidade
AFTER INSERT OR UPDATE OR DELETE ON Emprestimo
FOR EACH ROW
EXECUTE FUNCTION atualizar_disponibilidade();




--TRIGGER 3
--Calcular idade autor
CREATE OR REPLACE FUNCTION atualizar_idade_autor()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.data_falecimento_autor IS NOT NULL THEN
        NEW.idade := NULL;
    ELSE
        NEW.idade := EXTRACT(YEAR FROM age(CURRENT_DATE, NEW.data_nascimento_autor))::int;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_idade_autor
BEFORE INSERT OR UPDATE ON Autor
FOR EACH ROW
EXECUTE FUNCTION atualizar_idade_autor();




--TRIGGER 4
--calcular idade utilizador
CREATE OR REPLACE FUNCTION atualizar_idade_utilizador()
RETURNS TRIGGER AS $$
BEGIN
    NEW.idade := EXTRACT(YEAR FROM age(CURRENT_DATE, NEW.data_nascimento))::int;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_idade_utilizador
BEFORE INSERT OR UPDATE ON Utilizador
FOR EACH ROW
EXECUTE FUNCTION atualizar_idade_utilizador();






--TRIGGER 5
--Atualizar o estado da reserva depois de ser realizado o emprestimo do livro desejado
CREATE OR REPLACE FUNCTION atualizar_estado_reserva()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Reserva
    SET estado_reserva = 'cancelado'
    WHERE ID_recurso = NEW.ID_recurso
      AND ID_utilizador = NEW.ID_utilizador
      AND estado_reserva = 'ativa';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE TRIGGER trigger_cancelar_reserva
AFTER INSERT ON Emprestimo
FOR EACH ROW
EXECUTE FUNCTION atualizar_estado_reserva();




--TRIGGER 6
--Verificar se todos os campos para registar um emprestimo estão certos
CREATE OR REPLACE FUNCTION validar_emprestimo()
RETURNS TRIGGER AS $$
DECLARE
    atrasos INT;
    emprestimos_atuais INT;
    recurso_ocupado INT;
    funcionario_valido BOOLEAN;
BEGIN
    SELECT pode_emprestar INTO funcionario_valido
    FROM Funcionario
    WHERE ID_utilizador = NEW.ID_funcionario;
    IF funcionario_valido IS NULL OR funcionario_valido = FALSE THEN
        RAISE EXCEPTION 'Funcionário inválido.';
    END IF;
    SELECT COUNT(*) INTO atrasos
    FROM Emprestimo
    WHERE ID_utilizador = NEW.ID_utilizador
      AND data_devolucao_efetiva IS NULL
      AND data_devolucao_prevista < CURRENT_DATE;
    IF atrasos > 0 THEN
        RAISE EXCEPTION 'O utilizador possui empréstimos atrasados.';
    END IF;
    SELECT COUNT(*) INTO emprestimos_atuais
    FROM Emprestimo
    WHERE ID_utilizador = NEW.ID_utilizador
      AND data_devolucao_efetiva IS NULL;
    IF emprestimos_atuais >= 5 THEN
        RAISE EXCEPTION 'Limite de 5 empréstimos atingido.';
    END IF;
    SELECT COUNT(*) INTO recurso_ocupado
    FROM Emprestimo
    WHERE ID_recurso = NEW.ID_recurso
      AND data_devolucao_efetiva IS NULL;
    IF recurso_ocupado > 0 THEN
        RAISE EXCEPTION 'Recurso já emprestado.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validar_emprestimo
BEFORE INSERT ON Emprestimo
FOR EACH ROW EXECUTE FUNCTION validar_emprestimo();




















