# Publicar na Hostinger — sem copiar e colar arquivos

Este repositório é o site `iatmosfera.com.br`. Os arquivos ficam na raiz, no
branch `main`. A Hostinger puxa o `main` sozinha a cada push: você configura
uma vez (5 minutos) e nunca mais abre o gerenciador de arquivos.

> Por que não direto da sessão do Claude? O contêiner em que o Claude roda só
> tem saída HTTPS. FTP (21) e SSH (65002) não respondem de lá. Então o Claude
> faz commit e push aqui, e a Hostinger busca o código no GitHub.

```
você / Claude --push--> GitHub (main) --Hostinger puxa--> public_html --> https://iatmosfera.com.br
```

## Caminho A (recomendado): Git da Hostinger, sem senha em lugar nenhum

1. **hPanel** → **Sites** → **iatmosfera.com.br** → **Arquivos** →
   **Gerenciador de Arquivos**: entre em `public_html` e apague o que houver
   (a Hostinger exige a pasta vazia na primeira vez).
2. **Sites** → **iatmosfera.com.br** → **Avançado** → **Git** →
   **Connect with GitHub**. Autorize o app da Hostinger e dê acesso ao
   repositório **BeltraoGesto/iatmosfera-site** (é privado).
3. Preencha: repositório `BeltraoGesto/iatmosfera-site`, branch **`main`**,
   diretório **em branco** (= `public_html`). Para um subdomínio, informe a
   pasta dele, ex.: `public_html/embreve`.
4. Confirme. O site entra no ar; a partir daí cada push atualiza sozinho.

> Tela de Git no modelo antigo (campo de URL e botão **Gerar chave SSH**)?
> Gere a chave, copie e cadastre no GitHub em **Settings → Deploy keys → Add
> deploy key** (sem "write"). Na Hostinger use
> `git@github.com:BeltraoGesto/iatmosfera-site.git`, branch `main`, diretório
> em branco. Em **Auto Deployment**, copie a **Webhook URL** e cadastre no
> GitHub em **Settings → Webhooks → Add webhook** (Content type
> `application/json`, "Just the push event").

### Conferir

- Abra `https://iatmosfera.com.br` em aba anônima.
- O SSL já está ativo no painel. Se aparecer "não seguro": **Segurança → SSL**
  → ligar **Forçar HTTPS** (ou descomente as 3 linhas do item 1 em `.htaccess`).
- Teste o formulário **"Avise-me quando lançar"**: grava em `dados/avise-me.csv`
  (pasta bloqueada para o navegador) e envia um aviso para o e-mail definido em
  `avise-me.php` (`DESTINO`). Se o PHP falhar, a página abre o e-mail do
  visitante como alternativa.
- A pasta `dados/` com o CSV não é apagada nas atualizações (o Git da Hostinger
  não remove arquivos que não estão no repositório).

## Caminho B: FTP pelo GitHub Actions (qualquer plano)

1. hPanel → **Sites → iatmosfera.com.br → Arquivos → Contas FTP**: anote
   **FTP IP (host)** e **Nome de usuário**; se preciso, **Alterar senha**.
2. GitHub → repositório → **Settings → Secrets and variables → Actions**:
   secrets `FTP_SERVER`, `FTP_USERNAME`, `FTP_PASSWORD`; variável
   `PUBLICACAO` = `ftp` (e `FTP_SERVER_DIR` = `./` se o usuário FTP já nasce
   dentro de `public_html`).
3. Push (ou **Actions → Run workflow**).

## Caminho C: SSH/rsync (Premium, Business ou Cloud)

1. hPanel → **Sites → iatmosfera.com.br → Avançado → Acesso SSH** → **Ativar**;
   anote IP, porta (65002) e usuário.
2. No seu computador: `ssh-keygen -t ed25519 -f hostinger_deploy -N ""`.
   Cadastre o conteúdo de `hostinger_deploy.pub` em **Gerenciar chaves SSH**.
3. GitHub → secrets `SSH_HOST`, `SSH_USER`, `SSH_KEY` (conteúdo da chave
   privada); variável `PUBLICACAO` = `sftp`.

## O que tem no repositório

| Arquivo | Para quê |
|---|---|
| `index.html` | landing page (vídeo de fundo, "Avise-me", botão Contato); textos e caminhos no próprio arquivo e no bloco `CONFIG` do script |
| `galaxia.html` | a galáxia interativa ("em breve"); conteúdo editável no bloco `CONTEUDO` no início do script |
| `assets/video/` | vídeo de fundo em loop (`lancamento-16x9.mp4`, `lancamento-9x16.mp4`) e os pôsteres `.jpg` |
| `.htaccess` | compressão, cache, bloqueio de arquivos internos e da pasta `.git`, HTTPS (comentado) |
| `avise-me.php` | recebe o formulário "Avise-me" (opcional) |
| `contato.php` | recebe o formulário "Contato" da landing (opcional) |
| `dados/` | onde o PHP grava os e-mails e mensagens; protegido por `.htaccess` |
| `assets/animacoes/` | animações de cada quadro (veja o README da pasta) |
| `.github/workflows/publicar.yml` | só para os caminhos B e C |
| `.github/workflows/importar-midia.yml` | traz vídeos/imagens geradas (ex.: Higgsfield) para dentro do repositório: liste em `midia/importar.txt` e faça push |

## Problemas comuns

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| Hostinger recusa: "directory is not empty" | `public_html` tem arquivos | esvaziar a pasta e tentar de novo |
| Site não atualiza depois do push | Hostinger não recebeu o aviso | hPanel → Avançado → Git → **Deploy** manual; conferir o webhook no GitHub |
| `530 Login incorrect` (FTP) | usuário ou host errados | copiar de novo de **Contas FTP** |
| Formulário abre o e-mail em vez de enviar | `avise-me.php`/`contato.php` não subiu ou PHP com erro | conferir o arquivo em `public_html`; versão do PHP (**Avançado → Configuração PHP**) ≥ 7.4 |
