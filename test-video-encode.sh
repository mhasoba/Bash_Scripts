#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
mkdir "$fixture/bin"
touch "$fixture/input file.mp4"
cat > "$fixture/bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ARGUMENT_LOG"
EOF
chmod +x "$fixture/bin/ffmpeg"
export PATH="$fixture/bin:$PATH" ARGUMENT_LOG="$fixture/arguments"

bash "$script_dir/video-encode.sh" "$fixture/input file.mp4" "$fixture/output.mp4"
grep -Fxq -- 'libx264' "$ARGUMENT_LOG"
grep -Fxq -- '-crf' "$ARGUMENT_LOG"
grep -Fxq -- '-n' "$ARGUMENT_LOG"
grep -Fxq -- "$fixture/input file.mp4" "$ARGUMENT_LOG"

bash "$script_dir/video-encode.sh" --encoder cuda --quality 28 "$fixture/input file.mp4" "$fixture/output.mp4"
grep -Fxq -- 'h264_nvenc' "$ARGUMENT_LOG"
grep -Fxq -- '-cq' "$ARGUMENT_LOG"
grep -Fxq -- '28' "$ARGUMENT_LOG"

touch "$fixture/existing.mp4"
if bash "$script_dir/video-encode.sh" "$fixture/input file.mp4" "$fixture/existing.mp4" 2>/dev/null; then
    echo 'Existing output must not be overwritten.' >&2
    exit 1
fi
ln -s "$fixture/missing-target" "$fixture/existing-link.mp4"
if bash "$script_dir/video-encode.sh" "$fixture/input file.mp4" "$fixture/existing-link.mp4" 2>/dev/null; then
    echo 'Existing output symlinks must not be overwritten.' >&2
    exit 1
fi
if bash "$script_dir/video-encode.sh" --quality 52 "$fixture/input file.mp4" "$fixture/output.mp4" 2>/dev/null; then
    echo 'Invalid quality must be rejected.' >&2
    exit 1
fi
if bash "$script_dir/video-encode.sh" --quality 0 "$fixture/input file.mp4" "$fixture/output.mp4" 2>/dev/null; then
    echo 'Automatic NVENC quality must not be accepted as a quality value.' >&2
    exit 1
fi
if bash "$script_dir/video-encode.sh" --encoder other "$fixture/input file.mp4" "$fixture/output.mp4" 2>/dev/null; then
    echo 'Invalid encoder must be rejected.' >&2
    exit 1
fi
echo 'Video encoder tests passed.'