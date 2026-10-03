#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 <directory> [model_size] [num_speakers] [options...]

Recursively transcribe supported audio/video files, one at a time.
Options are passed to transcribe-speakers-venv.sh.
  --dry-run  List selected files and existing outputs without transcribing.
  -h, --help Show this help.

Examples:
  $0 ~/Desktop/NOMIS_Workshop_2026/recordings --dry-run
  $0 ~/Desktop/NOMIS_Workshop_2026/recordings medium --device cuda --batch-size 8
EOF
}

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

INPUT_DIR="$1"
shift
if [[ ! -d "$INPUT_DIR" ]]; then
    echo "Error: Directory not found: $INPUT_DIR" >&2
    exit 1
fi
INPUT_DIR="$(realpath -- "$INPUT_DIR")"

DRY_RUN=0
TRANSCRIBE_ARGS=()
for argument in "$@"; do
    if [[ "$argument" == "--dry-run" ]]; then
        DRY_RUN=1
    else
        TRANSCRIBE_ARGS+=("$argument")
    fi
done

SUFFIX="speakers"
for argument in "${TRANSCRIBE_ARGS[@]}"; do
    if [[ "$argument" == "--transcription-only" ]]; then
        SUFFIX="transcript"
        break
    fi
done
output_dir_for() {
    local input_file="$1"
    printf '%s/transcripts\n' "$(dirname -- "$input_file")"
}

output_base_for() {
    local input_file="$1"
    local output_dir
    local input_name="${input_file##*/}"
    output_dir="$(output_dir_for "$input_file")"
    printf '%s/%s_%s\n' "$output_dir" "${input_name%.*}" "$SUFFIX"
}

mapfile -d '' -t AUDIO_FILES < <(find "$INPUT_DIR" -type f \
    \( -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.wav' -o -iname '*.flac' \
    -o -iname '*.ogg' -o -iname '*.opus' -o -iname '*.aac' -o -iname '*.wma' \
    -o -iname '*.aif' -o -iname '*.aiff' -o -iname '*.mp4' -o -iname '*.m4v' \
    -o -iname '*.mov' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.avi' \
    -o -iname '*.mpeg' -o -iname '*.mpg' \) -print0 | sort -z)

if [[ ${#AUDIO_FILES[@]} -eq 0 ]]; then
    echo "No supported audio/video files found in: $INPUT_DIR" >&2
    exit 1
fi

COMPLETED=0
SKIPPED=0
FAILED=0
PLANNED=0
FIRST_PENDING=""

for input_file in "${AUDIO_FILES[@]}"; do
    output_dir="$(output_dir_for "$input_file")"
    output_base="$(output_base_for "$input_file")"
    output_count=0
    for extension in txt srt json; do
        if [[ -e "$output_base.$extension" || -L "$output_base.$extension" ]]; then
            ((output_count += 1))
        fi
    done

    if [[ $DRY_RUN -eq 1 ]]; then
        if [[ $output_count -eq 3 ]]; then
            printf 'Skip (outputs already complete): %s -> %s\n' "$input_file" "$output_dir"
            ((SKIPPED += 1))
        elif [[ $output_count -gt 0 ]]; then
            printf 'Would fail (partial output set exists): %s -> %s\n' "$input_file" "$output_dir"
            ((FAILED += 1))
        else
            printf 'Would transcribe: %s -> %s\n' "$input_file" "$output_dir"
            ((PLANNED += 1))
        fi
        continue
    fi

    if [[ $output_count -eq 3 ]]; then
        printf 'Skip (outputs already complete): %s -> %s\n' "$input_file" "$output_dir"
        ((SKIPPED += 1))
        continue
    elif [[ $output_count -gt 0 ]]; then
        printf 'Error: Partial output set exists for %s; move or remove its existing outputs before retrying.\n' "$input_file" >&2
        ((FAILED += 1))
        continue
    fi

    if [[ -z "$FIRST_PENDING" ]]; then
        FIRST_PENDING="$input_file"
        FIRST_PENDING_OUTPUT_DIR="$output_dir"
    fi
done

if [[ $DRY_RUN -eq 1 ]]; then
    printf 'Batch dry run: discovered=%d planned=%d skipped=%d partial=%d\n' \
        "${#AUDIO_FILES[@]}" "$PLANNED" "$SKIPPED" "$FAILED"
    [[ $FAILED -eq 0 ]]
    exit $?
fi

if [[ -z "$FIRST_PENDING" ]]; then
    printf 'Batch complete: discovered=%d completed=0 skipped=%d failed=%d\n' \
        "${#AUDIO_FILES[@]}" "$SKIPPED" "$FAILED"
    [[ $FAILED -eq 0 ]]
    exit $?
fi

if ! "$SCRIPT_DIR/transcribe-speakers-venv.sh" "$FIRST_PENDING" \
    "${TRANSCRIBE_ARGS[@]}" --output-dir "$FIRST_PENDING_OUTPUT_DIR" --preflight-only; then
    echo "Error: Preflight failed; no recordings were processed." >&2
    exit 1
fi

for input_file in "${AUDIO_FILES[@]}"; do
    output_dir="$(output_dir_for "$input_file")"
    output_base="$(output_base_for "$input_file")"
    output_count=0
    for extension in txt srt json; do
        if [[ -e "$output_base.$extension" || -L "$output_base.$extension" ]]; then
            ((output_count += 1))
        fi
    done
    if [[ $output_count -ne 0 ]]; then
        continue
    fi

    printf '\nTranscribing: %s\nOutputs: %s\n' "$input_file" "$output_dir"
    if "$SCRIPT_DIR/transcribe-speakers-venv.sh" "$input_file" \
            "${TRANSCRIBE_ARGS[@]}" --output-dir "$output_dir"; then
        ((COMPLETED += 1))
    else
        printf 'Failed: %s\n' "$input_file" >&2
        ((FAILED += 1))
    fi
done

printf '\nBatch complete: discovered=%d completed=%d skipped=%d failed=%d\n' \
    "${#AUDIO_FILES[@]}" "$COMPLETED" "$SKIPPED" "$FAILED"
[[ $FAILED -eq 0 ]]