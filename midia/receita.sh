#!/usr/bin/env bash
# Monta o vídeo de fundo em LOOP PERFEITO a partir de dois clipes gerados no Kling:
#   A = cena principal (15 s, câmera travada, áudio nativo: só sons da operação)
#   B = ponte (5 s): começa exatamente no último quadro de A e termina no primeiro quadro de A
# Sequência final: A[0,4 s → fim] ⟶ B ⟶ A[0 → 0,4 s]; o último quadro é igual ao primeiro,
# por isso o reinício é invisível e nada "some" no meio (veículos e pessoas seguem o caminho).
# Por cima, um zoom "respirado" muito leve (até 3,5 %) que volta ao ponto de partida no fim
# do loop — é o push-in cinematográfico sem quebrar o loop.
# Saídas: assets/video/lancamento-16x9.mp4 (2560 px, com áudio) e midia/previa-16x9.mp4 (1920 px, leve).
set -euo pipefail

A_URL="${A_URL:-}"
B_URL="${B_URL:-}"
SAIDA="assets/video/lancamento-16x9.mp4"
PREVIA="midia/previa-16x9.mp4"
LARG=3840; ALT=2160            # tamanho de trabalho (os clipes 4K do Kling vêm em 3828×2164)
H=0.4                          # cabeça de A reaproveitada no fechamento
X1=0.3                         # fusão A→B (os quadros já são quase iguais)
X2=0.4                         # fusão B→A (= H: o último quadro vira exatamente o primeiro)
ZOOM=0.035                     # amplitude do zoom respirado

[ -n "$A_URL" ] && [ -n "$B_URL" ] || { echo "Defina A_URL e B_URL no topo de midia/receita.sh"; exit 1; }

curl -fsSL --retry 3 --retry-delay 5 -o /tmp/A.mp4 "$A_URL"
curl -fsSL --retry 3 --retry-delay 5 -o /tmp/B.mp4 "$B_URL"
for f in A B; do echo "$f: $(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,nb_frames -of csv=p=0 /tmp/$f.mp4) $(ffprobe -v error -show_entries format=duration -of csv=p=0 /tmp/$f.mp4)s"; done

DA="$(ffprobe -v error -show_entries format=duration -of csv=p=0 /tmp/A.mp4)"
DB="$(ffprobe -v error -show_entries format=duration -of csv=p=0 /tmp/B.mp4)"
# comprimento final = (DA-H) + DB - X1 + H - X2
L="$(awk -v a="$DA" -v b="$DB" -v x1="$X1" -v x2="$X2" 'BEGIN{printf "%.3f", a+b-x1-x2}')"
OFF1="$(awk -v a="$DA" -v h="$H" -v x1="$X1" 'BEGIN{printf "%.3f", (a-h)-x1}')"
OFF2="$(awk -v a="$DA" -v b="$DB" -v h="$H" -v x1="$X1" -v x2="$X2" 'BEGIN{printf "%.3f", (a-h)+b-x1-x2}')"
N="$(awk -v l="$L" 'BEGIN{printf "%d", l*24+0.5}')"
echo "duração final: ${L}s (${N} quadros); fusões em ${OFF1}s e ${OFF2}s"

NORM="scale=${LARG}:${ALT}:flags=lanczos,setsar=1,fps=24,settb=AVTB,format=yuv420p"
# áudio: trilha de A (a partir de H) emendada com o começo de A, fusão de 1 s, e fades curtos nas pontas
AUD="[0:a]atrim=start=${H},asetpts=PTS-STARTPTS[a1];[0:a]atrim=0:$(awk -v l="$L" -v a="$DA" -v h="$H" 'BEGIN{printf "%.3f", l-(a-h)+1.0}'),asetpts=PTS-STARTPTS[a2];[a1][a2]acrossfade=d=1[a3];[a3]atrim=0:${L},afade=t=in:d=0.3,afade=t=out:st=$(awk -v l="$L" 'BEGIN{printf "%.3f", l-0.3}'):d=0.3[aout]"

montar() { # $1 = saída, $2 = largura, $3 = altura, $4 = crf, $5 = bitrate de áudio
  ffmpeg -nostdin -hide_banner -loglevel error -y -i /tmp/A.mp4 -i /tmp/B.mp4 -filter_complex "
    [0:v]trim=start=${H},setpts=PTS-STARTPTS,${NORM}[va];
    [1:v]${NORM}[vb];
    [0:v]trim=duration=${H},setpts=PTS-STARTPTS,${NORM}[vc];
    [va][vb]xfade=transition=fade:duration=${X1}:offset=${OFF1}[vab];
    [vab][vc]xfade=transition=fade:duration=${X2}:offset=${OFF2}[vloop];
    [vloop]zoompan=z='1+${ZOOM}*(0.5-0.5*cos(2*PI*on/${N}))':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=${2}x${3}:fps=24,format=yuv420p[vout];
    ${AUD}" \
    -map "[vout]" -map "[aout]" -c:v libx264 -preset slow -crf "$4" -movflags +faststart -c:a aac -b:a "$5" -shortest "$1"
  echo "-> $1 $(stat -c %s "$1") bytes, $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$1")s"
}
montar "$SAIDA"  2560 1440 18 128k
montar "$PREVIA" 1920 1080 21 96k

# folha de quadros (1/s) e mapa de movimento do arquivo final
mkdir -p midia/quadros
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$SAIDA" -vf "fps=1,scale=480:-2,tile=5x4" -frames:v 1 -q:v 4 midia/quadros/lancamento-16x9.jpg
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$SAIDA" -vf "fps=5,tblend=all_mode=difference,format=gray,tmix=frames=100:weights='1',eq=brightness=0.1:contrast=6,scale=960:-2" -frames:v 1 -q:v 4 midia/quadros/lancamento-16x9-movimento.jpg || true
# pôster = primeiro quadro do loop (é o que aparece antes do vídeo carregar)
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$SAIDA" -frames:v 1 -update 1 -q:v 3 -vf scale=1920:-2 assets/video/lancamento-16x9.jpg
ffmpeg -nostdin -hide_banner -i "$SAIDA" -vf "fps=5,tblend=all_mode=difference,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=/tmp/mov.txt" -f null - 2>/dev/null || true
awk -F= '/YAVG/{s+=$2;n++} END{if(n) printf "movimento médio YAVG=%.3f (n=%d)\n", s/n, n}' /tmp/mov.txt || true
