// api/asana/atualizar-tarefa.js
// POST /api/asana/atualizar-tarefa
// Body: { asanaTaskGid, completed?: boolean, prazo?: 'YYYY-MM-DD' }
//
// Disparado por: atualizarAtividade() e atualizarProjeto() no SGQ, quando o
// status muda (ex: para "Concluída"/"Concluído" → completed: true).

const { asanaFetch } = require('./_client');

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Método não permitido. Use POST.' });
  }

  try {
    const { asanaTaskGid, completed, prazo } = req.body || {};
    if (!asanaTaskGid) {
      return res.status(400).json({ error: 'Campo "asanaTaskGid" é obrigatório.' });
    }

    const data = {};
    if (typeof completed === 'boolean') data.completed = completed;
    if (prazo) data.due_on = prazo;

    if (Object.keys(data).length === 0) {
      return res.status(400).json({ error: 'Nada para atualizar (informe "completed" e/ou "prazo").' });
    }

    const result = await asanaFetch(`/tasks/${asanaTaskGid}`, {
      method: 'PUT',
      body: JSON.stringify({ data }),
    });

    return res.status(200).json({ ok: true, task: result.data });
  } catch (err) {
    console.error('Erro ao atualizar tarefa na Asana:', err);
    return res.status(502).json({ error: err.message });
  }
};
