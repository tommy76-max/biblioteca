db.Emprestimo.updateMany(
  {
    estado_emprestimo: "em curso"  // só atualizar empréstimos em curso
  },
  [
    {
      $set: {
        estado_emprestimo: {
          $cond: [
            { $lt: [ { $toDate: "$data_devolucao_prevista" }, new Date() ] },
            "atrasado",
            "$estado_emprestimo"
          ]
        }
      }
    }
  ]
);



db.Emprestimo.updateMany(
  { estado_emprestimo: "atrasado" },
  [
    {
      $set: {
        "multa.valor": {
          $multiply: [
            0.5,
            {
              $floor: {
                $divide: [
                  { $subtract: [ new Date(), { $toDate: "$data_devolucao_prevista" } ] },
                  1000 * 60 * 60 * 24
                ]
              }
            }
          ]
        },
        "multa.data_aplicacao": {
          $dateToString: { format: "%Y-%m-%d", date: { $toDate: "$data_devolucao_prevista" } }
        },
        "multa.estado_multa": "pendente",
        "multa.data_pagamento": null
      }
    }
  ]
);




