#!/usr/bin/env bash
# Monta o vídeo de fundo em LOOP PERFEITO a partir de dois clipes gerados no Kling:
#   A = cena principal (15 s, câmera travada, áudio nativo: só sons da operação)
#   B = ponte (6 s): começa exatamente no último quadro de A e termina no primeiro quadro de A
# Sequência final: A[0,4 s → fim] ⟶ B ⟶ A[0 → 0,4 s]; o último quadro é igual ao primeiro,
# por isso o reinício é invisível e nada "some" no meio (veículos e pessoas seguem o caminho).
# Por cima, um zoom "respirado" muito leve (até 3,5 %) que volta ao ponto de partida no fim
# do loop — é o push-in cinematográfico sem quebrar o loop.
# Saídas: assets/video/lancamento-16x9.mp4 (2560 px, com áudio) e midia/previa-16x9.mp4 (1920 px, leve).
set -euo pipefail

A_URL="https://d8j0ntlcm91z4.cloudfront.net/user_3JrpVF6RHYDXayQgblrxBgA0H2i/hf_20261002_193654_5964d312-5379-406d-a6c7-99a8af146829.mp4"
B_URL="https://d8j0ntlcm91z4.cloudfront.net/user_3JrpVF6RHYDXayQgblrxBgA0H2i/hf_20261002_194905_609d14e5-0bab-4109-a8d9-c5f0b04b49e6.mp4"
SAIDA="assets/video/lancamento-16x9.mp4"
PREVIA="midia/previa-16x9.mp4"
LARG=3840; ALT=2160            # tamanho de trabalho (os clipes 4K do Kling vêm em 3828×2164)
H=0.4                          # cabeça de A reaproveitada no fechamento
X1=0.3                         # fusão A→B (os quadros já são quase iguais)
X2=0.4                         # fusão B→A (= H: o último quadro vira exatamente o primeiro)
ZOOM=0.035                     # amplitude do zoom respirado

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

# ÁUDIO — análise do clipe A (midia/analise no branch referencias): ambiente estável de 0 a 9,5 s,
# motor da caminhonete entre 6 e 8 s, e um tom agudo (sirene) de 10 a 13 s.
# Decisão: usar só o trecho limpo (0,4 → 9,5 s), repetido com fusões de 1,5 s até cobrir o loop;
# compressor para achatar a passagem do veículo; corte de -5 dB nos médios (motores/tons),
# reforço do grave (ronco do foguete) e leve realce do chiado da ventilação; nada de sirene.
A_INI=0.4; A_FIM=9.5
AUD="[0:a]atrim=${A_INI}:${A_FIM},asetpts=PTS-STARTPTS,asplit=3[s1][s2][s3];[s1][s2]acrossfade=d=1.5:c1=tri:c2=tri[s12];[s12][s3]acrossfade=d=1.5:c1=tri:c2=tri[s123];[s123]atrim=0:${L},asetpts=PTS-STARTPTS,acompressor=threshold=-30dB:ratio=4:attack=20:release=400:makeup=2,equalizer=f=800:width_type=o:width=1.6:g=-5,bass=g=4:f=110,treble=g=2:f=3000,dynaudnorm=f=500:g=21:p=0.8:m=4,volume=-3dB,afade=t=in:d=0.3,afade=t=out:st=$(awk -v l="$L" 'BEGIN{printf "%.3f", l-0.3}'):d=0.3[aout]"

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
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$SAIDA" -vf "fps=1,scale=480:-2,tile=5x5" -frames:v 1 -q:v 4 midia/quadros/lancamento-16x9.jpg
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$SAIDA" -vf "fps=5,tblend=all_mode=difference,format=gray,tmix=frames=100:weights='1',eq=brightness=0.1:contrast=6,scale=960:-2" -frames:v 1 -q:v 4 midia/quadros/lancamento-16x9-movimento.jpg || true
# pôster = primeiro quadro do loop (é o que aparece antes do vídeo carregar)
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$SAIDA" -frames:v 1 -update 1 -q:v 3 -vf scale=1920:-2 assets/video/lancamento-16x9.jpg
ffmpeg -nostdin -hide_banner -i "$SAIDA" -vf "fps=5,tblend=all_mode=difference,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=/tmp/mov.txt" -f null - 2>/dev/null || true
awk -F= '/YAVG/{s+=$2;n++} END{if(n) printf "movimento médio YAVG=%.3f (n=%d)\n", s/n, n}' /tmp/mov.txt || true
# conferência do áudio final: nível por segundo (total e agudos)
ffmpeg -nostdin -hide_banner -i "$SAIDA" -vn -af "asetnsamples=n=48000,astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.RMS_level:file=/tmp/tot.txt" -f null - 2>/dev/null || true
awk -F= '/RMS_level/{printf "áudio final s%02d %.1f dB\n", i++, $2}' /tmp/tot.txt | tr '\n' ';' ; echo
