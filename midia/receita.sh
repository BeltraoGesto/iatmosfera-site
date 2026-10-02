#!/usr/bin/env bash
# Clipe A cortado em 13 s (sem os 2 s finais em que o carro dispara) e com áudio só do foguete:
# tira a faixa de vozes/motores (220 Hz–3,8 kHz), mantém o ronco grave e o chiado agudo da ventilação,
# e preenche o meio com um ruído grave contínuo (sem vozes) para o som não ficar oco.
set -euo pipefail
A_URL="https://d8j0ntlcm91z4.cloudfront.net/user_3JrpVF6RHYDXayQgblrxBgA0H2i/hf_20261002_193654_5964d312-5379-406d-a6c7-99a8af146829.mp4"
T=13
curl -fsSL --retry 3 --retry-delay 5 -o /tmp/A.mp4 "$A_URL"
AUD="[0:a]asplit=2[lo][hi];[lo]lowpass=f=220:p=2[l];[hi]highpass=f=3800:p=2,volume=1.6[h];anoisesrc=color=brown:r=48000:a=0.7:d=${T},bandpass=f=500:width_type=o:width=3,volume=-14dB[n];[l][h][n]amix=inputs=3:normalize=0,bass=g=3:f=80,acompressor=threshold=-28dB:ratio=3:attack=10:release=300:makeup=4,alimiter=limit=0.9:level=false[aout]"
mkdir -p referencias midia/quadros midia/analise
ffmpeg -nostdin -hide_banner -loglevel error -y -i /tmp/A.mp4 -t "$T" -filter_complex "[0:v]scale=2560:-2:flags=lanczos,format=yuv420p[v];${AUD}" \
  -map "[v]" -map "[aout]" -c:v libx264 -preset slow -crf 18 -movflags +faststart -c:a aac -b:a 128k -shortest referencias/A-13s-foguete.mp4
ffmpeg -nostdin -hide_banner -loglevel error -y -i /tmp/A.mp4 -t "$T" -filter_complex "[0:v]scale=1920:-2:flags=lanczos,format=yuv420p[v];${AUD}" \
  -map "[v]" -map "[aout]" -c:v libx264 -preset slow -crf 21 -movflags +faststart -c:a aac -b:a 96k -shortest referencias/A-13s-foguete-previa.mp4
for f in referencias/A-13s-foguete.mp4 referencias/A-13s-foguete-previa.mp4; do echo "-> $f $(stat -c %s "$f") bytes, $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")s"; done
# conferência: nível por segundo da faixa de vozes (300 Hz–3 kHz) antes e depois
for par in "antes:/tmp/A.mp4" "depois:referencias/A-13s-foguete.mp4"; do
  n="${par%%:*}"; f="${par#*:}"
  ffmpeg -nostdin -hide_banner -i "$f" -t "$T" -vn -af "bandpass=f=1000:width_type=o:width=3.3,asetnsamples=n=48000,astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.RMS_level:file=/tmp/$n.txt" -f null - 2>/dev/null
  awk -F= -v n="$n" '/RMS_level/{printf "%s vozes s%02d %.1f dB\n", n, i++, $2}' /tmp/$n.txt | tr '\n' ';'; echo
done
ffmpeg -nostdin -hide_banner -loglevel error -y -i referencias/A-13s-foguete.mp4 -vf "fps=1,scale=480:-2,tile=5x3" -frames:v 1 -q:v 4 midia/quadros/A-13s-foguete.jpg
