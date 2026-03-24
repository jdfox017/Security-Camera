#!/bin/bash

VIDEO_DIR="/var/lib/motioneye/Camera1"
AUDIO_DIR="/var/lib/motioneye_audio"
OUT_DIR="/var/lib/Mvideos"
TEMP_DIR="/tmp/camera_merge"

mkdir -p "$OUT_DIR" "$TEMP_DIR"
cd /home/fox17

for date_dir in "$VIDEO_DIR"/*/; do
    [ -d "$date_dir" ] || continue
    date_folder=$(basename "$date_dir")
    mkdir -p "$OUT_DIR/$date_folder"

    for video in "$date_dir"*.mp4; do
        [ -e "$video" ] || continue
        if [ $(( $(date +%s) - $(stat -c %Y "$video") )) -lt 60 ]; then continue; fi

        filename=$(basename "$video")
        timestamp=${filename%.mp4}
        output_file="$OUT_DIR/$date_folder/$filename"
        if [ -f "$output_file" ]; then continue; fi

        IFS='-' read -r h m s <<< "$timestamp"
        v_start=$(( 10#$h * 3600 + 10#$m * 60 + 10#$s ))
        duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video")
        v_duration_int=$(printf "%.0f" "$duration")
        v_end=$(( v_start + v_duration_int ))

        # 1. Find the best start audio file
        best_match=""
        best_start=-1
        for a_path in "$AUDIO_DIR/$date_folder/"*.mp3; do
            [ -e "$a_path" ] || continue
            a_file=$(basename "$a_path")
            IFS='-' read -r ah am as <<< "${a_file%.mp3}"
            a_start=$(( 10#$ah * 3600 + 10#$am * 60 + 10#$as ))

            if [ "$a_start" -le "$v_start" ] && [ "$a_start" -gt "$best_start" ]; then
                best_start=$a_start
                best_match=$a_path
            fi
        done
 if [ -n "$best_match" ]; then

            rm -f "$TEMP_DIR/list.txt"
            echo "file '$best_match'" > "$TEMP_DIR/list.txt"

            # Use the actual start time of the first file to track progress
            current_track_start=$best_start

            while [ $(( current_track_start + 58 )) -lt "$v_end" ]; do
                expected_next=$(( current_track_start + 60 ))
                found_next=""

                # Check for a file starting within +/- 2 seconds of the expected 60s mark
                for fuzzy_offset in 0 -1 1 -2 2; do
                    check_time=$(( expected_next + fuzzy_offset ))
                    nh=$(printf "%02d" $(( check_time / 3600 )))
                    nm=$(printf "%02d" $(( (check_time % 3600) / 60 )))
                    ns=$(printf "%02d" $(( check_time % 60 )))

                    target_file="$AUDIO_DIR/$date_folder/$nh-$nm-$ns.mp3"
                    if [ -f "$target_file" ]; then
                        found_next="$target_file"
                        current_track_start=$check_time
                        break
                    fi
                done

                if [ -n "$found_next" ]; then
                    echo "file '$found_next'" >> "$TEMP_DIR/list.txt"
                else
                    # No more audio files found in sequence
                    break
                fi
            done

            offset=$(( v_start - best_start + 1 ))
            echo "Merging $filename ($v_duration_int sec) using $(wc -l < "$TEMP_DIR/list.txt") audio chunks..."

            ffmpeg -y -i "$video" -f concat -safe 0 -i "$TEMP_DIR/list.txt" \
            -filter_complex "[1:a]atrim=start=$offset,asetpts=PTS-STARTPTS[aud]" \
            -map 0:v:0 -map "[aud]" -c:v copy -c:a libmp3lame \
            -t "$duration" "$output_file" -loglevel error

            echo "Successfully merged: $filename"
        fi
    done
done
rm -rf "$TEMP_DIR"
sudo chown -R user:user /var/lib/Mvideos