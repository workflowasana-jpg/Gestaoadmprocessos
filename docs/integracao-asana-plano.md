# Plano de Integração: SGQ → Asana

> Documento de referência técnica para implementar quando o sistema migrar de localStorage para Supabase + Vercel. O objetivo é registrar, no Asana, todas as Atividades e Projetos lançados no SGQ, mantendo as atualizações sincronizadas.

---

## 0. Controle de versão (Git) e fluxo de homologação

Antes mesmo da integração com a Asana, esse é o processo que sustenta toda a migração (Git → homologação → Supabase → Vercel).

### 0.1 Estrutura do repositório

```
sgq/
├── index.html (ou app/ se migrar para framework)
├── api/                  ← Vercel Functions (endpoints do item 4, mais abaixo)
│   └── asana/
│       ├── criar-tarefa.js
│       ├── atualizar-tarefa.js
│       ├── comentar-tarefa.js
│       └── anexar-imagem.js
├── supabase/
│   └── migrations/       ← histórico de alterações no banco (SQL versionado)
├── .env.example           ← modelo das variáveis de ambiente (sem valores reais)
├── .gitignore              ← inclui .env, node_modules, etc.
└── README.md
```

### 0.2 Branches e fluxo de homologação

| Branch | Papel |
|---|---|
| `main` | Produção. Protegida — só recebe merge vindo de `homolog` já aprovado. Todo push aqui gera deploy automático em produção no Vercel. |
| `homolog` | Ambiente de testes/validação. Todo push aqui gera um deploy de preview no Vercel com URL própria, para o time testar antes de ir pra produção. |
| `feature/nome-da-mudanca` | Uma branch por mudança (ex: `feature/integracao-asana`, `feature/relatorio-x`). Sai de `homolog`, some depois do merge. |

**Fluxo de uma mudança:**
1. Criar `feature/xyz` a partir de `homolog`.
2. Desenvolver e commitar.
3. Abrir Pull Request para `homolog` → o Vercel gera automaticamente uma URL de preview daquele PR.
4. Time testa nessa URL de preview (isso *é* a homologação).
5. Aprovado → merge em `homolog`.
6. Quando o conjunto de mudanças em `homolog` estiver validado, abrir PR de `homolog` → `main`.
7. Merge em `main` → deploy automático em produção.

### 0.3 Segredos e variáveis de ambiente

- Nunca commitar tokens (Asana, Supabase, etc.) no repositório — nem em `.env`, nem em código.
- Configurar as variáveis direto no painel do Vercel, separadas por ambiente: **Production** (valores reais), **Preview** (pode ser uma conta/workspace de sandbox da Asana) e **Development** (local).
- Manter um `.env.example` no repo só com os *nomes* das variáveis, para qualquer pessoa que for rodar o projeto saber o que precisa configurar.

### 0.4 Commits e versionamento

- Adotar mensagens de commit padronizadas (ex: [Conventional Commits](https://www.conventionalcommits.org/pt-br/): `feat:`, `fix:`, `chore:`, `docs:`) — isso facilita gerar um changelog automático e entender o histórico numa auditoria futura.
- Marcar releases homologadas com tags (`v1.0.0`, `v1.1.0`...) sempre que `homolog` for promovida para `main`. Isso permite saber exatamente qual versão do sistema estava em produção em uma data específica — importante para rastreabilidade em auditorias ISO.
- Sugestão: exibir a versão/tag atual em algum canto discreto do sistema (ex: rodapé do menu, perto do selo), puxando de uma variável definida no build — ajuda muito na hora de reportar um bug ("em qual versão isso aconteceu?").

### 0.5 Checklist mínimo antes de abrir o repositório

- [ ] `.gitignore` cobrindo `.env`, `node_modules`, arquivos de build
- [ ] `README.md` com instruções de setup local
- [ ] Branch `main` protegida (exigir PR + aprovação, sem push direto)
- [ ] Vercel conectado ao repositório (deploy automático de preview por PR e produção por push em `main`)
- [ ] Variáveis de ambiente cadastradas no Vercel antes do primeiro deploy real

---

## 1. Por que não fazer a integração com a Asana agora

O SGQ hoje é um arquivo HTML único, executado inteiramente no navegador (sem servidor próprio). A Asana exige que o token de acesso (Personal Access Token ou OAuth) seja tratado como segredo — a própria documentação da Asana orienta a nunca incluir o token em código do lado do cliente. Além disso, a troca de token via OAuth direto do navegador esbarra em bloqueios de CORS na prática.

**Conclusão:** a integração precisa de um backend (servidor) para guardar o token com segurança e falar com a API da Asana. Faz sentido implementar isso junto com a migração para Supabase + Vercel, que já está planejada.

## 2. O que já foi preparado no sistema atual

- Atividades e Projetos agora têm um campo `asanaTaskGid` (vazio por padrão), reservado para guardar o ID da tarefa correspondente na Asana assim que for criada.
- Isso evita uma migração de dados dolorosa depois — o campo já nasce pronto na estrutura.

## 3. Arquitetura proposta

```
[Navegador - SGQ]  →  [Backend seguro: Vercel Function ou Supabase Edge Function]  →  [API da Asana]
                              ↑ guarda o token da Asana em variável de ambiente
                              ↑ guarda o mapeamento asana_task_gid ↔ id local no Postgres (Supabase)
```

O frontend nunca fala diretamente com a Asana. Ele sempre chama o próprio backend, que:
1. Autentica a chamada (usuário logado no SGQ).
2. Faz a chamada correspondente à API da Asana usando o token guardado em segredo (variável de ambiente, nunca no código).
3. Salva/atualiza o `asana_task_gid` na tabela do Supabase.

## 4. Endpoints necessários (no backend)

| Endpoint | Disparado quando | Ação na Asana |
|---|---|---|
| `POST /api/asana/criar-tarefa` | Atividade ou Projeto é criado no SGQ | `POST /tasks` — cria a tarefa, define nome, descrição, responsável (por e-mail) e prazo (`due_on`) |
| `POST /api/asana/atualizar-tarefa` | Status é alterado | `PUT /tasks/{task_gid}` — atualiza `completed` (se status = concluído) e `due_on` |
| `POST /api/asana/comentar-tarefa` | Nova observação é registrada no histórico | `POST /tasks/{task_gid}/stories` — adiciona a observação como comentário na tarefa |
| `POST /api/asana/anexar-imagem` | Observação inclui print/imagem | `POST /tasks/{task_gid}/attachments` — anexa a imagem à tarefa |

## 5. Pontos do código que vão disparar essas chamadas

Hoje esses pontos já existem no SGQ e são exatamente onde as chamadas ao backend entrariam:

- `submitAtividade()` → após salvar, chamar `criar-tarefa` e guardar o `asana_task_gid` retornado.
- `atualizarAtividade()` → chamar `atualizar-tarefa` (status) + `comentar-tarefa` (observação) + `anexar-imagem` (se houver print).
- `submitProjeto()` → mesma lógica de criação.
- `atualizarProjeto()` / `atualizarSubtarefa()` → mesma lógica de atualização (subtarefas podem virar subtarefas nativas da Asana, que também têm suporte na API).

## 6. Mapeamento de campos (SGQ → Asana)

| Campo no SGQ | Campo na Asana |
|---|---|
| Título da atividade/projeto | `name` |
| Descrição | `notes` |
| Responsável (colaborador) | `assignee` (por e-mail, requer que o e-mail do colaborador exista como usuário na Asana) |
| Prazo | `due_on` |
| Status = "Concluída"/"Concluído" | `completed: true` |
| Nova observação | Comentário (`story`) na tarefa |
| Print anexado | Anexo (`attachment`) na tarefa |
| Projeto → Subtarefas | Subtarefas nativas da Asana (`subtasks`) |

## 7. Fase 2 (opcional, depois que a Fase 1 estiver estável)

Sincronização no sentido contrário (alguém atualiza direto na Asana → reflete no SGQ), usando **webhooks da Asana**: a Asana chama uma URL do nosso backend sempre que a tarefa muda, e o backend atualiza o registro correspondente no Supabase via o `asana_task_gid` salvo. Isso é mais complexo (exige validar a assinatura do webhook e lidar com o handshake inicial da Asana) — recomendo deixar para depois que a Fase 1 (SGQ → Asana) estiver rodando bem.

## 8. Checklist para quando for implementar

- [ ] Criar um app/token na Asana (Developer Console) com escopo apenas do necessário
- [ ] Guardar o token como variável de ambiente no Vercel/Supabase (nunca no repositório)
- [ ] Criar a coluna `asana_task_gid` nas tabelas `atividades` e `projetos` no Postgres
- [ ] Implementar os 4 endpoints da seção 4
- [ ] Ligar os pontos de disparo da seção 5
- [ ] Tratar erros de forma silenciosa no frontend (se a Asana estiver fora do ar, o SGQ não pode travar — a atividade deve salvar normalmente mesmo se a sincronização falhar; registrar a falha na Trilha de Auditoria para revisão manual depois)
- [ ] Testar com um workspace de sandbox da Asana antes de apontar para o workspace real da empresa
