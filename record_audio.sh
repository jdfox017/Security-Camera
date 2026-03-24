#!/bin/bash

BASE_DIR="/var/lib/motioneye_audio"

# Create today's folder before starting
mkdir -p "$BASE_DIR/$(date +%m-%d-%Y)"

# Internal segmenting (keeps files starting at :00)
ffmpeg -y -f alsa -channels 1 -i hw:3,0 -acodec libmp3lame -ab 128k \
-f segment -segment_time 60 -segment_atclocktime 1 -reset_timestamps 1 \
-strftime 1 "$BASE_DIR/%m-%d-%Y/%H-%M-%S.mp3"