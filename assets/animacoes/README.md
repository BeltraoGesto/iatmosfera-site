# Animações dos quadros

Coloque aqui os arquivos de animação de cada nó (Lottie `.json`, vídeo `.mp4`/`.webm`,
imagem `.gif`/`.png`/`.webp` ou `.svg`). Depois, no `index.html`, dentro do bloco
`CONTEUDO`, aponte o nó para o arquivo:

```js
media: { type: 'lottie', src: 'assets/animacoes/executa.json' }
media: { type: 'video',  src: 'assets/animacoes/satelite.mp4', poster: 'assets/animacoes/satelite.jpg' }
media: { type: 'image',  src: 'assets/animacoes/auditoria.gif', alt: 'Trilha de auditoria' }
```

Sem `media`, o quadro mostra a animação padrão (órbita coral em CSS).
O player Lottie só é baixado se algum nó usar `type: 'lottie'`.
