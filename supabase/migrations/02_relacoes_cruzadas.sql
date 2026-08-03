-- =====================================================================
-- 02_relacoes_cruzadas.sql
-- Adiciona a referência que não pôde ser criada em 01_schema.sql porque
-- as duas tabelas dependem uma da outra (não conformidade → atividade
-- de ação corretiva vinculada, e atividade → não conformidade de origem).
-- =====================================================================
alter table public.nao_conformidades
  add constraint fk_nc_atividade_vinculada
  foreign key (atividade_vinculada_id) references public.atividades(id) on delete set null;
