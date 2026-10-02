# iAtmosfera — site

Site de `iatmosfera.com.br`.

- `index.html` — landing page: vídeo de fundo em loop (plataforma de lançamento à
  noite, gerado no Higgsfield), botão de som, "Avise-me quando lançar". Os textos
  estão no próprio HTML; o e-mail de contato do fallback está no script.
- `galaxia.html` — a galáxia interativa ("em breve") com os quadros de
  informação. Conteúdo editável no bloco `CONTEUDO` no início do script.
- `assets/video/` — `lancamento-16x9.mp4` (H.264 1080p, 16,9 s, com áudio) e o
  pôster `lancamento-16x9.jpg` (primeiro quadro, mostrado enquanto carrega).
- `assets/animacoes/` — animações dos quadros da galáxia (ver README da pasta).
- `avise-me.php` e `contato.php` — recebem os formulários e gravam em `dados/`.
- `midia/importar.txt` + workflow **Importar mídia** — traz arquivos gerados
  (Higgsfield etc.) para o repositório já otimizados para a web.
- Publicação automática na Hostinger: `PUBLICACAO-HOSTINGER.md`.

Identidade visual: coral `#f25f4c`, "iAtmosfera" sempre com o "i" em coral.
