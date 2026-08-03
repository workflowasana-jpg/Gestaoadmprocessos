-- =====================================================================
-- 04_seed.sql
-- Dados iniciais de configuração — os mesmos catálogos e grupos de
-- permissão que já vêm por padrão no protótipo (seedDB() no app).
-- Não inclui colaboradores/usuários de exemplo: isso você cria depois
-- de configurar o primeiro usuário administrador (ver MIGRATION_GUIDE.md).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Grupos de Permissão padrão
-- ---------------------------------------------------------------------
insert into public.grupos_permissao (nome, nivel, modulos) values
('Administrador da Qualidade', 'gestor', '{
  "controleAcesso": {"ver": true, "criar": true, "editar": true, "excluir": true},
  "custos": {"ver": true, "criar": true, "editar": true, "excluir": true},
  "pessoas": {"ver": true, "criar": true, "editar": true, "excluir": true},
  "produtividade": {"ver": true, "criar": true, "editar": true, "excluir": true},
  "indicadores": {"ver": true, "criar": true, "editar": true, "excluir": true},
  "naoConformidades": {"ver": true, "criar": true, "editar": true, "excluir": true},
  "documentos": {"ver": true, "criar": true, "editar": true, "excluir": true},
  "relatorios": {"ver": true, "criar": true, "editar": true, "excluir": true},
  "patrimonio": {"ver": true, "criar": true, "editar": true, "excluir": true}
}'::jsonb),
('Colaborador Operacional', 'colaborador', '{
  "controleAcesso": {"ver": false, "criar": false, "editar": false, "excluir": false},
  "custos": {"ver": true, "criar": true, "editar": false, "excluir": false},
  "pessoas": {"ver": true, "criar": true, "editar": false, "excluir": false},
  "produtividade": {"ver": true, "criar": false, "editar": true, "excluir": false},
  "indicadores": {"ver": false, "criar": false, "editar": false, "excluir": false},
  "naoConformidades": {"ver": true, "criar": true, "editar": false, "excluir": false},
  "documentos": {"ver": true, "criar": false, "editar": false, "excluir": false},
  "relatorios": {"ver": false, "criar": false, "editar": false, "excluir": false},
  "patrimonio": {"ver": true, "criar": false, "editar": false, "excluir": false}
}'::jsonb);

-- ---------------------------------------------------------------------
-- Estados e Cidades (exemplo mínimo — ajuste para a realidade da empresa)
-- ---------------------------------------------------------------------
insert into public.estados (nome, sigla) values
('São Paulo', 'SP'),
('Pernambuco', 'PE');

insert into public.cidades (nome, estado_id)
select 'São Paulo', id from public.estados where sigla = 'SP'
union all
select 'Recife', id from public.estados where sigla = 'PE';

-- ---------------------------------------------------------------------
-- Funções / Cargos
-- ---------------------------------------------------------------------
insert into public.funcoes (nome) values
('Analista de Qualidade'), ('Auditor Interno'), ('Coordenador de Qualidade');

-- ---------------------------------------------------------------------
-- Categorias (usadas em Custos e Não Conformidades)
-- ---------------------------------------------------------------------
insert into public.categorias (nome) values
('Inventário'), ('Auditoria de Estoque'), ('Deslocamento');

-- ---------------------------------------------------------------------
-- Status de Férias
-- ---------------------------------------------------------------------
insert into public.status_ferias (nome) values
('Planejada'), ('Em andamento'), ('Concluída');

-- ---------------------------------------------------------------------
-- Tipos de Documento (usados em Atividades e Controle Documental)
-- ---------------------------------------------------------------------
insert into public.tipos_documento (nome) values
('POP'), ('Instrução de Trabalho'), ('Treinamento'), ('Auditoria'), ('Revisão'), ('Melhoria');

-- ---------------------------------------------------------------------
-- Status de Documento (usado como status de Atividades)
-- ---------------------------------------------------------------------
insert into public.status_documento (nome) values
('Aberta'), ('Em execução'), ('Em validação'), ('Aprovada'), ('Concluída'), ('Cancelada');

-- ---------------------------------------------------------------------
-- Tipos de Custo
-- ---------------------------------------------------------------------
insert into public.tipos_custo (nome, exige_anexo) values
('Combustível', false), ('Alimentação', false), ('Auditoria de Estoque', true), ('Inventário', true);

-- ---------------------------------------------------------------------
-- Status de Projeto
-- ---------------------------------------------------------------------
insert into public.status_projeto (nome) values
('Planejamento'), ('Em andamento'), ('Concluído'), ('Atrasado');

-- ---------------------------------------------------------------------
-- Bases
-- ---------------------------------------------------------------------
insert into public.bases (nome) values
('Base São Paulo'), ('Base Recife');

-- ---------------------------------------------------------------------
-- Tipos de Atividade
-- ---------------------------------------------------------------------
insert into public.tipos_atividade (nome) values
('Elaboração de documento'), ('Revisão de documento'), ('Auditoria interna'), ('Treinamento');

-- ---------------------------------------------------------------------
-- Grupos de Acesso (físico/áreas — diferente de Grupos de Permissão)
-- ---------------------------------------------------------------------
insert into public.grupos_acesso (nome, descricao) values
('Acesso Área Operacional', 'Colaboradores da operação'),
('Acesso Administrativo', 'Setor administrativo e gestão');

-- ---------------------------------------------------------------------
-- Categorias e Status de Patrimônio
-- ---------------------------------------------------------------------
insert into public.categorias_patrimonio (nome) values
('Informática'), ('Mobiliário'), ('Veículos'), ('Equipamento de Auditoria'), ('Ferramentas');

insert into public.status_patrimonio (nome) values
('Em uso'), ('Em manutenção'), ('Reservado'), ('Extraviado'), ('Baixado');

-- ---------------------------------------------------------------------
-- Próximos Passos: linha única (o app faz upsert nela)
-- ---------------------------------------------------------------------
insert into public.proximos_passos (texto) values ('');
