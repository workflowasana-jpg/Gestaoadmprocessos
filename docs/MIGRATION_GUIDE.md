# Guia de Migração — SGQ: localStorage → Supabase + Vercel

Este guia explica como usar os arquivos deste pacote para sair do protótipo (dados no navegador) para um banco de dados real.

## 1. Rodar o SQL no Supabase

No painel do Supabase → **SQL Editor**, rode os arquivos da pasta `sql/` **nesta ordem exata**:

1. `01_schema.sql` — cria todas as tabelas
2. `02_relacoes_cruzadas.sql` — adiciona a referência cruzada entre Atividades e Não Conformidades
3. `03_rls_policies.sql` — ativa o RLS (segurança por linha) e recria, dentro do banco, as mesmas regras de permissão que já existem no app
4. `04_seed.sql` — popula os catálogos padrão (estados, tipos de custo, status, grupos de permissão, etc.)

Alternativa via CLI (`supabase db push`): coloque os 4 arquivos em `supabase/migrations/` com prefixo numérico (já estão nomeados assim) e rode `supabase db push` a partir da pasta do projeto.

## 2. Autenticação — trocando o login do protótipo pelo Supabase Auth

Hoje o app tem uma lista de e-mails com senha em texto puro no `localStorage`. Isso não é seguro nem escalável. A partir daqui, quem cuida de login/senha é o **Supabase Auth** — a tabela `public.usuarios` vira só o *perfil* (nome, grupo de permissão, colaborador vinculado), referenciando `auth.users(id)`.

### Criando o primeiro usuário administrador

1. Supabase → **Authentication → Users → Add user** (defina e-mail e senha).
2. Copie o `id` (UUID) desse usuário criado.
3. Rode no SQL Editor:

```sql
insert into public.usuarios (id, nome, email, grupo_permissao_id)
values (
  '<uuid-do-usuario-criado>',
  'Administrador',
  'admin@suaempresa.com',
  (select id from public.grupos_permissao where nome = 'Administrador da Qualidade')
);
```

Depois disso, esse usuário já consegue logar pelo Supabase Auth e o app (uma vez integrado) reconhece o perfil dele automaticamente.

### Login no frontend

```js
const { data, error } = await supabase.auth.signInWithPassword({ email, password });
```

## 3. Como o RLS substitui a lógica de permissão do app

O app hoje decide o que mostrar/esconder no JavaScript (`can('modulo','acao')`, filtros de "colaborador só vê o próprio"). Isso é ótimo para a experiência do usuário, mas **não é segurança de verdade** — alguém com o DevTools aberto poderia burlar. No banco, o RLS garante isso de verdade, mesmo que o frontend tente pedir dados que não devia.

As funções `public.tem_permissao()`, `public.sou_gestor()` e `public.meu_colaborador_id()` (criadas em `03_rls_policies.sql`) replicam exatamente a mesma matriz de permissões (`grupos_permissao.modulos`) e a mesma regra de "colaborador só vê o seu" que já existem no app — então a lógica de tela pode continuar como está, ela só passa a ser reforçada pelo banco também.

## 4. Convertendo o frontend: exemplo de padrão

O app hoje faz tudo direto em `DB` (um objeto grande em memória, persistido via `localStorage.setItem`). A conversão é: trocar cada leitura/escrita em `DB.xxx` por uma chamada ao Supabase. Sugestão de ordem (do mais simples pro mais complexo):

1. Catálogos (estados, cidades, tipos de custo, etc.) — CRUD simples, sem relação com usuário logado.
2. Colaboradores.
3. Custos, Atestados, Férias, Treinamentos, Acidentes, Licenças — já usam `colaborador_id`, RLS já filtra sozinho.
4. Atividades, Projetos, Subtarefas, Não Conformidades, Documentos, Patrimônio — envolvem o histórico polimórfico.
5. Indicadores, Relatórios, Conquistas, Auditoria — são só leituras agregadas dos dados acima.

### Exemplo: cadastro "Estados" (antes / depois)

**Antes (protótipo, localStorage):**
```js
DB.estados.push({id: uid('est'), nome, sigla});
saveDB();
renderCrudCatalogo(cat);
```

**Depois (Supabase):**
```js
const { error } = await supabase.from('estados').insert({ nome, sigla });
if (error) { alert(error.message); return; }
await renderCrudCatalogo(cat); // a função passa a buscar via supabase.from('estados').select('*')
```

### Exemplo: histórico polimórfico (atividade)

**Antes:** `a.historico.push({...})` dentro do array em memória.

**Depois:**
```js
await supabase.from('historico').insert({
  entidade_tipo: 'atividade',
  entidade_id: atividadeId,
  autor_id: session.user.id,
  autor_nome: perfil.nome,
  texto,
  status: statusNome,
  imagem_url: imagemUrl, // null se não houver anexo
});
```
E para exibir o histórico de uma atividade:
```js
const { data: historico } = await supabase
  .from('historico')
  .select('*')
  .eq('entidade_tipo', 'atividade')
  .eq('entidade_id', atividadeId)
  .order('data', { ascending: false });
```

## 5. Anexos/imagens

Veja `storage/README.md` — resumo: criar o bucket `anexos`, trocar o `fileToResizedDataURL()` (que gera base64) por um upload real (`supabase.storage.from('anexos').upload(...)`), e salvar a **URL** retornada na coluna `anexo_url`/`imagem_url` em vez do base64 inteiro.

## 6. Deploy no Vercel

1. Conecte o repositório Git ao Vercel (import project).
2. Em **Settings → Environment Variables**, cadastre `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` e (se for usar) `SUPABASE_SERVICE_ROLE_KEY`/`ASANA_TOKEN` — separadas por ambiente (Production / Preview / Development), nunca comitadas.
3. Siga o fluxo de branches (`main` = produção, `homolog` = testes com preview automático) já descrito em `integracao-asana-plano.md`, seção "Controle de versão (Git) e fluxo de homologação".

## 7. Ordem de trabalho sugerida

- [ ] Rodar os 4 arquivos SQL no projeto Supabase
- [ ] Criar o primeiro usuário admin (seção 2 acima)
- [ ] Criar o bucket `anexos` e as policies (`storage/README.md`)
- [ ] Converter o módulo de Cadastros (catálogos) — é o mais simples, serve de "molde"
- [ ] Converter Colaboradores
- [ ] Converter Custos / Gestão de Pessoas
- [ ] Converter Produtividade (Atividades/Projetos/Subtarefas) + histórico polimórfico
- [ ] Converter Não Conformidades, Documentos, Patrimônio
- [ ] Converter Indicadores/Relatórios/Conquistas/Auditoria (leitura agregada)
- [ ] Trocar o login por `supabase.auth.signInWithPassword`
- [ ] Testar cada módulo logado como Gestor e como Colaborador, confirmando que o RLS bloqueia o que deveria
