


## Estrutura dos Ficheiros
 `schema.sql` - Criação de todas as tabelas e triggers necessárias 
 `data.sql` - Inserção de dados de exemplo nas tabelas 
 `procedures.sql` -  Criação das funções e procedures
 `queries.sql` - Consultas e relatórios de exemplo




## Requisitos
- **Visual Studio Code**  
[https://code.visualstudio.com/](https://code.visualstudio.com/)  
- **Extensão PostgreSQL (by Microsoft)**  
[https://marketplace.visualstudio.com/items?itemName=ms-ossdata.vscode-pgsql](https://marketplace.visualstudio.com/items?itemName=ms-ossdata.vscode-pgsql)  
- **Ligação VPN (se estiver fora da rede da FCUL ou Eduroam)**  
[https://ciencias.ulisboa.pt/pt/vpn](https://ciencias.ulisboa.pt/pt/vpn)





## Aceder à Base de Dados do Grupo
> Certificar-se de que está ligado à VPN se estiver fora da rede da FCUL.

### Abrir a Extensão PostgreSQL
- No VS Code, abrir o painel lateral “**PostgreSQL**”.

### Adicionar uma Nova Ligação
Clicar em **“Add Connection”** e preencher com as seguintes configurações:
**Server name**: `appserver.alunos.di.fc.ul.pt` 
**Authentication Type**: Password 
**Username**: `bd048`
**Password**: `bd048` 
**Database name**: `bd048` 




## Preparar o Schema
Depois de se ligar à base de dados:
- Antes de correr qualquer ficheiro, executar o seguinte comando:
```sql 
SET search_path TO bd048_schema, public;
```



## Executar os ficheiros SQL
Todos os ficheiros devem ser executados na ordem indicada.

### Criar as Tabelas
1. Abrir o ficheiro schema.sql no VS Code.
2. Depois de definir o caminho, executar todas as instruções de criação de tabelas na ordem em que aparecem. 
Exemplo de comando:
```sql 
CREATE TABLE Autor(...);
```

### Criar Triggers
As triggers devem ser criadas antes dos inserts, para que sejam ativadas quando os dados forem inseridos.
1. Ainda no ficheiro schema.sql.
2. Executar as funções que são utilizadas pelas triggers e, em seguida, criar a trigger que depende dessa função.
3. Repetir o processo para todas as funções e triggers do ficheiro, na ordem em que aparecem.


### Inserir os Dados
1. Abrir o ficheiro data.sql.
2. Executar todos os INSERT na ordem do ficheiro.
3. As triggers criadas anteriormente vão disparar automaticamente durante os inserts.

### Executar Outras Funções/Procedures
1. Abrir o ficheiro procedures.sql.
2. Executar as funções e procedures.
3. Estas funções podem ser usadas para relatórios, atualizações ou operações adicionais.


### Testar Funções e Procedures
1. PROCEDURE atualizar_valor_multas:
Ao executar
 ```sql 
 CALL atualizar_valor_multas(); 
 ``` 
Após a execução do comando a procedure deverá atualizar o valor das multas de acordo com o tempo de atraso

2. PPROCEDURE renovar_emprestimo:
 ```sql 
 CALL renovar_emprestimo(21); 
 ``` 
 Deverá aparecer uma mensagem a dizer "Não é possível renovar um empréstimo que não está em curso."

```sql 
 CALL renovar_emprestimo(602); 
 ``` 
 Deverá aparecer uma mensagem a dizer "Empréstimo não existe."

```sql 
 CALL renovar_emprestimo(446); 
 ``` 
  Deverá aparecer uma mensagem a dizer "Não é possível renovar mais de 2 vezes."

```sql 
 CALL renovar_emprestimo(433); 
 ``` 
  Deverá aparecer uma mensagem a dizer "Empréstimo renovado com sucesso!"

3. PROCEDURE fazer_emprestimo
```sql 
 CALL fazer_emprestimo(3, 35, 203) 
```
 Deverá aparecer uma mensagem a dizer "Empréstimo realizado com sucesso."
 
```sql 
 CALL fazer_emprestimo(3, 35, 202) 
```
 Deverá aparecer uma mensagem a dizer "Funcionário inválido."

```sql 
 CALL fazer_emprestimo(102, 35, 202) 
```
 Deverá aparecer uma mensagem a dizer "O utilizador possui empréstimos atrasados."

```sql 
 CALL fazer_emprestimo(66, 1, 203) 
```
 Deverá aparecer uma mensagem a dizer "Limite de 5 empréstimos atingido."

 4. PROCEDURE cancelar_reservas_expiradas
 Ao executar o comando 
 ```sql
 CALL cancelar_reservas_expiradas();
 ```
 A procedure deverá mudar o estado da reserva para "cancelado" de todas as reservas que não foram levantadas a tempo da data limite de levantamento. Se não houverem reservas para cancelar aparece "Não há reservas expiradas para cancelar."

 5. FUNCTION estatisticas_biblioteca
Ao executar o comando:
```sql
 SELECT * FROM estatisticas_biblioteca();
 ```
 a função deverá retornar uma tabela com o total de emprestimos, os emprestimos atrasados e o total de multas pendentes

 6. FUNCTION registar_utilizador
 ```sql
 SELECT registar_utilizador('Ana','Luísa','Pereira','ana.pereira@exemplo.com','912345678','Rua Central','10','Lisboa','1000-001','1990-02-15','funcionario',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Bibliotecario','2020-09-01',1250.00,'09:00-17:00',TRUE); 
 ``` 
 Regista um funcionário bibliotecário, ou seja, com permissão para fazer empréstimos e reservas, na base de dados

 ```sql 
 SELECT registar_utilizador('Carlos',NULL,'Mendes','carlos.mendes@exemplo.com','913456789','Avenida das Escolas','45','Porto','4000-200','1985-06-12','funcionario',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Assistente Administrativo','2019-05-20',950.00,'08:00-16:00',FALSE);
 ```
 Regista um funcionário não bibliotecário, ou seja, sem permissão para fazer empréstimos e reservas, na base de dados. Deverá aparecer "Funcionário registado com sucesso. ID Utilizador: id_utilizador. Nome: nome"

 ```sql
 SELECT registar_utilizador('Inês','Maria','Gonçalves','ines.goncalves@exemplo.com','911223344','Rua das Oliveiras','15','Lisboa','1000-050','2004-05-21','aluno','A2025001',1,'Engenharia Informática',2025,NULL,NULL,NULL,NULL,NULL,NULL,NULL,False);
 ```
 Regista um aluno na base de dados. Deverá aparecer "Aluno registado com sucesso. ID Utilizador: id_utilizador. Nome: nome"


 ```sql
 SELECT registar_utilizador('Sofia',NULL,'Almeida','sofia.almeida@exemplo.com','915667788','Rua do Liceu','25','Lisboa','1050-123','1982-04-18','professor',NULL,NULL,NULL,NULL,'Física','Astrofísica','Mecânica, Termodinâmica',NULL,NULL,NULL,NULL,FALSE);
```
 Regista um professor na base de dados. Deverá aparecer "Professor registado com sucesso. ID Utilizador: id_utilizador. Nome: Sofia Almeida"

Ao executar:
```sql 
SELECT registar_utilizador('Paulo',NULL,'Rocha','paulo.rocha@exemplo.com','918223344','Rua Nova','33','Setúbal','2900-123','1995-11-02','docente',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,FALSE);
Deverá aparecer que o tipo de utilizador é inválido.
```
Ao executar:
```sql
SELECT registar_utilizador('André',NULL,'Martins','andre.martins@exemplo.com',NULL,'Rua dos Cravos','10','Lisboa','1000-101','1998-07-15','aluno','A2025010',2,'Design Gráfico',2024,NULL,NULL,NULL,NULL,NULL,NULL,NULL,FALSE);
```
Deverá aparecer que é necessário indicar o numero de telemóvel.

Ao executar:
```sql
SELECT registar_utilizador('Marta','Rita','Costa',NULL,'917889900','Rua do Mercado','20','Faro','8000-300','1993-05-10','funcionario',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Técnico de Informática','2022-01-01',1100.00,'10:00-18:00',False);
```
Deverá aparecer que é necessário indicar um email.

Ao executar:
```sql
SELECT registar_utilizador(NULL,NULL,'Santos','joana.santos@exemplo.com','911223366','Avenida das Flores','5','Porto','4000-050','2000-01-22','professor',NULL,NULL,NULL,NULL,'Matemática','Álgebra','Cálculo, Estatística',NULL,NULL,NULL,NULL,FALSE);
```
Deverá aparecer que é necessário indicar o primeiro nome.

Ao executar:
```sql
SELECT registar_utilizador('Joana','Filipa','Pereira','user296@uni.com','911223344','Rua das Laranjeiras','45','Lisboa','1000-250','2001-03-18','aluno','A2025123',1,'Engenharia Informática',2025,NULL,NULL,NULL,NULL,NULL,NULL,NULL,FALSE);
```
Deverá aparecer que já existe um utilizador com o mesmo email.

Ao executar:
```sql
SELECT registar_utilizador('Ricardo','Miguel','Alves','ricardo.alves@exemplo.com','91230298','Avenida do Saber','12','Coimbra','3000-150','2000-11-25','aluno','A2025111',3,'Ciências da Computação',2022,NULL,NULL,NULL,NULL,NULL,NULL,NULL,FALSE);
```
Deverá aparecer que já existe um utilizador com o mesmo numero de telemovel.

Ao executar:
```sql
SELECT registar_utilizador('Tiago','André','Marques','tiago.marques@exemplo.com','913445566','Rua da Escola','33','Porto','4000-123','2002-02-10','aluno','A2025333',2,NULL,2024,NULL,NULL,NULL,NULL,NULL,NULL,NULL,FALSE);
```
Deverá aparecer que é necessário indicar o curso do aluno.


Ao executar:
```sql
SELECT registar_utilizador('Miguel','Rui','Santos','miguel.santos@exemplo.com','917112233','Rua do Sol','18','Lisboa','1000-050','2002-09-12','aluno',NULL,2,'Engenharia Civil',2023,NULL,NULL,NULL,NULL,NULL,NULL,NULL,FALSE);
```
Deverá aparecer que é necessário indicar o numero de aluno.


Ao executar:
```sql
SELECT registar_utilizador('Helena','Maria','Rocha','helena.rocha@exemplo.com','915667789','Rua das Letras','8','Lisboa','1000-500','1980-06-20','professor',NULL,NULL,NULL,NULL,NULL,'Literatura Portuguesa','Teoria Literária',NULL,NULL,NULL,NULL,FALSE);
```
Deverá aparecer que é necessário indicar o departamento do professor.

Ao executar:
```sql
SELECT registar_utilizador('Sérgio','Miguel','Carvalho','sergio.carvalho@exemplo.com','918223344','Rua da Administração','77','Lisboa','1000-300','1985-08-12','funcionario',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2023-02-01',950.00,'09:00-17:00',FALSE);
```
Deverá aparecer que é necessário indicar o cargo do funcionário.




7. FUNCTION prioridade_reserva
Ao executar, por exemplo:
```sql
SELECT * FROM prioridade_reserva(25);
```
Deverá mostrar uma tabela com todas as reservas do recurso com id 25 e a prioridade da reserva. Reservas mais antigas têm prioridade sobre as mais recentes.

8. FUNCTION atualizar_atrasos_e_multas
Ao executar
```sql
SELECT atualizar_atrasos_e_multas();
```
a função atualiza reservas que possa já ter passado a atrasadas e regista-as na tabela multa. 





### Executar Views e Consultas de Teste
1. Abrir o ficheiro queries.sql.
2. Executar todas as views e consultas na ordem do ficheiro.
3. Estas consultas permitem verificar se os dados e regras estão a funcionar corretamente.


