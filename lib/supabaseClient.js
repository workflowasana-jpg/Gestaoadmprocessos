// lib/supabaseClient.js
// Cliente único do Supabase, usado por todo o frontend.
// As chaves vêm de variáveis de ambiente — nunca hardcode aqui.

import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env?.VITE_SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = import.meta.env?.VITE_SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Configure NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_ANON_KEY (ver .env.example).');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// ---------------------------------------------------------------------
// Exemplo de uso (padrão a seguir ao converter cada módulo do app):
// ---------------------------------------------------------------------
//
// Listar (respeita RLS automaticamente — cada usuário só vê o que pode):
//   const { data, error } = await supabase.from('custos').select('*').order('data', { ascending: false });
//
// Criar:
//   const { data, error } = await supabase.from('custos').insert({ ... }).select().single();
//
// Atualizar:
//   const { error } = await supabase.from('custos').update({ ... }).eq('id', custoId);
//
// Excluir:
//   const { error } = await supabase.from('custos').delete().eq('id', custoId);
//
// Login (Supabase Auth substitui a lista de e-mails do protótipo):
//   const { data, error } = await supabase.auth.signInWithPassword({ email, password });
//
// Sessão atual:
//   const { data: { session } } = await supabase.auth.getSession();
//
// Buscar o perfil (grupo de permissão, colaborador vinculado) do usuário logado:
//   const { data: perfil } = await supabase
//     .from('usuarios')
//     .select('*, grupos_permissao(*)')
//     .eq('id', session.user.id)
//     .single();
