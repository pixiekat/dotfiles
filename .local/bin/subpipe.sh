#!/usr/bin/env bash
# subpipe.sh: subtitle pipeline for one folder of episodes.
#   1. subliminal  → fetch subtitles
#   2. ffsubsync   → fix the global offset and frame-rate drift
#   3. alass       → fix section-by-section shifts (recaps, cuts)
# Originals are kept as .en.srt.orig; the final result is always .en.srt.
#
# Usage: ./subpipe.sh "*.mp4"      (run inside the season folder)

PATTERN="${1:-*.mp4}"

# Step 1: fetch subtitles one video at a time, with a pause between requests
# so OpenSubtitles doesn't rate-limit us.
SLEEP_SECONDS="${SLEEP_SECONDS:-5}"     # override with: SLEEP_SECONDS=10 subpipe.sh

for video in $PATTERN; do
    base="${video%.*}"

    # Skip videos that already have a subtitle, so reruns don't re-download everything
    if [ -f "${base}.en.srt" ]; then
        echo "Already has subtitle, skipping: $video"
        continue
    fi

    echo "Fetching subtitle: $video"
    subliminal download -l en --subtitle-categories hi,n,fo -v "$video"

    # Give the providers a rest before the next request
    sleep "$SLEEP_SECONDS"
done

for video in $PATTERN; do
    base="${video%.*}"                 # name without the extension
    srt="${base}.en.srt"
    [ -f "$srt" ] || { echo "No subtitle: $video"; continue; }

    # Keep the untouched original once, never overwriting an earlier backup
    [ -f "${base}.en.srt.orig" ] || cp "$srt" "${base}.en.srt.orig"

    # Step 2: ffsubsync (global offset and frame rate)
    ffsubsync "$video" -i "$srt" -o "${base}.ffs.srt" || continue

    # In step 3, stop alass re-guessing the frame rate, since ffsubsync already fixed it:
    alass --disable-fps-guessing "$video" "${base}.ffs.srt" "${base}.alass.srt" || continue

    # Final result takes the standard name; clean up the in-between file
    mv -f "${base}.alass.srt" "$srt"
    rm -f "${base}.ffs.srt"
done
