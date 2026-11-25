#!/bin/bash

# Transcribe with speaker diarization by default; plain Whisper is opt-in.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 <input_file> [model_size] [num_speakers] [WhisperX options...]
       $0 --no-diarization <input_file> [output_format] [model_size]

Default: WhisperX large-v3, full precision, automatic CUDA selection,
word alignment and speaker diarization. Writes _speakers.txt, .srt and .json.
Requires ffmpeg and HF_TOKEN with access to the diarization model.
Errors never silently fall back to plain transcription.

WhisperX options include --device, --compute-type, --num-speakers and
--transcription-only (explicitly skip diarization but retain alignment).
Use transcribe-speakers-venv.sh --help for all WhisperX options.

--no-diarization explicitly uses plain OpenAI Whisper (installed separately).
Plain output formats: txt (default), srt, vtt, json, tsv.

Examples:
  $0 recording.m4a
  $0 recording.m4a large-v3 --device cuda --num-speakers 2
  $0 --no-diarization recording.m4a vtt medium
EOF
}

if [[ $# -eq 0 ]]; then
    usage
    exit 1
elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
fi

if [[ "$1" != "--no-diarization" ]]; then
    case "${2:-}" in
        txt|srt|vtt|json|tsv)
            echo "Error: Diarization is now the default and writes TXT, SRT and JSON together." >&2
            echo "Use: $0 <input_file> [model_size] [WhisperX options...]" >&2
            echo "For the old plain-format interface, explicitly pass --no-diarization before the input." >&2
            exit 1
            ;;
    esac
    echo "Mode: WhisperX with speaker diarization (unless --transcription-only is requested)."
    exec bash "$SCRIPT_DIR/transcribe-speakers-venv.sh" "$@"
fi

shift
if [[ $# -lt 1 || $# -gt 3 ]]; then
    echo "Error: Plain transcription expects an input and optional output format and model." >&2
    usage >&2
    exit 1
fi
echo "Mode: plain OpenAI Whisper; speaker diarization explicitly disabled."

# Check if whisper is installed
if ! command -v whisper &> /dev/null; then
    echo "Error: Whisper is not installed."
    echo ""
    echo "Install it with one of these methods:"
    echo "  1. Using pipx (recommended):"
    echo "     sudo apt install pipx ffmpeg"
    echo "     pipx install openai-whisper"
    echo ""
    echo "  2. Using virtual environment:"
    echo "     python3 -m venv ~/whisper-env"
    echo "     source ~/whisper-env/bin/activate"
    echo "     pip install openai-whisper"
    echo ""
    echo "  3. Using --break-system-packages (not recommended):"
    echo "     pip3 install --break-system-packages openai-whisper"
    exit 1
fi

# Input file
INPUT_FILE="$1"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

# Output format (default: txt)
OUTPUT_FORMAT="${2:-txt}"
case "$OUTPUT_FORMAT" in
    txt|srt|vtt|json|tsv) ;;
    *) echo "Error: Unsupported output format '$OUTPUT_FORMAT'." >&2; exit 1 ;;
esac

# Model size (default: large-v3)
MODEL_SIZE="${3:-large-v3}"

# Get the directory and filename without extension
INPUT_DIR=$(dirname "$INPUT_FILE")
FILENAME=$(basename "$INPUT_FILE")
FILENAME_NO_EXT="${FILENAME%.*}"

# Output directory
OUTPUT_DIR="$INPUT_DIR"
if [ -e "$OUTPUT_DIR/$FILENAME_NO_EXT.$OUTPUT_FORMAT" ] || [ -L "$OUTPUT_DIR/$FILENAME_NO_EXT.$OUTPUT_FORMAT" ]; then
    echo "Error: Output already exists: $OUTPUT_DIR/$FILENAME_NO_EXT.$OUTPUT_FORMAT" >&2
    exit 1
fi

echo "Transcribing: $INPUT_FILE"
echo "Model: $MODEL_SIZE"
echo "Output format: $OUTPUT_FORMAT"
echo ""

# Run whisper transcription
if whisper "$INPUT_FILE" \
    --model "$MODEL_SIZE" \
    --fp16 False \
    --output_format "$OUTPUT_FORMAT" \
    --output_dir "$OUTPUT_DIR" && [ -f "$OUTPUT_DIR/$FILENAME_NO_EXT.$OUTPUT_FORMAT" ]; then

    echo ""
    echo "Transcription complete!"
    echo "Output saved to: $OUTPUT_DIR/$FILENAME_NO_EXT.$OUTPUT_FORMAT"
else
    echo ""
    echo "Error: Transcription failed."
    exit 1
fi
