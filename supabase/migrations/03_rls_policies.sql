-- =====================================================================
-- 03_rls_policies.sql
-- Row Level Security — replica no banco as mesmas regras que já existem
-- no app: permissões por módulo (ver/criar/editar/excluir) definidas em
-- grupos_permissao.modulos, e "colaborador só vê o que é seu" nos
-- módulos de Custos, Gestão de Pessoas, Produtividade e Patrimônio.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Funções auxiliares (chamadas de dentro das policies)
-- ---------------------------------------------------------------------

-- Verifica se o usuário logado tem a permissão <acao> no módulo <p_modulo>
-- (ex: tem_permissao('custos','criar')).
create or replace function public.tem_permissao(p_modulo text, p_acao text)
returns boolean
language sql
security definer
stable
as $$
  select coalesce(
    (
      select (g.modulos -> p_modulo ->> p_acao)::boolean
      from public.usuarios u
      join public.grupos_permissao g on g.id = u.grupo_permissao_id
      where u.id = auth.uid()
    ),
    false
  );
$$;

-- Retorna o colaborador_id vinculado ao usuário logado (ou null).
create or replace function public.meu_colaborador_id()
returns uuid
language sql
security definer
stable
as $$
  select colaborador_id from public.usuarios where id = auth.uid();
$$;

-- true se o usuário logado pertence a um grupo de nível "gestor".
create or replace function public.sou_gestor()
returns boolean
language sql
security definer
stable
as $$
  select coalesce(
    (select g.nivel = 'gestor' from public.usuarios u join public.grupos_permissao g on g.id = u.grupo_permissao_id where u.id = auth.uid()),
    false
  );
$$;

-- ---------------------------------------------------------------------
-- Catálogos genéricos: todo usuário autenticado pode ver; escrever
-- exige permissão do módulo "controleAcesso".
-- (Bloco repetido via DO/loop para não escrever 13 vezes a mesma policy.)
-- ---------------------------------------------------------------------
do $$
declare
  tabelas text[] := array[
    'estados','cidades','funcoes','categorias','status_ferias','tipos_documento',
    'status_documento','tipos_custo','status_projeto','bases','tipos_atividade',
    'grupos_acesso','categorias_patrimonio','status_patrimonio'
  ];
  t text;
begin
  foreach t in array tabelas loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('create policy "ver_%1$s" on public.%1$s for select using (auth.uid() is not null);', t);
    execute format('create policy "criar_%1$s" on public.%1$s for insert with check (public.tem_permissao(''controleAcesso'',''criar''));', t);
    execute format('create policy "editar_%1$s" on public.%1$s for update using (public.tem_permissao(''controleAcesso'',''editar''));', t);
    execute format('create policy "excluir_%1$s" on public.%1$s for delete using (public.tem_permissao(''controleAcesso'',''excluir''));', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- grupos_permissao e usuarios — controle de acesso "de verdade"
-- ---------------------------------------------------------------------
alter table public.grupos_permissao enable row level security;
create policy "ver_grupos_permissao" on public.grupos_permissao for select using (auth.uid() is not null);
create policy "criar_grupos_permissao" on public.grupos_permissao for insert with check (public.tem_permissao('controleAcesso','criar'));
create policy "editar_grupos_permissao" on public.grupos_permissao for update using (public.tem_permissao('controleAcesso','editar'));
create policy "excluir_grupos_permissao" on public.grupos_permissao for delete using (public.tem_permissao('controleAcesso','excluir'));

alter table public.usuarios enable row level security;
create policy "ver_usuarios" on public.usuarios for select using (auth.uid() is not null);
create policy "criar_usuarios" on public.usuarios for insert with check (public.tem_permissao('controleAcesso','criar'));
create policy "editar_usuarios" on public.usuarios for update using (id = auth.uid() or public.tem_permissao('controleAcesso','editar'));
create policy "excluir_usuarios" on public.usuarios for delete using (public.tem_permissao('controleAcesso','excluir'));

-- ---------------------------------------------------------------------
-- Colaboradores e histórico salarial (dado sensível — LGPD)
-- ---------------------------------------------------------------------
alter table public.colaboradores enable row level security;
create policy "ver_colaboradores" on public.colaboradores for select using (auth.uid() is not null);
create policy "criar_colaboradores" on public.colaboradores for insert with check (public.tem_permissao('controleAcesso','criar'));
create policy "editar_colaboradores" on public.colaboradores for update using (public.tem_permissao('controleAcesso','editar'));
create policy "excluir_colaboradores" on public.colaboradores for delete using (public.tem_permissao('controleAcesso','excluir'));

alter table public.historico_salarial enable row level security;
create policy "ver_historico_salarial" on public.historico_salarial for select using (public.tem_permissao('controleAcesso','ver'));
create policy "criar_historico_salarial" on public.historico_salarial for insert with check (public.tem_permissao('controleAcesso','editar'));

-- ---------------------------------------------------------------------
-- Custos — colaborador só vê/mexe no que é dele; gestor vê tudo
-- ---------------------------------------------------------------------
alter table public.custos enable row level security;
create policy "ver_custos" on public.custos for select
  using (public.sou_gestor() or colaborador_id = public.meu_colaborador_id());
create policy "criar_custos" on public.custos for insert
  with check (public.tem_permissao('custos','criar'));
create policy "editar_custos" on public.custos for update
  using (public.tem_permissao('custos','editar'));
create policy "excluir_custos" on public.custos for delete
  using (public.tem_permissao('custos','excluir'));

-- ---------------------------------------------------------------------
-- Gestão de Pessoas: atestados, férias, treinamentos, acidentes, licenças
-- (mesmo padrão: colaborador só o próprio, gestor vê tudo)
-- ---------------------------------------------------------------------
do $$
declare
  tabelas text[] := array['atestados','ferias','treinamentos','acidentes','licencas'];
  t text;
begin
  foreach t in array tabelas loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('create policy "ver_%1$s" on public.%1$s for select using (public.sou_gestor() or colaborador_id = public.meu_colaborador_id());', t);
    execute format('create policy "criar_%1$s" on public.%1$s for insert with check (public.tem_permissao(''pessoas'',''criar''));', t);
    execute format('create policy "editar_%1$s" on public.%1$s for update using (public.tem_permissao(''pessoas'',''editar''));', t);
    execute format('create policy "excluir_%1$s" on public.%1$s for delete using (public.tem_permissao(''pessoas'',''excluir''));', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Produtividade: projetos, subtarefas, atividades
-- ---------------------------------------------------------------------
alter table public.projetos enable row level security;
create policy "ver_projetos" on public.projetos for select
  using (
    public.sou_gestor()
    or exists (select 1 from public.projeto_responsaveis pr where pr.projeto_id = id and pr.colaborador_id = public.meu_colaborador_id())
  );
create policy "criar_projetos" on public.projetos for insert with check (public.tem_permissao('produtividade','criar'));
create policy "editar_projetos" on public.projetos for update using (public.tem_permissao('produtividade','editar'));
create policy "excluir_projetos" on public.projetos for delete using (public.tem_permissao('produtividade','excluir'));

alter table public.projeto_responsaveis enable row level security;
create policy "ver_projeto_responsaveis" on public.projeto_responsaveis for select using (auth.uid() is not null);
create policy "criar_projeto_responsaveis" on public.projeto_responsaveis for insert with check (public.tem_permissao('produtividade','criar'));
create policy "excluir_projeto_responsaveis" on public.projeto_responsaveis for delete using (public.tem_permissao('produtividade','editar'));

alter table public.subtarefas enable row level security;
create policy "ver_subtarefas" on public.subtarefas for select
  using (
    public.sou_gestor()
    or responsavel_id = public.meu_colaborador_id()
    or exists (select 1 from public.projeto_responsaveis pr where pr.projeto_id = projeto_id and pr.colaborador_id = public.meu_colaborador_id())
  );
create policy "criar_subtarefas" on public.subtarefas for insert with check (public.tem_permissao('produtividade','criar'));
create policy "editar_subtarefas" on public.subtarefas for update using (public.tem_permissao('produtividade','editar'));
create policy "excluir_subtarefas" on public.subtarefas for delete using (public.tem_permissao('produtividade','excluir'));

alter table public.atividades enable row level security;
create policy "ver_atividades" on public.atividades for select
  using (public.sou_gestor() or responsavel_id = public.meu_colaborador_id());
create policy "criar_atividades" on public.atividades for insert with check (public.tem_permissao('produtividade','criar'));
create policy "editar_atividades" on public.atividades for update
  using (public.sou_gestor() or (responsavel_id = public.meu_colaborador_id() and public.tem_permissao('produtividade','editar')));
create policy "excluir_atividades" on public.atividades for delete using (public.tem_permissao('produtividade','excluir'));

-- ---------------------------------------------------------------------
-- Não Conformidades — colaborador só vê as que é responsável
-- ---------------------------------------------------------------------
alter table public.nao_conformidades enable row level security;
create policy "ver_nc" on public.nao_conformidades for select
  using (public.sou_gestor() or responsavel_id = public.meu_colaborador_id());
create policy "criar_nc" on public.nao_conformidades for insert with check (public.tem_permissao('naoConformidades','criar'));
create policy "editar_nc" on public.nao_conformidades for update using (public.tem_permissao('naoConformidades','editar'));
create policy "excluir_nc" on public.nao_conformidades for delete using (public.tem_permissao('naoConformidades','excluir'));

-- ---------------------------------------------------------------------
-- Controle Documental — visível a todos que têm o módulo liberado
-- (documento é referência compartilhada, não é "do colaborador")
-- ---------------------------------------------------------------------
alter table public.documentos enable row level security;
create policy "ver_documentos" on public.documentos for select using (public.tem_permissao('documentos','ver'));
create policy "criar_documentos" on public.documentos for insert with check (public.tem_permissao('documentos','criar'));
create policy "editar_documentos" on public.documentos for update using (public.tem_permissao('documentos','editar'));
create policy "excluir_documentos" on public.documentos for delete using (public.tem_permissao('documentos','excluir'));

-- ---------------------------------------------------------------------
-- Patrimônio — colaborador só vê o que está sob a responsabilidade dele
-- ---------------------------------------------------------------------
alter table public.patrimonios enable row level security;
create policy "ver_patrimonios" on public.patrimonios for select
  using (public.sou_gestor() or responsavel_id = public.meu_colaborador_id());
create policy "criar_patrimonios" on public.patrimonios for insert with check (public.tem_permissao('patrimonio','criar'));
create policy "editar_patrimonios" on public.patrimonios for update
  using (public.tem_permissao('patrimonio','editar'));
create policy "excluir_patrimonios" on public.patrimonios for delete using (public.tem_permissao('patrimonio','excluir'));

-- ---------------------------------------------------------------------
-- Histórico (polimórfico) — segue a visibilidade da entidade "pai"
-- Simplificado: gestor vê tudo; colaborador vê o histórico de itens
-- onde ele já teria acesso à entidade correspondente.
-- ---------------------------------------------------------------------
alter table public.historico enable row level security;
create policy "ver_historico" on public.historico for select
  using (
    public.sou_gestor()
    or (entidade_tipo = 'atividade' and exists (select 1 from public.atividades a where a.id = entidade_id and a.responsavel_id = public.meu_colaborador_id()))
    or (entidade_tipo = 'projeto' and exists (select 1 from public.projeto_responsaveis pr where pr.projeto_id = entidade_id and pr.colaborador_id = public.meu_colaborador_id()))
    or (entidade_tipo = 'subtarefa' and exists (select 1 from public.subtarefas s where s.id = entidade_id and s.responsavel_id = public.meu_colaborador_id()))
    or (entidade_tipo = 'nao_conformidade' and exists (select 1 from public.nao_conformidades n where n.id = entidade_id and n.responsavel_id = public.meu_colaborador_id()))
    or (entidade_tipo = 'documento' and public.tem_permissao('documentos','ver'))
    or (entidade_tipo = 'patrimonio' and exists (select 1 from public.patrimonios p where p.id = entidade_id and p.responsavel_id = public.meu_colaborador_id()))
  );
create policy "criar_historico" on public.historico for insert with check (auth.uid() is not null);
create policy "editar_historico" on public.historico for update using (auth.uid() is not null); -- suporta a função "Corrigir observação"

-- ---------------------------------------------------------------------
-- Conquistas e Próximos Passos — módulo "indicadores"
-- ---------------------------------------------------------------------
alter table public.conquistas enable row level security;
create policy "ver_conquistas" on public.conquistas for select using (public.tem_permissao('indicadores','ver'));
create policy "criar_conquistas" on public.conquistas for insert with check (public.tem_permissao('indicadores','criar'));
create policy "excluir_conquistas" on public.conquistas for delete using (public.tem_permissao('indicadores','excluir'));

alter table public.proximos_passos enable row level security;
create policy "ver_proximos_passos" on public.proximos_passos for select using (public.tem_permissao('indicadores','ver'));
create policy "editar_proximos_passos" on public.proximos_passos for all using (public.tem_permissao('indicadores','criar'));

-- ---------------------------------------------------------------------
-- Trilha de Auditoria — só gestor lê; qualquer usuário autenticado pode
-- inserir (é o próprio app registrando as ações, de qualquer perfil).
-- ---------------------------------------------------------------------
alter table public.audit_log enable row level security;
create policy "ver_audit_log" on public.audit_log for select using (public.sou_gestor());
create policy "criar_audit_log" on public.audit_log for insert with check (auth.uid() is not null);
