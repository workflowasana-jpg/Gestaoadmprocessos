# Storage (Supabase) — anexos e evidências

O protótipo guarda imagens (prints de observação, evidências de custo, fotos de patrimônio) como base64 direto no `localStorage`. Isso não escala num banco real — a recomendação é usar o **Supabase Storage** e salvar apenas a URL no banco (colunas `anexo_url` / `imagem_url` já previstas no schema).

## 1. Criar o bucket

No painel do Supabase → Storage → New bucket:

- Nome: `anexos`
- Público: **não** (privado) — o acesso é controlado por policy, não por URL pública direta

## 2. Policies do bucket (Storage → Policies)

```sql
-- Leitura: qualquer usuário autenticado pode ler os arquivos
create policy "anexos_select"
on storage.objects for select
using (bucket_id = 'anexos' and auth.uid() is not null);

-- Upload: qualquer usuário autenticado pode enviar arquivo
create policy "anexos_insert"
on storage.objects for insert
with check (bucket_id = 'anexos' and auth.uid() is not null);
```

Se quiser restringir upload por módulo (ex: só quem tem permissão de `custos.criar`), dá para reaproveitar a função `public.tem_permissao(...)` já criada em `03_rls_policies.sql` dentro do `with check`.

## 3. Estrutura de pastas sugerida dentro do bucket

```
anexos/
├── custos/{custo_id}.jpg
├── atividades/{historico_id}.jpg
├── projetos/{historico_id}.jpg
├── nao-conformidades/{historico_id}.jpg
├── documentos/{historico_id}.jpg
├── patrimonio/{historico_id}.jpg
└── acidentes/{acidente_id}.jpg
```

## 4. No frontend

```js
// Upload
const { data, error } = await supabase.storage
  .from('anexos')
  .upload(`custos/${custoId}.jpg`, file);

// Pega a URL para salvar na coluna anexo_url/imagem_url
const { data: urlData } = supabase.storage
  .from('anexos')
  .getPublicUrl(`custos/${custoId}.jpg`); // ou createSignedUrl se o bucket for privado
```

> Como o bucket é privado, prefira `createSignedUrl` (URL temporária) na hora de **exibir** a imagem, em vez de `getPublicUrl`.
