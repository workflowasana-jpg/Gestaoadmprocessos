// api/asana/comentar-tarefa.js
// POST /api/asana/comentar-tarefa
// Body: { asanaTaskGid, texto }
//
// Disparado por: atualizarAtividade(), atualizarProjeto() e atualizarSubtarefa()
// no SGQ, toda vez que uma nova observação é registrada no histórico.

const { asanaFetch } = require('./_client');

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Método não permitido. Use POST.' });
  }

  try {
    const { asanaTaskGid, texto } = req.body || {};
    if (!asanaTaskGid || !texto) {
      return res.status(400).json({ error: 'Campos "asanaTaskGid" e "texto" são obrigatórios.' });
    }

    const result = await asanaFetch(`/tasks/${asanaTaskGid}/stories`, {
      method: 'POST',
      body: JSON.stringify({ data: { text: texto } }),
    });

    return res.status(200).json({ ok: true, story: result.data });
  } catch (err) {
    console.error('Erro ao comentar na tarefa da Asana:', err);
    return res.status(502).json({ error: err.message });
  }
};
