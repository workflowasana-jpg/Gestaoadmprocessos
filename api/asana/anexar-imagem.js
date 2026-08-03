// api/asana/anexar-imagem.js
// POST /api/asana/anexar-imagem
// Body: { asanaTaskGid, imagemBase64, nomeArquivo? }
//   imagemBase64 aceita tanto uma data URL ("data:image/jpeg;base64,....")
//   quanto uma string base64 pura — mesmo formato já usado pelo SGQ ao
//   anexar prints nas observações (fileToResizedDataURL).
//
// Disparado por: atualizarAtividade(), atualizarProjeto() e atualizarSubtarefa()
// no SGQ, quando a observação inclui um print/imagem anexado.

const { ASANA_BASE_URL } = require('./_client');

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Método não permitido. Use POST.' });
  }

  try {
    const { asanaTaskGid, imagemBase64, nomeArquivo } = req.body || {};
    if (!asanaTaskGid || !imagemBase64) {
      return res.status(400).json({ error: 'Campos "asanaTaskGid" e "imagemBase64" são obrigatórios.' });
    }

    const token = process.env.ASANA_TOKEN;
    if (!token) {
      return res.status(500).json({ error: 'ASANA_TOKEN não configurado.' });
    }

    const base64Data = imagemBase64.includes(',') ? imagemBase64.split(',')[1] : imagemBase64;
    const buffer = Buffer.from(base64Data, 'base64');
    const blob = new Blob([buffer], { type: 'image/jpeg' });

    const form = new FormData();
    form.append('file', blob, nomeArquivo || 'print.jpg');

    const asanaRes = await fetch(`${ASANA_BASE_URL}/tasks/${asanaTaskGid}/attachments`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: form,
    });

    const data = await asanaRes.json().catch(() => null);
    if (!asanaRes.ok) {
      const msg = (data && data.errors && data.errors[0] && data.errors[0].message) || asanaRes.statusText;
      throw new Error(`Asana API ${asanaRes.status}: ${msg}`);
    }

    return res.status(200).json({ ok: true, attachment: data.data });
  } catch (err) {
    console.error('Erro ao anexar imagem na tarefa da Asana:', err);
    return res.status(502).json({ error: err.message });
  }
};
