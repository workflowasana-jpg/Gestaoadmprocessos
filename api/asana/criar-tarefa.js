// api/asana/criar-tarefa.js
// POST /api/asana/criar-tarefa
// Body: { titulo, descricao?, responsavelEmail?, prazo? }  (prazo no formato YYYY-MM-DD)
// Retorna: { asanaTaskGid }
//
// Disparado por: submitAtividade() e submitProjeto() no SGQ, logo após salvar
// o registro localmente. O asanaTaskGid retornado deve ser salvo no campo
// "asanaTaskGid" da atividade/projeto correspondente.

const { asanaFetch } = require('./_client');

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Método não permitido. Use POST.' });
  }

  try {
    const { titulo, descricao, responsavelEmail, prazo } = req.body || {};
    if (!titulo) {
      return res.status(400).json({ error: 'Campo "titulo" é obrigatório.' });
    }

    const workspaceGid = process.env.ASANA_WORKSPACE_GID;
    const projectGid = process.env.ASANA_DEFAULT_PROJECT_GID;
    if (!workspaceGid) {
      return res.status(500).json({ error: 'ASANA_WORKSPACE_GID não configurado.' });
    }

    // Tenta localizar o usuário da Asana pelo e-mail do responsável (best-effort).
    let assigneeGid = null;
    if (responsavelEmail) {
      try {
        const users = await asanaFetch(`/workspaces/${workspaceGid}/users?opt_fields=email`);
        const encontrado = (users.data || []).find(
          (u) => (u.email || '').toLowerCase() === responsavelEmail.toLowerCase()
        );
        if (encontrado) assigneeGid = encontrado.gid;
      } catch (e) {
        console.warn('Não foi possível localizar o responsável na Asana:', e.message);
      }
    }

    const payload = {
      data: {
        name: titulo,
        notes: descricao || '',
        workspace: workspaceGid,
        ...(projectGid ? { projects: [projectGid] } : {}),
        ...(prazo ? { due_on: prazo } : {}),
        ...(assigneeGid ? { assignee: assigneeGid } : {}),
      },
    };

    const result = await asanaFetch('/tasks', {
      method: 'POST',
      body: JSON.stringify(payload),
    });

    return res.status(200).json({ asanaTaskGid: result.data.gid });
  } catch (err) {
    console.error('Erro ao criar tarefa na Asana:', err);
    // Importante: quem chamar este endpoint deve tratar a falha sem travar o
    // salvamento local (a atividade/projeto já foi salvo no SGQ antes desta chamada).
    return res.status(502).json({ error: err.message });
  }
};
