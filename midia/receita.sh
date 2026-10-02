#!/usr/bin/env bash
# Análise do áudio do clipe A: por segundo, nível RMS total e da faixa aguda (> 2,5 kHz)
set -euo pipefail
A_URL="https://d8j0ntlcm91z4.cloudfront.net/user_3JrpVF6RHYDXayQgblrxBgA0H2i/hf_20261002_193654_5964d312-5379-406d-a6c7-99a8af146829.mp4"
curl -fsSL --retry 3 -o /tmp/A.mp4 "$A_URL"
ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,sample_rate,channels -of csv=p=0 /tmp/A.mp4
mkdir -p midia/analise
for faixa in "total:anull" "agudo:highpass=f=2500" "medio:bandpass=f=600:width_type=o:width=1.5" "grave:lowpass=f=160"; do
  nome="${faixa%%:*}"; filtro="${faixa#*:}"
  ffmpeg -nostdin -hide_banner -i /tmp/A.mp4 -vn -af "${filtro},asetnsamples=n=48000,astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.RMS_level:file=/tmp/${nome}.txt" -f null - 2>/dev/null
  awk -F= -v n="$nome" '/RMS_level/{printf "%s s%02d %.1f dB\n", n, i++, $2}' /tmp/${nome}.txt > "midia/analise/A-audio-${nome}.txt"
done
paste midia/analise/A-audio-total.txt midia/analise/A-audio-agudo.txt midia/analise/A-audio-medio.txt midia/analise/A-audio-grave.txt > midia/analise/A-audio.txt
cat midia/analise/A-audio.txt
# espectrograma para conferir visualmente
ffmpeg -nostdin -hide_banner -loglevel error -y -i /tmp/A.mp4 -lavfi "showspectrumpic=s=1500x400:legend=1:scale=log" midia/analise/A-audio-espectro.png
