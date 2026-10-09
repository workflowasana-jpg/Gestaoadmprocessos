# Controle Administrativo

Sistema web para controle de **colaboradores**, **atestados** (licença maternidade, paternidade, eleitoral, doença e acidente), **custos** (inventário, projetos e auditorias externas) e **férias** dos colaboradores.

Arquivos:

- `index.html`: o sistema da supervisão (não precisa de build)
- `enviar.html`: página onde os colaboradores enviam o atestado (CPF + matrícula + foto)
- `config.js`: URL e chave do Supabase, preenchidos **uma única vez** e lidos pelas duas páginas
- `schema.sql`: cria as tabelas e a segurança no Supabase (pode rodar de novo sem perder dados)
- `colaboradores_carga.sql`: carga inicial do time (contém CPFs, **não vai para o GitHub**, já está no `.gitignore`)
- `.gitignore`: impede que a carga de colaboradores seja enviada ao GitHub

## 1. Supabase (banco de dados)

1. Crie uma conta em https://supabase.com e clique em **New project**.
2. Abra **SQL Editor > New query**, cole todo o conteúdo de `schema.sql` e clique em **Run**. Depois faça o mesmo com `colaboradores_carga.sql`.
3. Em **Authentication > Users > Add user**, crie o usuário (e-mail e senha) de cada pessoa que vai usar o sistema.
4. Em **Authentication > Sign In / Providers**, desative **Allow new users to sign up**. Assim ninguém consegue se cadastrar sozinho.
5. Em **Project Settings > API**, copie a **Project URL** e a chave **anon public**.
6. Abra o `config.js` e cole:

```js
SUPABASE_URL: "https://xxxxxxxx.supabase.co",
SUPABASE_ANON_KEY: "eyJhbGciOi..."
```

A chave *anon* pode ficar no código: a proteção dos dados vem das regras (RLS) do `schema.sql`, que só liberam acesso a quem fez login. **Nunca** coloque a chave `service_role` no HTML.

> Sem essa configuração o sistema funciona em **modo local**, guardando os dados só no navegador. Serve para testar, não para uso real.

## 2. GitHub

```bash
git init
git add index.html enviar.html config.js schema.sql README.md .gitignore
git commit -m "Controle administrativo"
git branch -M main
git remote add origin https://github.com/SEU-USUARIO/controle-administrativo.git
git push -u origin main
```

Deixe o repositório **privado**.

## 3. Vercel

1. Entre em https://vercel.com com a conta do GitHub.
2. **Add New > Project**, escolha o repositório e clique em **Deploy** (não precisa mudar nenhuma configuração).
3. Pronto: cada `git push` publica a nova versão automaticamente.

## Regras que o sistema já aplica

- Sugestão de prazo: maternidade 120 dias (180 Empresa Cidadã), paternidade 5 dias (20 Empresa Cidadã), eleitoral 2 dias por dia trabalhado na eleição.
- Aviso para doença e acidente acima de 15 dias (encaminhamento ao INSS) e lembrete de emissão da CAT.
- Prazo concessivo de férias (12 meses após o fim do período aquisitivo), com alerta de risco de pagamento em dobro.
- Alerta de atestados sem documento original entregue.
- Exportação para planilha (CSV que abre direto no Excel).

## LGPD

Atestados são dados de saúde (dado pessoal sensível). Restrinja os usuários do Supabase a quem realmente precisa, e prefira não registrar o CID se o setor não precisar dele.

## Envio de atestado pelos colaboradores

1. Na tela **Atestados**, clique em **Link de envio para colaboradores** para copiar o link ou mostrar o QR Code.
2. O colaborador entra com CPF e matrícula, escolhe o tipo, as datas e anexa a foto ou o PDF.
3. O envio aparece em **Aguardando conferência** (com aviso no menu e no painel).
4. Clique em **Conferir e lançar**, ajuste o que precisar (CID, por exemplo) e clique em **Lançar atestado**. Ou clique em **Recusar**.

As fotos ficam numa pasta privada do Supabase Storage (`sgi-atestados`). O colaborador só consegue enviar; só quem tem login no sistema consegue abrir.

## Aviso por e-mail de atestados

Funciona no próprio back end do sistema (Vercel), enviando pelo e-mail da empresa via SMTP. Não usa serviço externo.

Arquivos: `api/aviso-atestado.js`, `package.json` e `atualizacao_aviso_email.sql`.

1. Peça à TI uma caixa de e-mail para os avisos (ex.: `avisos@dtel.com.br`) e os dados de SMTP: servidor, porta, usuário e senha.
   - Google Workspace: `smtp.gmail.com`, porta `465`, com "senha de app".
   - Microsoft 365: `smtp.office365.com`, porta `587`, com SMTP AUTH liberado na caixa.
2. Suba `api/aviso-atestado.js` e `package.json` para o GitHub junto com o resto.
3. Na Vercel, em **Settings > Environment Variables**, cadastre: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `EMAIL_DE`, `EMAIL_PARA`, `EMAIL_CC`, `AVISO_SEGREDO` e `APP_URL`. Depois faça um **Redeploy**.
4. Abra o `atualizacao_aviso_email.sql`, troque `SEU-SITE.vercel.app` e `SEU-SEGREDO` e rode no SQL Editor do Supabase.

Para mudar os destinatários depois, edite `EMAIL_PARA` e `EMAIL_CC` na Vercel e faça um Redeploy.
