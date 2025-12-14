//QUERIES




//1. Consulta de recursos disponíveis
//Esta query devolve todos os recursos cuja disponibilidade é "disponível", mostrando apenas o título, autores e tipo
//de recurso, ordenados alfabeticamente pelo título.

db.Recurso.find(
  { disponibilidade: "disponível" },
  {
    _id: 0,
    titulo: 1,
    autores: 1,
    tipo_recurso: 1
  }
).sort({ titulo: 1 });

// Tempos de execução:
// executionTimeMillis: 71 ms
// totalDocsExamined: 17882





// 2. Número de recursos disponíveis por categoria
//Esta pipeline de agregação filtra os recursos disponíveis e conta quantos existem em cada categoria.
db.Recurso.aggregate([
  {
    // Filtra apenas os recursos com disponibilidade "disponível"
    $match: { disponibilidade: "disponível" }
  },
  {
    // Agrupa os documentos por categoria e conta quantos existem
    $group: {
      _id: "$categoria",
      disponiveis: { $sum: 1 }
    }
  },
  {
    // Renomeia campos e remove o _id original do output
    $project: {
      _id: 0,
      nome_categoria: "$_id",
      disponiveis: 1
    }
  },
  {
    // Ordena o resultado pelo nome da categoria
    $sort: { nome_categoria: 1 }
  }
]);

// Tempos de execução:
// executionTimeMillis: 34 ms
// totalDocsExamined: 17882






// 3. Total de empréstimos por recurso
// Esta pipeline de agregação calcula o número total de empréstimos realizados por cada recurso, identificados pelo título

db.Emprestimo.aggregate([
  {
    // Agrupa os empréstimos pelo título do recurso
    $group: {
      _id: "$titulo_recurso",
      // Conta o número de empréstimos por recurso
      total_emprestimos: { $sum: 1 }
    }
  },
  {
    // - remove o campo _id
    // - renomeia o título do recurso
    $project: {
      _id: 0,
      titulo: "$_id",
      total_emprestimos: 1
    }
  },
  {
    // Ordena do recurso mais emprestado para o menos emprestado
    $sort: { total_emprestimos: -1 }
  }
]);

// Tempos de execução
// executionTimeMillis: 89 ms
// totalDocsExamined: 25947






// 4. Multas pendentes associadas a empréstimos
// Esta pipeline de agregação filtra os empréstimos que possuem multas em estado "pendente" e apresenta informação relevante
// sobre cada multa, incluindo o utilizador, valor e data de aplicação.

db.Emprestimo.aggregate([
  {
    // Seleciona apenas empréstimos com multas pendentes
    $match: {
      "multa.estado_multa": "pendente"
    }
  },
  {
    // Projeta apenas os campos relevantes para o resultado e renomeia-os
    $project: {
      _id: 0,
      ID_multa: "$multa.ID_multa",
      utilizador: "$nome_utilizador",
      valor: "$multa.valor",
      data_aplicacao: "$multa.data_aplicacao"
    }
  }
]);

// Tempos de execução
// executionTimeMillis: 15 ms
// totalDocsExamined: 2320






// 5. Ranking de utilizadores com atrasos na devolução
// Esta pipeline identifica os empréstimos devolvidos com atraso,
// agrupa-os por utilizador e constrói um ranking dos utilizadores com mais atrasos

db.Emprestimo.aggregate([
  {
    // Filtra apenas empréstimos que:
    // 1) já foram devolvidos (data_devolucao_efetiva diferente de null)
    // 2) tiveram atraso na devolução (data efetiva > data prevista)
    $match: {
      data_devolucao_efetiva: { $ne: null },
      $expr: {
        $gt: ["$data_devolucao_efetiva", "$data_devolucao_prevista"]
      }
    }
  },
  {
    // Agrupa os empréstimos por utilizador e conta o número total de atrasos
    $group: {
      _id: "$ID_utilizador",
      // Obtém o nome do utilizador
      nome: { $first: "$nome_utilizador" },
      total_atrasos: { $sum: 1 }
    }
  },
  {
    // Aplica funções de janela para criar um ranking com base no número total de atrasos (ordem decrescente)
    $setWindowFields: {
      sortBy: { total_atrasos: -1 },
      output: {
        ranking_atrasados: { $rank: {} }
      }
    }
  },
  {
    // Formata o output final
    // - renomeia o identificador do utilizador
    // - mantém o total de atrasos e o ranking
    $project: {
      _id: 0,
      id_utilizador: "$_id",
      nome: 1,
      total_atrasos: 1,
      ranking_atrasados: 1
    }
  },
  {
    // Garante a ordenação final pelo ranking
    $sort: { ranking_atrasados: 1 }
  }
]);

// Tempos de execução
// executionTimeMillis: 21 ms
// totalDocsExamined: 26017





// 6. Empréstimos atualmente em curso
// Esta query retorna todos os empréstimos que ainda estão em curso, mostrando informações relevantes

db.Emprestimo.find(
  {
    // Filtra apenas empréstimos com estado "em curso"
    estado_emprestimo: "em curso"
  },
  {
    // Projeta apenas os campos relevantes
    _id: 0,
    titulo_recurso: 1,
    nome_utilizador: 1,
    data_emprestimo: 1,
    data_devolucao_prevista: 1
  }
).sort(
  // Ordena os empréstimos do mais recente para o mais antigo
  { data_emprestimo: -1 }
);

// Tempos de execução
// executionTimeMillis: 19 ms
// totalDocsExamined: 26017







// 7. Último empréstimo por utilizador e dias desde então
// Esta pipeline encontra o último empréstimo de cada utilizador e calcula quantos dias se passaram desde esse empréstimo.

db.Emprestimo.aggregate([
  {
    // Ordena todos os empréstimos por data crescente
    $sort: { data_emprestimo: 1 }
  },
  {
    // Agrupa os empréstimos por utilizador
    // - nome_utilizador: vai buscar o primeiro nome
    // - ultimo_emprestimo: vai buscar a última data de empréstimo
    $group: {
      _id: "$ID_utilizador",
      nome_utilizador: { $first: "$nome_utilizador" },
      ultimo_emprestimo: { $last: "$data_emprestimo" }
    }
  },
  {
    // Calcula a diferença em dias entre a data do último empréstimo e hoje
    $addFields: {
      dias_desde_ultimo_emprestimo: {
        $dateDiff: {
          startDate: { $dateFromString: { dateString: "$ultimo_emprestimo" } },
          endDate: new Date(),
          unit: "day"
        }
      }
    }
  },
  {
    // Ajusta os campos de saída para legibilidade
    $project: {
      _id: 0,
      ID_utilizador: "$_id",
      nome_utilizador: 1,
      ultimo_emprestimo: 1,
      dias_desde_ultimo_emprestimo: 1
    }
  },
  {
    // Ordena do utilizador com mais dias desde o último empréstimo para o menor
    $sort: { dias_desde_ultimo_emprestimo: -1 }
  }
]);


// Tempos de execução
// executionTimeMillis: 130 ms
// totalDocsExamined: 26017






// 8. Total de reservas ativas por recurso
// Esta pipeline conta quantas reservas estão atualmente ativas para cada recurso
// mostrando o título do recurso e o total de reservas pendentes

db.Reserva.aggregate([
  {
    // Filtra apenas reservas que estão ativas
    $match: { estado_reserva: "ativa" }
  },
  {
    // Agrupa as reservas por ID do recurso
    // - titulo: vai buscar o título do recurso
    // - total_reservas_pendentes: conta quantas reservas existem
    $group: {
      _id: "$ID_recurso",
      titulo: { $first: "$titulo_recurso" },
      total_reservas_pendentes: { $sum: 1 }
    }
  },
  {
    // Ajusta o output final
    $project: {
      _id: 0,                  // remove o campo _id
      titulo: 1,               // mantém o título do recurso
      total_reservas_pendentes: 1 // mantém o total de reservas pendentes
    }
  },
  {
    // Ordena do recurso com mais reservas pendentes para o menos
    $sort: { total_reservas_pendentes: -1 }
  }
]);

// Tempos de execução
// executionTimeMillis: 5 ms
// totalDocsExamined: 87







// 9. Total de empréstimos e reservas por utilizador
// Descrição:
// Esta pipeline agrega os dados de empréstimos por utilizador,
// calcula o total de empréstimos, faz um lookup na coleção de reservas para contar quantas reservas cada utilizador possui,
// e retorna um resultado combinado, ordenado pelo maior número de empréstimos e reservas.

db.Emprestimo.aggregate([
  {
    // Agrupa os empréstimos por utilizador
    $group: {
      _id: "$ID_utilizador",
      nome_utilizador: { $first: "$nome_utilizador" },
      total_emprestimos: { $sum: 1 }
    }
  },
  {
    // Faz lookup na coleção Reserva para contar reservas do mesmo utilizador
    $lookup: {
      from: "Reserva",
      let: { userId: "$_id" },
      pipeline: [
        { $match: { $expr: { $eq: ["$ID_utilizador", "$$userId"] } } },
        { $count: "total" } // conta o total de reservas
      ],
      as: "reservas_count"
    }
  },
  {
    // Formata o output final
    $project: {
      _id: 0,
      ID_utilizador: "$_id",
      nome_utilizador: 1,
      total_emprestimos: 1,
      // Se não houver reservas, retorna 0
      total_reservas: { 
        $ifNull: [{ $arrayElemAt: ["$reservas_count.total", 0] }, 0] 
      }
    }
  },
  {
    // Ordena por total de empréstimos e reservas 
    $sort: { 
      total_emprestimos: -1, 
      total_reservas: -1 
    }
  }
]);

// Tempos de execução
// executionTimeMillis: 4056 ms
// totalDocsExamined: 25947







// 10. Recursos sem empréstimos nem reservas
// Esta pipeline identifica os recursos que não possuem nenhum empréstimo nem nenhuma reserva associada.
// O resultado mostra apenas título, autores e categoria

db.Recurso.aggregate([
  {
    // Faz lookup na coleção "Emprestimo" para trazer todos os empréstimos do recurso
    $lookup: {
      from: "Emprestimo",
      localField: "_id",
      foreignField: "ID_recurso",
      as: "emprestimos"
    }
  },
  {
    // Faz lookup na coleção "Reserva" para trazer todas as reservas do recurso
    $lookup: {
      from: "Reserva",
      localField: "_id",
      foreignField: "ID_recurso",
      as: "reservas"
    }
  },
  {
    // Filtra apenas os recursos que não possuem empréstimos nem reservas
    $match: {
      $and: [
        { emprestimos: { $eq: [] } },
        { reservas: { $eq: [] } }
      ]
    }
  },
  {
    // Projeta apenas os campos relevantes
    $project: {
      _id: 0,
      titulo: 1,
      autores: 1,
      categoria: 1
    }
  },
  {
    // Ordena os resultados alfabeticamente pelo título
    $sort: { titulo: 1 }
  }
]);

// Tempos de execução
// executionTimeMillis: 1012 ms
// totalDocsExamined: 46149







// 11. Percentagem de empréstimos por idioma
// Esta pipeline calcula quantos empréstimos existem por idioma
// calcula o total geral de empréstimos e determina a percentagem de cada idioma em relação ao total.

db.Emprestimo.aggregate([
  {
    // Faz lookup para trazer dados completos do recurso associado
    $lookup: {
      from: "Recurso",
      localField: "ID_recurso",
      foreignField: "_id",
      as: "recurso"
    }
  },
  {
    // Desagrega o array do lookup para trabalhar com cada recurso individualmente
    $unwind: "$recurso"
  },
  {
    // Agrupa por idioma e conta o total de empréstimos por idioma
    $group: {
      _id: "$recurso.idioma",
      total_emprestimos: { $sum: 1 }
    }
  },
  {
    // Agrupa todos os idiomas em um único documento para calcular o total geral
    $group: {
      _id: null,
      idiomas: {
        $push: {
          idioma: "$_id",
          total_emprestimos: "$total_emprestimos"
        }
      },
      total_geral: { $sum: "$total_emprestimos" }
    }
  },
  {
    // Desagrega novamente os idiomas para projetar cada linha individualmente
    $unwind: "$idiomas"
  },
  {
    // Calcula percentagem de empréstimos por idioma e projeta os campos finais
    $project: {
      _id: 0,
      idioma: "$idiomas.idioma",
      total_emprestimos: "$idiomas.total_emprestimos",
      percentagem_emprestimos: {
        $round: [
          {
            $multiply: [
              { $divide: ["$idiomas.total_emprestimos", "$total_geral"] },
              100
            ]
          },
          2
        ]
      }
    }
  },
  {
    // Ordena pelo total de empréstimos em ordem decrescente
    $sort: { total_emprestimos: -1 }
  }
]);

// Tempos de execução
// executionTimeMillis: 1579 ms
// totalDocsExamined: 25947





// 12. Total de empréstimos por mês
// Esta pipeline calcula o total de empréstimos por mês. Limita o resultado aos últimos 12 meses.

db.Emprestimo.aggregate([
  {
    // Adiciona um campo "mes" extraindo os primeiros 7 caracteres da data
    // no formato "YYYY-MM"
    $addFields: {
      mes: { $substr: ["$data_emprestimo", 0, 7] }
    }
  },
  {
    // Agrupa os empréstimos pelo mês e conta o total de empréstimos
    $group: {
      _id: "$mes",
      total_emprestimos: { $sum: 1 }
    }
  },
  {
    // Ajusta os campos de saída
    $project: {
      _id: 0,
      mes: "$_id",
      total_emprestimos: 1
    }
  },
  {
    // Ordena os meses de forma crescente
    $sort: { mes: 1 }
  },
  {
    // Limita o resultado aos últimos 12 meses
    $limit: 12
  }
]);

// Tempos de execução
// executionTimeMillis: 38 ms
// totalDocsExamined: 25947





// 13. Classificação de devoluções de empréstimos
// Esta pipeline analisa os empréstimos devolvidos, classificando cada devolução em:
// - "Adiantado": devolução antes da data prevista
// - "No dia da devolução prevista": devolução exatamente na data
// - "Atrasado": devolução depois da data prevista

db.Emprestimo.aggregate([
  {
    // Filtra apenas empréstimos que já foram devolvidos
    $match: {
      data_devolucao_efetiva: { $ne: null }
    }
  },
  {
    // Classifica cada empréstimo em "Adiantado", "No dia da devolução prevista" ou "Atrasado"
    $group: {
      _id: {
        $cond: {
          if: { $lt: ["$data_devolucao_efetiva", "$data_devolucao_prevista"] },
          then: "Adiantado",
          else: {
            $cond: {
              if: { $eq: ["$data_devolucao_efetiva", "$data_devolucao_prevista"] },
              then: "No dia da devolução prevista",
              else: "Atrasado"
            }
          }
        }
      },
      total: { $sum: 1 }
    }
  },
  {
    // Agrupa em um único documento para calcular percentagens
    $group: {
      _id: null,
      tipos: {
        $push: {
          tipo_devolucao: "$_id",
          total: "$total"
        }
      },
      total_geral: { $sum: "$total" }
    }
  },
  {
    // Desagrega os tipos de devolução novamente para projetar individualmente
    $unwind: "$tipos"
  },
  {
    // Calcula percentagem de cada tipo e ajusta campos de saída
    $project: {
      _id: 0,
      tipo_devolucao: "$tipos.tipo_devolucao",
      total: "$tipos.total",
      percentagem: {
        $round: [
          {
            $multiply: [
              { $divide: ["$tipos.total", "$total_geral"] },
              100
            ]
          },
          2
        ]
      }
    }
  },
  {
    // Ordena do tipo com mais devoluções para o menor
    $sort: { total: -1 }
  }
]);

// Tempos de execução
// executionTimeMillis: 48 ms
// totalDocsExamined: 0





// 14. Estatísticas salariais por cargo de funcionário
// Descrição:
// Esta pipeline analisa os usuários que são funcionários
// e calcula, por cargo:
// - salário médio
// - salário mínimo
// - salário máximo
// - número de funcionários

db.Utilizador.aggregate([
  {
    // Seleciona apenas os utilizadores que têm detalhes de funcionário
    $match: {
      "detalhes_funcionario": { $ne: null }
    }
  },
  {
    // Agrupa os utilizadores por cargo e calcula métricas salariais
    $group: {
      _id: "$detalhes_funcionario.cargo",
      salario_medio: { $avg: "$detalhes_funcionario.salario" },
      salario_minimo: { $min: "$detalhes_funcionario.salario" },
      salario_maximo: { $max: "$detalhes_funcionario.salario" },
      numero_funcionarios: { $sum: 1 }
    }
  },
  {
    // Ajusta os campos de saída, arredondando os salários
    $project: {
      _id: 0,
      cargo: "$_id",
      salario_medio: { $round: ["$salario_medio", 2] },
      salario_minimo: { $round: ["$salario_minimo", 2] },
      salario_maximo: { $round: ["$salario_maximo", 2] },
      numero_funcionarios: 1
    }
  },
  {
    // Ordena os cargos pelo salário médio de forma decrescente
    $sort: { salario_medio: -1 }
  }
]);

// Tempos de execução
// executionTimeMillis: 67 ms
// totalDocsExamined: 50300





// 15. Distribuição de utilizadores por faixa etária
// Esta pipeline agrupa os utilizadores por faixas etárias
// Calcula o total de utilizadores por faixa e a percentagem sobre o total geral de utilizadores.

db.Utilizador.aggregate([
  {
    // Classifica cada utilizador numa faixa etária usando $switch
    $group: {
      _id: {
        $switch: {
          branches: [
            { case: { $and: [{ $gte: ["$idade", 15] }, { $lte: ["$idade", 20] }] }, then: "15-20 anos" },
            { case: { $and: [{ $gte: ["$idade", 21] }, { $lte: ["$idade", 25] }] }, then: "21-25 anos" },
            { case: { $and: [{ $gte: ["$idade", 26] }, { $lte: ["$idade", 35] }] }, then: "26-35 anos" },
            { case: { $and: [{ $gte: ["$idade", 36] }, { $lte: ["$idade", 45] }] }, then: "36-45 anos" },
            { case: { $and: [{ $gte: ["$idade", 46] }, { $lte: ["$idade", 55] }] }, then: "46-55 anos" },
            { case: { $and: [{ $gte: ["$idade", 56] }, { $lte: ["$idade", 65] }] }, then: "56-65 anos" },
            { case: { $gt: ["$idade", 65] }, then: "65+ anos" }
          ],
          default: "Idade desconhecida"
        }
      },
      total_utilizadores: { $sum: 1 } // Conta total de utilizadores em cada faixa
    }
  },
  {
    // Agrupa novamente para calcular total geral e preparar percentagens
    $group: {
      _id: null,
      total_geral: { $sum: "$total_utilizadores" },
      faixas: {
        $push: {
          faixa_etaria: "$_id",
          total_utilizadores: "$total_utilizadores"
        }
      }
    }
  },
  {
    // Desagrega para projetar cada faixa individualmente
    $unwind: "$faixas"
  },
  {
    // Calcula percentagem e ajusta campos finais
    $project: {
      _id: 0,
      faixa_etaria: "$faixas.faixa_etaria",
      total_utilizadores: "$faixas.total_utilizadores",
      percentagem_total: {
        $concat: [
          { $toString: { $round: [{ $multiply: [{ $divide: ["$faixas.total_utilizadores", "$total_geral"] }, 100] }, 2] } },
          " %"
        ]
      }
    }
  },
  {
    // Ordena alfabeticamente pela faixa etária
    $sort: { faixa_etaria: 1 }
  }
]);

// Tempos de execução
// executionTimeMillis: 58 ms
// totalDocsExamined: 50300






// 16. Empréstimos e percentagem de renovação por tipo de utilizador
// Esta pipeline agrupa os empréstimos por tipo de utilizador e conta o total de empréstimos e quantos foram renovados

db.Emprestimo.aggregate([
  {
    // Agrupa por tipo de utilizador
    $group: {
      _id: "$tipo_utilizador",
      total_emprestimos: { $sum: 1 },
      // Conta apenas os empréstimos que foram renovados
      emprestimos_renovados: {
        $sum: {
          $cond: [{ $gt: ["$numero_renovacoes", 0] }, 1, 0]
        }
      }
    }
  },
  {
    // Ajusta os campos de saída
    $project: {
      _id: 0,
      tipo_utilizador: "$_id",
      total_emprestimos: 1,
      emprestimos_renovados: 1,
      // Calcula percentagem de renovação e formata como string
      percentagem_renovacao: {
        $concat: [
          {
            $toString: {
              $round: [
                {
                  $multiply: [
                    { $divide: ["$emprestimos_renovados", "$total_emprestimos"] },
                    100
                  ]
                },
                2
              ]
            }
          },
          "%"
        ]
      }
    }
  },
  {
    // Ordena alfabeticamente pelo tipo de utilizador
    $sort: { tipo_utilizador: 1 }
  }
]);

// Tempos de execução
// executionTimeMillis: 24 ms
// totalDocsExamined: 25947





// 17. Estatísticas detalhadas de empréstimos por categoria de recurso
// Esta pipeline agrega dados de empréstimos agrupando por categoria
// de recurso. Calcula:
// - total de empréstimos
// - empréstimos ativos (em curso ou atrasados)
// - empréstimos concluídos
// - número de recursos únicos na categoria
// - média de empréstimos por recurso
// - total de renovações e taxa de renovação

db.Emprestimo.aggregate([
  {
    // Faz lookup para trazer informações do recurso associado a cada empréstimo
    $lookup: {
      from: "Recurso",
      localField: "ID_recurso",
      foreignField: "_id",
      as: "recurso_info"
    }
  },
  {
    // Desagrega o array retornado pelo lookup para processar cada recurso individualmente
    $unwind: "$recurso_info"
  },
  {
    // Agrupa por categoria do recurso
    $group: {
      _id: "$recurso_info.categoria",
      total_emprestimos: { $sum: 1 }, // total de empréstimos na categoria
      emprestimos_ativos: {
        $sum: {
          // Conta apenas os empréstimos "em curso" ou "atrasado"
          $cond: [
            { $in: ["$estado_emprestimo", ["em curso", "atrasado"]] },
            1,
            0
          ]
        }
      },
      emprestimos_concluidos: {
        $sum: {
          // Conta apenas os empréstimos "concluídos"
          $cond: [{ $eq: ["$estado_emprestimo", "concluído"] }, 1, 0]
        }
      },
      total_renovacoes: { $sum: "$numero_renovacoes" }, // soma de todas as renovações
      recursos_unicos: { $addToSet: "$ID_recurso" } // cria um set de IDs únicos para contar recursos distintos
    }
  },
  {
    // Calcula campos derivados importantes
    $addFields: {
      num_recursos_diferentes: { $size: "$recursos_unicos" }, // número de recursos distintos
      media_emprestimos_por_recurso: {
        // média de empréstimos por recurso da categoria
        $round: [
          { $divide: ["$total_emprestimos", { $size: "$recursos_unicos" }] },
          2
        ]
      },
      taxa_renovacao: {
        // taxa de renovação em percentagem
        $round: [
          {
            $multiply: [
              { $divide: ["$total_renovacoes", "$total_emprestimos"] },
              100
            ]
          },
          2
        ]
      }
    }
  },
  {
    // Ajusta output final e formata taxa de renovação com símbolo "%"
    $project: {
      _id: 0,
      categoria: "$_id",
      total_emprestimos: 1,
      emprestimos_ativos: 1,
      emprestimos_concluidos: 1,
      num_recursos_diferentes: 1,
      media_emprestimos_por_recurso: 1,
      total_renovacoes: 1,
      taxa_renovacao_perc: { $concat: [{ $toString: "$taxa_renovacao" }, "%"] }
    }
  },
  {
    // Ordena pelo total de empréstimos para destacar categorias mais utilizadas
    $sort: { total_emprestimos: -1 }
  }
]);

// Tempos de execução
// executionTimeMillis: 1731 ms
// totalDocsExamined: 25947





// 18. Estatísticas de empréstimos por autor (top 10)
// Esta pipeline analisa os empréstimos agrupando por autores individuais, calcula:
// - total de empréstimos
// - empréstimos ativos (em curso ou atrasados)
// - total de renovações e média de renovações por empréstimo
// - número de categorias diferentes de recursos associados
// Ordena pelo total de empréstimos e limita aos top 10 autores.

db.Emprestimo.aggregate([
  {
    // Faz lookup para trazer informações do recurso associado a cada empréstimo
    $lookup: {
      from: "Recurso",
      let: { recurso_id: "$ID_recurso" },
      pipeline: [
        {
          $match: {
            $expr: { $eq: ["$_id", "$$recurso_id"] }
          }
        },
        {
          // Mantém apenas campos relevantes
          $project: {
            autores: 1,
            categoria: 1,
            tipo_recurso: 1
          }
        }
      ],
      as: "recurso_info"
    }
  },
  {
    // Desagrega o array de recursos para processar cada recurso individualmente
    $unwind: "$recurso_info"
  },
  {
    // Desagrega o array de autores, permitindo agrupar por autor individual
    $unwind: "$recurso_info.autores"
  },
  {
    // Agrupa por autor
    $group: {
      _id: "$recurso_info.autores",
      total_emprestimos: { $sum: 1 },
      emprestimos_ativos: {
        // Conta apenas empréstimos "em curso" ou "atrasado"
        $sum: {
          $cond: [
            { $in: ["$estado_emprestimo", ["em curso", "atrasado"]] },
            1,
            0
          ]
        }
      },
      total_renovacoes: { $sum: "$numero_renovacoes" },
      // Mantém um set de categorias distintas do autor
      categorias: { $addToSet: "$recurso_info.categoria" }
    }
  },
  {
    // Calcula média de renovações por empréstimo
    $addFields: {
      media_renovacoes: {
        $round: [
          { $divide: ["$total_renovacoes", "$total_emprestimos"] },
          2
        ]
      }
    }
  },
  {
    // Projeta campos finais para apresentação
    $project: {
      _id: 0,
      autor: "$_id",
      total_emprestimos: 1,
      emprestimos_ativos: 1,
      total_renovacoes: 1,
      media_renovacoes_por_emprestimo: "$media_renovacoes",
      categorias_diferentes: { $size: "$categorias" }
    }
  },
  {
    // Ordena pelo total de empréstimos (descendente)
    $sort: { total_emprestimos: -1 }
  },
  {
    // Limita a top 10 autores
    $limit: 10
  }
]);

// Tempos de execução
// executionTimeMillis: 5299 ms
// totalDocsExamined: 25947









//ÍNDICES




// 1. Índice em Recurso por disponibilidade e título
// Query 1 filtra recursos disponíveis e ordena por título.
// O índice permite filtrar e ordenar diretamente, evitando varredura completa da coleção (COLLSCAN), acelerando a execução.
db.Recurso.createIndex(
  { disponibilidade: 1, titulo: 1 },
  { name: "idx_disponibilidade_titulo" }
)


// 2. Índice em Emprestimo por título do recurso
// Queries que agrupam ou contam empréstimos por título de recurso (ex: Query 2).
// Melhora performance de $group e consultas que filtram por titulo_recurso.
db.Emprestimo.createIndex(
  { titulo_recurso: 1 },
  { name: "idx_titulo_recurso_emprestimo" }
)


// 3. Índice composto para multas pendentes
// Query 4 filtra multas pendentes e ordena por data de aplicação.
// Índice permite filtrar e ordenar diretamente em campos aninhados, evitando scan completo e sort em memória.
db.Emprestimo.createIndex(
  { "multa.estado_multa": 1, "multa.data_aplicacao": -1 },
  { name: "idx_multa_estado_data" }
)


// 4. Índice para empréstimos em curso ordenados por data
// Query 6 vai busca empréstimos 'em curso' e ordena por data de empréstimo descendente.
// Permite ao MongoDB usar o índice para filtrar e ordenar sem sort em memória.
db.Emprestimo.createIndex(
  { estado_emprestimo: 1, data_emprestimo: -1 },
  { name: "idx_estado_data_emprestimo" }
)


// 5. Índice para recursos em bom estado ordenados por título
// Queries que filtram recursos por estado e ordenam por título.
// Índice acelera filtro e ordenação combinados, útil para listas de recursos disponíveis.
db.Recurso.createIndex(
  { estado: 1, titulo: 1 },
  { name: "idx_estado_titulo" }
)


// 6. Índice composto para reservas ativas
// Query 8 filtra reservas ativas por recurso.
// Índice composto em estado_reserva e ID_recurso acelera filtro e possíveis joins (lookups) com Emprestimo.
db.Reserva.createIndex(
  { estado_reserva: 1, ID_recurso: 1 },
  { name: "idx_reserva_estado_recurso" }
)


// 7. Índices para agregações por utilizador
// Queries que agrupam empréstimos ou reservas por utilizador (ex: Queries 7, 9, 10).
// Índices em ID_utilizador aceleram $group e $lookup.
db.Emprestimo.createIndex(
  { ID_utilizador: 1 },
  { name: "idx_id_utilizador_emprestimo" }
)
db.Reserva.createIndex(
  { ID_utilizador: 1 },
  { name: "idx_id_utilizador_reserva" }
)


// 8. Índices para lookups de recursos
// Queries que fazem lookup entre Emprestimo/Reserva e Recurso (ex: Queries 8, 15, 16).
// Índices em ID_recurso aceleram o join interno do $lookup.
db.Emprestimo.createIndex(
  { ID_recurso: 1 },
  { name: "idx_id_recurso_emprestimo" }
)
db.Reserva.createIndex(
  { ID_recurso: 1 },
  { name: "idx_id_recurso_reserva" }
)


// 9. Índice para análise temporal
// Query 12 analisa empréstimos por data.
// Índice em data_emprestimo acelera filtros, ordenações e agregações temporais.
db.Emprestimo.createIndex(
  { data_emprestimo: 1 },
  { name: "idx_data_emprestimo" }
)


// 10. Índice para devoluções efetivas
// Queries que verificam devolução antecipada, no dia ou atrasada (Query 13).
// Índice em data_devolucao_efetiva e data_devolucao_prevista acelera filtro e comparação.
db.Emprestimo.createIndex(
  { data_devolucao_efetiva: 1, data_devolucao_prevista: 1 },
  { name: "idx_devolucoes" }
)


// 11. Índice para funcionários
// Query 14 analisa salários por cargo.
// Índice composto permite filtrar, agrupar e ordenar rapidamente por cargo e salário.
db.Utilizador.createIndex(
  { "detalhes_funcionario.cargo": 1, "detalhes_funcionario.salario": 1 },
  { name: "idx_funcionario_cargo_salario" }
)


// 12. Índice para análise por idade
// Query 15 agrupa utilizadores por faixa etária.
// Índice em idade acelera filtragem e agrupamento.
db.Utilizador.createIndex(
  { idade: 1 },
  { name: "idx_idade" }
)


// 13. Índice para tipo de utilizador e renovações
// Query 16 calcula total de empréstimos e percentagem de renovações por tipo.
// Índice composto acelera agrupamento e cálculos por tipo de utilizador.
db.Emprestimo.createIndex(
  { tipo_utilizador: 1, numero_renovacoes: 1 },
  { name: "idx_tipo_utilizador_renovacoes" }
)


// 14. Índice multikey para autores
// Query 18 analisa empréstimos por autor.
// Índice multikey permite buscar e agrupar rapidamente em arrays de autores.
db.Recurso.createIndex(
  { autores: 1 },
  { name: "idx_autores" }
)


// 15. Índice para categoria de recursos
// Queries 17 e 18 agrupam por categoria.
// Índice acelera $group, $match e ordenação por categoria.
db.Recurso.createIndex(
  { categoria: 1 },
  { name: "idx_categoria" }
)


// 16. Índice composto para estado de empréstimo
// Queries que filtram empréstimos por estado e verificam renovações.
// Índice acelera filtros condicionais e cálculos de percentagem de renovação.
db.Emprestimo.createIndex(
  { estado_emprestimo: 1, numero_renovacoes: 1 },
  { name: "idx_estado_renovacoes" }
)


// 17. Índice para idioma
// Query 11 analisa empréstimos por idioma do recurso.
// Índice acelera lookup e agrupamento por idioma.
db.Recurso.createIndex(
  { idioma: 1 },
  { name: "idx_idioma" }
)


// 18. Índice para título de recurso em reservas
// Query 9 e lookups para reservas.
// Índice acelera filtro e ordenação por título de recurso.
db.Reserva.createIndex(
  { titulo_recurso: 1 },
  { name: "idx_titulo_recurso_reserva" }
)






// OPERAÇOES CRUD ADICIONAIS 



// Objetivo:
// - Verificar todos os empréstimos que ainda estão "em curso"
// - Se a data_devolucao_prevista já passou, atualizar o estado para "atrasado"
// - Caso contrário, mantém "em curso"
db.Emprestimo.updateMany(
  {
    estado_emprestimo: "em curso"  // só processa empréstimos atualmente em curso
  },
  [
    {
      $set: {
        estado_emprestimo: {
          $cond: [
            // Se data_devolucao_prevista < hoje, então "atrasado"
            { $lt: [ { $toDate: "$data_devolucao_prevista" }, new Date() ] },
            "atrasado",
            // Senão mantém o estado atual
            "$estado_emprestimo"
          ]
        }
      }
    }
  ]
);



// Objetivo:
// - Para todos os empréstimos com estado "atrasado", calcular multa diária
// - Multiplicar 0,5 (valor diário) pelo número de dias em atraso
// - Definir campos da multa: valor, data de aplicação, estado e data de pagamento
db.Emprestimo.updateMany(
  { estado_emprestimo: "atrasado" }, // só processa empréstimos atrasados
  [
    {
      $set: {
        // Calcula multa: 0.5 por dia de atraso
        "multa.valor": {
          $multiply: [
            0.5,
            {
              $floor: { // arredonda para baixo o número de dias completos de atraso
                $divide: [
                  { $subtract: [ new Date(), { $toDate: "$data_devolucao_prevista" } ] }, // diferença em ms
                  1000 * 60 * 60 * 24 // converte ms para dias
                ]
              }
            }
          ]
        },
        // Define a data da aplicação da multa como a data prevista de devolução
        "multa.data_aplicacao": {
          $dateToString: { format: "%Y-%m-%d", date: { $toDate: "$data_devolucao_prevista" } }
        },
        "multa.estado_multa": "pendente", // marca multa como pendente
        "multa.data_pagamento": null // ainda não paga
      }
    }
  ]
);
