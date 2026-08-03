// api/asana/_client.js
// Cliente compartilhado para chamadas à API da Asana.
// O token fica em variável de ambiente (ASANA_TOKEN) — nunca no código.

const ASANA_BASE_URL = 'https://app.asana.com/api/1.0';

async function asanaFetch(path, options = {}) {
  const token = process.env.ASANA_TOKEN;
  if (!token) {
    throw new Error('ASANA_TOKEN não configurado nas variáveis de ambiente.');
  }

  const isFormData = options.body instanceof FormData;

  const res = await fetch(`${ASANA_BASE_URL}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(isFormData ? {} : { 'Content-Type': 'application/json' }),
      ...options.headers,
    },
  });

  const data = await res.json().catch(() => null);

  if (!res.ok) {
    const msg = (data && data.errors && data.errors[0] && data.errors[0].message) || res.statusText;
    throw new Error(`Asana API ${res.status}: ${msg}`);
  }

  return data;
}

module.exports = { asanaFetch, ASANA_BASE_URL };
