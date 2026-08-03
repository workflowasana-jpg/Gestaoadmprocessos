-- =====================================================================
-- 01_schema.sql — SGQ (Sistema de Gestão da Qualidade) — DTEL
-- Schema completo para Supabase (PostgreSQL).
-- Rode este arquivo primeiro, na ordem: 01 → 02 → 03 → 04
-- =====================================================================
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- CONTROLE DE ACESSO
-- ---------------------------------------------------------------------
create table public.grupos_permissao (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  nivel text not null check (nivel in ('gestor','colaborador')),
  -- Matriz de permissões, mesmo formato usado no app:
  -- {"controleAcesso":{"ver":true,"criar":true,"editar":true,"excluir":true}, "custos":{...}, ...}
  modulos jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- CADASTROS / CATÁLOGOS
-- ---------------------------------------------------------------------
create table public.estados (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  sigla text not null
);

create table public.cidades (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  estado_id uuid references public.estados(id) on delete set null
);

create table public.funcoes (
  id uuid primary key default gen_random_uuid(),
  nome text not null
);

create table public.categorias (
  id uuid primary key default gen_random_uuid(),
  nome text not null
);

create table public.status_ferias (
  id uuid primary key default gen_random_uuid(),
  nome text not null
);

create table public.tipos_documento (
  id uuid primary key default gen_random_uuid(),
  nome text not null
);

create table public.status_documento (
  id uuid primary key default gen_random_uuid(),
  nome text not null
);

create table public.tipos_custo (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  exige_anexo boolean not null default false
);

create table public.status_projeto (
  id uuid primary key default gen_random_uuid(),
  nome text not null
);

create table public.bases (
  id uuid primary key default gen_random_uuid(),
  nome text not null
);

create table public.tipos_atividade (
  id uuid primary key default gen_random_uuid(),
  nome text not null
);

create table public.grupos_acesso (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  descricao text
);

create table public.categorias_patrimonio (
  id uuid primary key default gen_random_uuid(),
  nome text not null
);

create table public.status_patrimonio (
  id uuid primary key default gen_random_uuid(),
  nome text not null
);

-- ---------------------------------------------------------------------
-- COLABORADORES
-- ---------------------------------------------------------------------
create table public.colaboradores (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  data_nascimento date,
  data_admissao date,
  funcao_id uuid references public.funcoes(id) on delete set null,
  salario_atual numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

create table public.historico_salarial (
  id uuid primary key default gen_random_uuid(),
  colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
  data date not null,
  valor numeric(12,2) not null,
  obs text
);

-- ---------------------------------------------------------------------
-- USUÁRIOS (perfil vinculado ao auth.users do Supabase Auth)
-- O login/senha ficam a cargo do Supabase Auth — esta tabela só guarda
-- o perfil (nome, grupo de permissão, colaborador vinculado).
-- ---------------------------------------------------------------------
create table public.usuarios (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text not null,
  email text not null unique,
  grupo_permissao_id uuid references public.grupos_permissao(id) on delete restrict,
  colaborador_id uuid references public.colaboradores(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- PRODUTIVIDADE: PROJETOS, SUBTAREFAS, ATIVIDADES
-- ---------------------------------------------------------------------
create table public.projetos (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  data_inicio date not null,
  prazo date not null,
  status_projeto_id uuid references public.status_projeto(id) on delete set null,
  descricao text,
  observacao text,
  asana_task_gid text,
  created_at timestamptz not null default now()
);

create table public.projeto_responsaveis (
  projeto_id uuid not null references public.projetos(id) on delete cascade,
  colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
  primary key (projeto_id, colaborador_id)
);

create table public.subtarefas (
  id uuid primary key default gen_random_uuid(),
  projeto_id uuid not null references public.projetos(id) on delete cascade,
  titulo text not null,
  responsavel_id uuid references public.colaboradores(id) on delete set null,
  status text not null default 'Aberta' check (status in ('Aberta','Em andamento','Concluída','Cancelada')),
  created_at timestamptz not null default now()
);

-- Não Conformidades precisa existir antes de Atividades (referência cruzada),
-- a referência de volta (atividade_vinculada_id) é adicionada em 02_relacoes_cruzadas.sql
create table public.nao_conformidades (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  descricao text not null,
  categoria_id uuid references public.categorias(id) on delete set null,
  cidade_id uuid references public.cidades(id) on delete set null,
  base_id uuid references public.bases(id) on delete set null,
  data_ocorrencia date not null,
  responsavel_id uuid references public.colaboradores(id) on delete set null,
  causa_raiz text,
  plano_acao text,
  status text not null default 'Aberta' check (status in ('Aberta','Em análise','Em tratativa (CAPA)','Concluída','Reprovada')),
  atividade_vinculada_id uuid, -- FK adicionada em 02_relacoes_cruzadas.sql
  created_at timestamptz not null default now()
);

create table public.atividades (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  tipo_documento_id uuid references public.tipos_documento(id) on delete set null,
  responsavel_id uuid references public.colaboradores(id) on delete set null,
  status_id uuid references public.status_documento(id) on delete set null,
  data_inicio date not null,
  prazo date not null,
  descricao text,
  observacao text,
  origem_nc_id uuid references public.nao_conformidades(id) on delete set null,
  asana_task_gid text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- CUSTOS
-- ---------------------------------------------------------------------
create table public.custos (
  id uuid primary key default gen_random_uuid(),
  tipo_custo_id uuid references public.tipos_custo(id) on delete set null,
  colaborador_id uuid references public.colaboradores(id) on delete set null,
  valor_combustivel numeric(12,2) not null default 0,
  valor_alimentacao numeric(12,2) not null default 0,
  km numeric(10,2) not null default 0,
  categoria_id uuid references public.categorias(id) on delete set null,
  cidade_id uuid references public.cidades(id) on delete set null,
  base_id uuid references public.bases(id) on delete set null,
  projeto_id uuid references public.projetos(id) on delete set null,
  data date not null,
  obs text,
  anexo_url text, -- URL no Supabase Storage (evidência obrigatória para alguns tipos)
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- GESTÃO DE PESSOAS
-- ---------------------------------------------------------------------
create table public.atestados (
  id uuid primary key default gen_random_uuid(),
  colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
  data_inicio date not null,
  data_fim date not null,
  dias integer not null,
  cid text,
  obs text,
  created_at timestamptz not null default now()
);

create table public.ferias (
  id uuid primary key default gen_random_uuid(),
  colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
  data_inicio date not null,
  data_fim date not null,
  status_ferias_id uuid references public.status_ferias(id) on delete set null,
  obs text,
  created_at timestamptz not null default now()
);

create table public.treinamentos (
  id uuid primary key default gen_random_uuid(),
  colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
  nome text not null,
  data date not null,
  carga_horaria numeric(6,2) not null default 0,
  obs text,
  created_at timestamptz not null default now()
);

create table public.acidentes (
  id uuid primary key default gen_random_uuid(),
  colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
  data date not null,
  base_id uuid references public.bases(id) on delete set null,
  tipo_afastamento text not null check (tipo_afastamento in ('Com afastamento','Sem afastamento')),
  dias_afastamento integer not null default 0,
  cid text,
  cat_emitida boolean not null default false,
  numero_cat text,
  descricao text not null,
  obs text,
  anexo_url text,
  status text not null default 'Em investigação' check (status in ('Em investigação','Concluído')),
  created_at timestamptz not null default now()
);

create table public.licencas (
  id uuid primary key default gen_random_uuid(),
  colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
  tipo text not null check (tipo in ('Maternidade','Paternidade')),
  data_inicio date not null,
  data_fim date not null,
  obs text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- CONTROLE DOCUMENTAL
-- ---------------------------------------------------------------------
create table public.documentos (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  tipo_documento_id uuid references public.tipos_documento(id) on delete set null,
  versao text not null default '1.0',
  status_fluxo text not null default 'Rascunho' check (status_fluxo in ('Rascunho','Em revisão','Aprovado','Publicado','Obsoleto')),
  responsavel_id uuid references public.colaboradores(id) on delete set null,
  data_criacao date not null default current_date,
  data_ultima_revisao date not null default current_date,
  periodicidade_revisao_dias integer not null default 365,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- PATRIMÔNIO
-- ---------------------------------------------------------------------
create table public.patrimonios (
  id uuid primary key default gen_random_uuid(),
  codigo_patrimonio text not null unique,
  descricao text not null,
  categoria_patrimonio_id uuid references public.categorias_patrimonio(id) on delete set null,
  responsavel_id uuid references public.colaboradores(id) on delete set null,
  base_id uuid references public.bases(id) on delete set null,
  cidade_id uuid references public.cidades(id) on delete set null,
  data_aquisicao date,
  valor_aquisicao numeric(12,2) default 0,
  fornecedor text,
  nota_fiscal text,
  garantia_ate date,
  status_patrimonio_id uuid references public.status_patrimonio(id) on delete set null,
  motivo_baixa text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- HISTÓRICO (tabela única polimórfica — substitui os arrays embutidos
-- do protótipo, usada por atividades, projetos, subtarefas, não
-- conformidades, documentos e patrimônios)
-- ---------------------------------------------------------------------
create table public.historico (
  id uuid primary key default gen_random_uuid(),
  entidade_tipo text not null check (entidade_tipo in ('atividade','projeto','subtarefa','nao_conformidade','documento','patrimonio')),
  entidade_id uuid not null,
  data timestamptz not null default now(),
  autor_id uuid references public.usuarios(id) on delete set null,
  autor_nome text not null,
  texto text not null,
  status text,
  imagem_url text, -- URL no Supabase Storage (prints/fotos anexadas à observação)
  origem_subtarefa text, -- preenchido quando o registro é espelhado de uma subtarefa no histórico do projeto
  editado boolean not null default false,
  texto_original text,
  data_edicao timestamptz,
  autor_edicao_id uuid references public.usuarios(id) on delete set null
);
create index idx_historico_entidade on public.historico(entidade_tipo, entidade_id);

-- ---------------------------------------------------------------------
-- INDICADORES: CONQUISTAS E PRÓXIMOS PASSOS
-- ---------------------------------------------------------------------
create table public.conquistas (
  id uuid primary key default gen_random_uuid(),
  descricao text not null,
  valor_economizado numeric(12,2) not null default 0,
  tempo_economizado_horas numeric(8,2) not null default 0,
  data date not null,
  criado_por uuid references public.usuarios(id) on delete set null,
  created_at timestamptz not null default now()
);

-- Registro único (texto livre) de "próximos passos" do setor.
create table public.proximos_passos (
  id uuid primary key default gen_random_uuid(),
  texto text not null default '',
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid references public.usuarios(id) on delete set null
);

-- ---------------------------------------------------------------------
-- TRILHA DE AUDITORIA
-- ---------------------------------------------------------------------
create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  data timestamptz not null default now(),
  usuario_id uuid references public.usuarios(id) on delete set null,
  usuario_nome text not null,
  modulo text not null,
  acao text not null,
  descricao text not null
);
create index idx_audit_log_data on public.audit_log(data desc);

-- ---------------------------------------------------------------------
-- Índices de apoio (colunas mais usadas em filtros "colaborador só vê o
-- próprio" e em listagens por data)
-- ---------------------------------------------------------------------
create index idx_custos_colaborador on public.custos(colaborador_id);
create index idx_atestados_colaborador on public.atestados(colaborador_id);
create index idx_ferias_colaborador on public.ferias(colaborador_id);
create index idx_treinamentos_colaborador on public.treinamentos(colaborador_id);
create index idx_acidentes_colaborador on public.acidentes(colaborador_id);
create index idx_licencas_colaborador on public.licencas(colaborador_id);
create index idx_atividades_responsavel on public.atividades(responsavel_id);
create index idx_projeto_resp_colaborador on public.projeto_responsaveis(colaborador_id);
create index idx_patrimonios_responsavel on public.patrimonios(responsavel_id);
create index idx_nc_responsavel on public.nao_conformidades(responsavel_id);
