-- Controle Administrativo (tabelas com prefixo sgi_): rode este script inteiro no Supabase
-- Pode rodar de novo sem medo: o que já existe é mantido, com os dados.
-- (Dashboard > SQL Editor > New query > colar > Run)

create extension if not exists pgcrypto;

-- COLABORADORES -------------------------------------------------------
create table if not exists public.sgi_colaboradores (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  matricula     text unique,
  nome          text not null,
  email         text,
  cpf           text unique,
  funcao        text,
  data_admissao date,
  cidade        text,
  localidade    text,
  ativo         boolean not null default true,
  observacao    text
);

-- ATESTADOS / AFASTAMENTOS -------------------------------------------
create table if not exists public.sgi_atestados (
  id                 uuid primary key default gen_random_uuid(),
  created_at         timestamptz not null default now(),
  colaborador        text not null,
  matricula          text,
  tipo               text not null check (tipo in ('maternidade','paternidade','eleitoral','doenca','acidente','declaracao')),
  cid                text,
  data_inicio        date not null,
  data_fim           date not null,
  dias               integer,
  documento_entregue boolean default false,
  cat_emitida        boolean default false,
  observacao         text,
  constraint sgi_atestados_periodo check (data_fim >= data_inicio)
);

-- CUSTOS --------------------------------------------------------------
create table if not exists public.sgi_custos (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  categoria   text not null check (categoria in ('inventario','projeto','auditoria','endomarketing')),
  descricao   text not null,
  referencia  text,
  fornecedor  text,
  valor       numeric(14,2) not null default 0,
  data        date not null,
  status      text not null default 'previsto' check (status in ('previsto','aprovado','pago')),
  nota_fiscal text,
  observacao  text
);

-- FÉRIAS --------------------------------------------------------------
create table if not exists public.sgi_ferias (
  id                uuid primary key default gen_random_uuid(),
  created_at        timestamptz not null default now(),
  colaborador       text not null,
  matricula         text,
  aquisitivo_inicio date,
  aquisitivo_fim    date,
  data_inicio       date not null,
  data_fim          date not null,
  dias              integer,
  abono             boolean default false,
  adiantamento_13   boolean default false,
  status            text not null default 'programada' check (status in ('programada','aprovada','em_gozo','concluida')),
  observacao        text,
  constraint sgi_ferias_periodo check (data_fim >= data_inicio)
);

create index if not exists sgi_atestados_inicio_idx on public.sgi_atestados (data_inicio);
create index if not exists sgi_custos_data_idx      on public.sgi_custos (data);
create index if not exists sgi_ferias_inicio_idx    on public.sgi_ferias (data_inicio);

-- SEGURANÇA ------------------------------------------------------------
-- Só usuários logados (criados por você em Authentication > Users)
-- conseguem ler e gravar. Sem login, nada é acessível.
alter table public.sgi_colaboradores enable row level security;
alter table public.sgi_atestados enable row level security;
alter table public.sgi_custos    enable row level security;
alter table public.sgi_ferias    enable row level security;

drop policy if exists "logados_acesso_total" on public.sgi_colaboradores;
drop policy if exists "logados_acesso_total" on public.sgi_atestados;
drop policy if exists "logados_acesso_total" on public.sgi_custos;
drop policy if exists "logados_acesso_total" on public.sgi_ferias;

create policy "logados_acesso_total" on public.sgi_colaboradores for all to authenticated using (true) with check (true);
create policy "logados_acesso_total" on public.sgi_atestados for all to authenticated using (true) with check (true);
create policy "logados_acesso_total" on public.sgi_custos    for all to authenticated using (true) with check (true);
create policy "logados_acesso_total" on public.sgi_ferias    for all to authenticated using (true) with check (true);

-- ---------------------------------------------------------------------
-- JÁ RODOU A VERSÃO ANTIGA (tabelas sem prefixo) E TEM DADOS?
-- Em vez de rodar o script acima, rode só estas 3 linhas para renomear
-- as tabelas mantendo os dados e as regras de segurança:
--
-- alter table public.atestados rename to sgi_atestados;
-- alter table public.custos    rename to sgi_custos;
-- alter table public.ferias    rename to sgi_ferias;

-- =====================================================================
-- ENVIO DE ATESTADOS PELOS COLABORADORES
-- (pode rodar o arquivo inteiro de novo: nada é apagado)
-- =====================================================================

-- documento digital anexado ao atestado lançado
alter table public.sgi_atestados add column if not exists arquivo_path text;

-- envios aguardando conferência
create table if not exists public.sgi_atestados_envios (
  id             uuid primary key default gen_random_uuid(),
  created_at     timestamptz not null default now(),
  colaborador_id uuid references public.sgi_colaboradores(id) on delete set null,
  colaborador    text not null,
  matricula      text,
  tipo           text not null check (tipo in ('maternidade','paternidade','eleitoral','doenca','acidente','declaracao')),
  data_inicio    date not null,
  data_fim       date not null,
  observacao     text,
  arquivo_path   text not null,
  status         text not null default 'pendente' check (status in ('pendente','aprovado','recusado')),
  motivo_recusa  text,
  atestado_id    uuid,
  conferido_em   timestamptz,
  conferido_por  text,
  constraint sgi_envios_periodo check (data_fim >= data_inicio)
);
create index if not exists sgi_envios_status_idx on public.sgi_atestados_envios (status, created_at);

alter table public.sgi_atestados_envios enable row level security;
drop policy if exists "logados_acesso_total" on public.sgi_atestados_envios;
create policy "logados_acesso_total" on public.sgi_atestados_envios for all to authenticated using (true) with check (true);
-- Colaboradores (sem login) NÃO acessam a tabela diretamente.
-- Eles só usam as duas funções abaixo, que conferem CPF + matrícula.

-- 1) confere CPF + matrícula e devolve só o primeiro nome
create or replace function public.sgi_validar_colaborador(p_cpf text, p_matricula text)
returns text
language sql
security definer
set search_path = public
as $$
  select split_part(nome, ' ', 1)
  from public.sgi_colaboradores
  where regexp_replace(coalesce(cpf, ''), '[^0-9]', '', 'g') = regexp_replace(coalesce(p_cpf, ''), '[^0-9]', '', 'g')
    and trim(coalesce(matricula, '')) = trim(coalesce(p_matricula, ''))
    and ativo
  limit 1;
$$;

-- 2) registra o envio (confere tudo de novo no servidor)
create or replace function public.sgi_enviar_atestado(
  p_cpf text, p_matricula text, p_tipo text,
  p_inicio date, p_fim date, p_observacao text, p_arquivo text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  c public.sgi_colaboradores%rowtype;
  novo uuid;
begin
  select * into c
  from public.sgi_colaboradores
  where regexp_replace(coalesce(cpf, ''), '[^0-9]', '', 'g') = regexp_replace(coalesce(p_cpf, ''), '[^0-9]', '', 'g')
    and trim(coalesce(matricula, '')) = trim(coalesce(p_matricula, ''))
    and ativo
  limit 1;
  if not found then raise exception 'Colaborador não encontrado. Confira o CPF e a matrícula.'; end if;

  if p_tipo not in ('maternidade','paternidade','eleitoral','doenca','acidente','declaracao') then raise exception 'Tipo de atestado inválido.'; end if;
  if p_inicio is null or p_fim is null or p_fim < p_inicio then raise exception 'Confira as datas: o fim não pode ser antes do início.'; end if;
  if p_fim - p_inicio > 200 then raise exception 'Período muito longo. Confira as datas.'; end if;
  if p_inicio < current_date - 120 then raise exception 'A data de início é muito antiga. Fale com a supervisão.'; end if;
  if p_arquivo is null or p_arquivo !~ '^envios/[0-9a-f-]{36}\.(jpg|png|webp|pdf)$' then raise exception 'Anexe a foto ou o PDF do atestado.'; end if;
  if (select count(*) from public.sgi_atestados_envios where colaborador_id = c.id and status = 'pendente') >= 5 then
    raise exception 'Você já tem 5 envios aguardando conferência. Aguarde a supervisão.';
  end if;

  insert into public.sgi_atestados_envios
    (colaborador_id, colaborador, matricula, tipo, data_inicio, data_fim, observacao, arquivo_path)
  values
    (c.id, c.nome, c.matricula, p_tipo, p_inicio, p_fim, nullif(trim(p_observacao), ''), p_arquivo)
  returning id into novo;
  return novo;
end;
$$;

revoke all on function public.sgi_validar_colaborador(text, text) from public;
revoke all on function public.sgi_enviar_atestado(text, text, text, date, date, text, text) from public;
grant execute on function public.sgi_validar_colaborador(text, text) to anon, authenticated;
grant execute on function public.sgi_enviar_atestado(text, text, text, date, date, text, text) to anon, authenticated;

-- ARQUIVOS (fotos/PDF dos atestados) ----------------------------------
-- Pasta privada: colaborador só consegue ENVIAR; só quem tem login abre.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('sgi-atestados', 'sgi-atestados', false, 10485760,
        array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "sgi_envio_upload" on storage.objects;
create policy "sgi_envio_upload" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'sgi-atestados' and (storage.foldername(name))[1] = 'envios');

drop policy if exists "sgi_atestados_leitura" on storage.objects;
create policy "sgi_atestados_leitura" on storage.objects
  for select to authenticated
  using (bucket_id = 'sgi-atestados');

drop policy if exists "sgi_atestados_exclusao" on storage.objects;
create policy "sgi_atestados_exclusao" on storage.objects
  for delete to authenticated
  using (bucket_id = 'sgi-atestados');

-- =====================================================================
-- NOVO TIPO: DECLARAÇÃO
-- Atualiza a regra de tipos das tabelas que já existem.
-- =====================================================================
do $$
declare r record;
begin
  for r in
    select rel.relname, con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    where rel.relnamespace = 'public'::regnamespace
      and rel.relname in ('sgi_atestados', 'sgi_atestados_envios')
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%tipo%'
  loop
    execute format('alter table public.%I drop constraint %I', r.relname, r.conname);
  end loop;
end $$;

alter table public.sgi_atestados add constraint sgi_atestados_tipo_check
  check (tipo in ('maternidade','paternidade','eleitoral','doenca','acidente','declaracao'));
alter table public.sgi_atestados_envios add constraint sgi_envios_tipo_check
  check (tipo in ('maternidade','paternidade','eleitoral','doenca','acidente','declaracao'));

-- =====================================================================
-- BANCO DE HORAS (importado do Relatório de Ponto em PDF)
-- =====================================================================
create table if not exists public.sgi_banco_horas (
  id                 uuid primary key default gen_random_uuid(),
  created_at         timestamptz not null default now(),
  colaborador_id     uuid references public.sgi_colaboradores(id) on delete set null,
  colaborador        text not null,
  cpf                text not null,
  matricula_ponto    text,
  cargo              text,
  periodo_inicio     date not null,
  periodo_fim        date not null,
  saldo_anterior_min integer,
  saldo_periodo_min  integer,
  saldo_atual_min    integer,
  debito_min         integer,
  credito_min        integer,
  horas_trab_min     integer,
  dias_trabalhados   integer,
  faltas_min         integer,
  atrasos_min        integer,
  fechamento_min     integer,
  dias               jsonb not null default '[]'::jsonb,
  arquivo_nome       text,
  emitido_em         text,
  constraint sgi_banco_horas_periodo_unico unique (cpf, periodo_inicio, periodo_fim)
);
create index if not exists sgi_banco_horas_cpf_idx on public.sgi_banco_horas (cpf, periodo_fim desc);

alter table public.sgi_banco_horas enable row level security;
drop policy if exists "logados_acesso_total" on public.sgi_banco_horas;
create policy "logados_acesso_total" on public.sgi_banco_horas for all to authenticated using (true) with check (true);

-- =====================================================================
-- ANEXOS NOS LANÇAMENTOS DE ATESTADO E CUSTO
-- =====================================================================
alter table public.sgi_custos add column if not exists arquivo_path text;
alter table public.sgi_atestados add column if not exists arquivo_path text;

-- aceita também o XML da nota fiscal
update storage.buckets
   set allowed_mime_types = array['image/jpeg','image/png','image/webp','application/pdf','application/xml','text/xml']
 where id = 'sgi-atestados';

-- quem tem login pode anexar arquivos nas pastas atestados/ e custos/
drop policy if exists "sgi_anexos_upload_logados" on storage.objects;
create policy "sgi_anexos_upload_logados" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'sgi-atestados' and (storage.foldername(name))[1] in ('atestados', 'custos'));

-- =====================================================================
-- NOVA CATEGORIA DE CUSTO: ENDOMARKETING
-- =====================================================================
do $$
declare r record;
begin
  for r in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    where rel.relnamespace = 'public'::regnamespace
      and rel.relname = 'sgi_custos'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%categoria%'
  loop
    execute format('alter table public.sgi_custos drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.sgi_custos add constraint sgi_custos_categoria_check
  check (categoria in ('inventario','projeto','auditoria','endomarketing'));
