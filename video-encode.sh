#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [--encoder cpu|cuda] [--quality 1-51] <input> <output>"
    echo "Re-encode the first video stream as H.264 and copy any audio streams."
    echo "Lower quality values produce higher quality; the default is 23."
}

encoder=cpu
quality=23
while [[ $# -gt 0 ]]; do
    case "$1" in
        --encoder|--quality)
            if [[ $# -lt 2 ]]; then
                usage >&2
                exit 2
            fi
            if [[ "$1" == --encoder ]]; then
                encoder="$2"
            else
                quality="$2"
            fi
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
        *) break ;;
    esac
done

if [[ $# -ne 2 ]]; then
    usage >&2
    exit 2
fi
input="$1"
output="$2"
if [[ ! -f "$input" ]]; then
    echo "Input file not found: $input" >&2
    exit 1
fi
if [[ -e "$output" || -L "$output" || "$output" == '-' ]]; then
    echo "Output already exists or is invalid: $output" >&2
    exit 1
fi
if [[ ! "$quality" =~ ^([1-9]|[1-4][0-9]|5[01])$ ]]; then
    echo "Quality must be an integer from 1 to 51." >&2
    exit 2
fi
case "$encoder" in
    cpu) video_options=(-c:v libx264 -crf "$quality") ;;
    cuda) video_options=(-c:v h264_nvenc -cq "$quality" -b:v 0) ;;
    *) echo "Encoder must be cpu or cuda." >&2; exit 2 ;;
esac
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg is required." >&2
    exit 1
fi

ffmpeg -n -i "$input" -map 0:v:0 -map '0:a?' "${video_options[@]}" -c:a copy "$output"