#!/bin/bash

# Script to transcribe audio/video recordings using OpenAI Whisper
# Usage: ./transcribe-audio.sh input_file [output_format] [model_size]

# Check if input file is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_file> [output_format] [model_size]"
    echo ""
    echo "Arguments:"
    echo "  input_file     - Audio or videoIf disk space is a concern, you can use the "tiny" model (~75 MB) which is quite good for basic transcription. The script defaults to "base" which is a good compromise between size and accuracy.

 file to transcribe"
    echo "  output_format  - Output format: txt, srt, vtt, json, tsv (default: txt)"
    echo "  model_size     - Whisper model: tiny, base, small, medium, large (default: base)"
    echo ""
    echo "Examples:"
    echo "  $0 recording.mp3"
    echo "  $0 recording.mp4 srt"
    echo "  $0 recording.wav txt medium"
    exit 1
fi

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

# Model size (default: base)
MODEL_SIZE="${3:-base}"

# Get the directory and filename without extension
INPUT_DIR=$(dirname "$INPUT_FILE")
FILENAME=$(basename "$INPUT_FILE")
FILENAME_NO_EXT="${FILENAME%.*}"

# Output directory
OUTPUT_DIR="$INPUT_DIR"

echo "Transcribing: $INPUT_FILE"
echo "Model: $MODEL_SIZE"
echo "Output format: $OUTPUT_FORMAT"
echo ""

# Run whisper transcription
whisper "$INPUT_FILE" \
    --model "$MODEL_SIZE" \
    --output_format "$OUTPUT_FORMAT" \
    --output_dir "$OUTPUT_DIR"

# Check if transcription was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "Transcription complete!"
    echo "Output saved to: $OUTPUT_DIR/$FILENAME_NO_EXT.$OUTPUT_FORMAT"
else
    echo ""
    echo "Error: Transcription failed."
    exit 1
fi
