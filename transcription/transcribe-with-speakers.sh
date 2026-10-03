#!/bin/bash

# Script to transcribe audio/video with speaker diarization
# Usage: ./transcribe-with-speakers.sh input_file [model_size] [num_speakers]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -z "${HF_TOKEN:-}" ] && [ -f "$PROJECT_DIR/.env" ]; then
    while IFS= read -r env_line || [ -n "$env_line" ]; do
        [[ "$env_line" =~ ^[[:space:]]*(#|$) ]] && continue
        if [[ "$env_line" =~ ^[[:space:]]*HF_TOKEN[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            HF_TOKEN="${BASH_REMATCH[1]}"
            HF_TOKEN="${HF_TOKEN%$'\r'}"
            HF_TOKEN="${HF_TOKEN#"${HF_TOKEN%%[![:space:]]*}"}"
            HF_TOKEN="${HF_TOKEN%"${HF_TOKEN##*[![:space:]]}"}"
            if [ "${#HF_TOKEN}" -ge 2 ]; then
                first_char="${HF_TOKEN:0:1}"
                last_char="${HF_TOKEN: -1}"
                if { [ "$first_char" = "'" ] && [ "$last_char" = "'" ]; } || { [ "$first_char" = '"' ] && [ "$last_char" = '"' ]; }; then
                    HF_TOKEN="${HF_TOKEN:1:${#HF_TOKEN}-2}"
                fi
            fi
            export HF_TOKEN
            break
        fi
    done < "$PROJECT_DIR/.env"
fi

WHISPERX_PYTHON="${WHISPERX_PYTHON:-python3}"
if ! command -v "$WHISPERX_PYTHON" >/dev/null 2>&1; then
    echo "Error: Python interpreter not found: $WHISPERX_PYTHON" >&2
    echo "Run transcribe-speakers-venv.sh to set up the virtual environment." >&2
    exit 1
fi
exec "$WHISPERX_PYTHON" -u "$SCRIPT_DIR/transcribe-speakers.py" "$@"
