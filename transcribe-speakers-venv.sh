#!/bin/bash

# Wrapper script to run transcription with speakers in a virtual environment
# This avoids the externally-managed-environment issue

VENV_DIR="$HOME/whisperx-env"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment at $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
    
    echo "Installing WhisperX and dependencies..."
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install whisperx
    deactivate
    
    echo ""
    echo "Setup complete!"
    echo ""
fi

# Check if input file is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_file> [model_size] [num_speakers]"
    echo ""
    echo "Arguments:"
    echo "  input_file     - Audio or video file to transcribe"
    echo "  model_size     - Whisper model: tiny, base, small, medium, large (default: base)"
    echo "  num_speakers   - Expected number of speakers (optional, auto-detect if not specified)"
    echo ""
    echo "Examples:"
    echo "  $0 meeting.mp3"
    echo "  $0 interview.mp4 medium"
    echo "  $0 podcast.wav base 2"
    echo ""
    echo "Note: Requires HuggingFace token for speaker diarization."
    echo "Get one at: https://huggingface.co/settings/tokens"
    echo "Set it with: export HF_TOKEN='your_token_here'"
    exit 1
fi

# Check if HuggingFace token is set
if [ -z "$HF_TOKEN" ]; then
    echo "Warning: HF_TOKEN not set. Speaker diarization requires a HuggingFace token."
    echo "Get one at: https://huggingface.co/settings/tokens"
    echo "Then set it with: export HF_TOKEN='your_token_here'"
    echo ""
    read -p "Continue without speaker diarization? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Input file
INPUT_FILE="$1"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

# Model size (default: base)
MODEL_SIZE="${2:-base}"

# Number of speakers (optional)
NUM_SPEAKERS="${3:-}"

# Get the directory and filename without extension
INPUT_DIR=$(dirname "$(realpath "$INPUT_FILE")")
FILENAME=$(basename "$INPUT_FILE")
FILENAME_NO_EXT="${FILENAME%.*}"

echo "Transcribing with speaker diarization: $INPUT_FILE"
echo "Model: $MODEL_SIZE"
if [ -n "$NUM_SPEAKERS" ]; then
    echo "Expected speakers: $NUM_SPEAKERS"
    SPEAKER_FLAG="--min_speakers $NUM_SPEAKERS --max_speakers $NUM_SPEAKERS"
else
    echo "Auto-detecting number of speakers"
    SPEAKER_FLAG=""
fi
echo ""

# Create a Python script to run WhisperX
TEMP_SCRIPT="/tmp/whisperx_run_$$.py"

cat > "$TEMP_SCRIPT" << 'EOFPYTHON'
import sys
import whisperx
import json
import os

def format_timestamp(seconds):
    """Convert seconds to HH:MM:SS format"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"

def transcribe_with_speakers(audio_file, model_size, output_dir, filename_base, 
                            min_speakers=None, max_speakers=None, hf_token=None):
    device = "cpu"  # or "cuda" if you have GPU
    
    # Load audio
    print("Loading audio...")
    audio = whisperx.load_audio(audio_file)
    
    # Transcribe
    print(f"Transcribing with {model_size} model...")
    model = whisperx.load_model(model_size, device, compute_type="int8")
    result = model.transcribe(audio, batch_size=16)
    
    # Align whisper output
    print("Aligning timestamps...")
    model_a, metadata = whisperx.load_align_model(language_code=result["language"], device=device)
    result = whisperx.align(result["segments"], model_a, metadata, audio, device, return_char_alignments=False)
    
    # Speaker diarization
    if hf_token:
        print("Identifying speakers...")
        diarize_model = whisperx.DiarizationPipeline(use_auth_token=hf_token, device=device)
        
        diarize_kwargs = {}
        if min_speakers and max_speakers:
            diarize_kwargs = {"min_speakers": min_speakers, "max_speakers": max_speakers}
        
        diarize_segments = diarize_model(audio, **diarize_kwargs)
        result = whisperx.assign_word_speakers(diarize_segments, result)
    
    # Save outputs
    segments = result["segments"]
    
    # Save as JSON
    json_output = os.path.join(output_dir, f"{filename_base}_speakers.json")
    with open(json_output, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    print(f"JSON saved: {json_output}")
    
    # Save as readable text with speakers
    txt_output = os.path.join(output_dir, f"{filename_base}_speakers.txt")
    with open(txt_output, 'w', encoding='utf-8') as f:
        current_speaker = None
        for segment in segments:
            speaker = segment.get('speaker', 'Unknown')
            start_time = format_timestamp(segment['start'])
            text = segment['text'].strip()
            
            if speaker != current_speaker:
                f.write(f"\n[{speaker}] ({start_time})\n")
                current_speaker = speaker
            
            f.write(f"{text}\n")
    print(f"Text saved: {txt_output}")
    
    # Save as SRT with speakers
    srt_output = os.path.join(output_dir, f"{filename_base}_speakers.srt")
    with open(srt_output, 'w', encoding='utf-8') as f:
        for i, segment in enumerate(segments, 1):
            speaker = segment.get('speaker', 'Unknown')
            start = segment['start']
            end = segment['end']
            text = segment['text'].strip()
            
            # SRT timestamp format
            start_srt = f"{int(start//3600):02d}:{int((start%3600)//60):02d}:{int(start%60):02d},{int((start%1)*1000):03d}"
            end_srt = f"{int(end//3600):02d}:{int((end%3600)//60):02d}:{int(end%60):02d},{int((end%1)*1000):03d}"
            
            f.write(f"{i}\n")
            f.write(f"{start_srt} --> {end_srt}\n")
            f.write(f"[{speaker}] {text}\n\n")
    print(f"SRT saved: {srt_output}")
    
    print("\nTranscription complete!")

if __name__ == "__main__":
    audio_file = sys.argv[1]
    model_size = sys.argv[2]
    output_dir = sys.argv[3]
    filename_base = sys.argv[4]
    min_speakers = int(sys.argv[5]) if sys.argv[5] else None
    max_speakers = int(sys.argv[6]) if sys.argv[6] else None
    hf_token = sys.argv[7] if sys.argv[7] else None
    
    transcribe_with_speakers(audio_file, model_size, output_dir, filename_base,
                           min_speakers, max_speakers, hf_token)
EOFPYTHON

# Activate virtual environment and run the Python script
source "$VENV_DIR/bin/activate"

python "$TEMP_SCRIPT" \
    "$INPUT_FILE" \
    "$MODEL_SIZE" \
    "$INPUT_DIR" \
    "$FILENAME_NO_EXT" \
    "${NUM_SPEAKERS:-}" \
    "${NUM_SPEAKERS:-}" \
    "${HF_TOKEN:-}"

EXIT_CODE=$?

deactivate

# Clean up temp script
rm -f "$TEMP_SCRIPT"

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "Output files:"
    echo "  - ${INPUT_DIR}/${FILENAME_NO_EXT}_speakers.txt (readable transcript)"
    echo "  - ${INPUT_DIR}/${FILENAME_NO_EXT}_speakers.srt (subtitles with speakers)"
    echo "  - ${INPUT_DIR}/${FILENAME_NO_EXT}_speakers.json (detailed data)"
else
    echo ""
    echo "Error: Transcription failed."
    exit 1
fi
