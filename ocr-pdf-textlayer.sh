#!/usr/bin/env bash
# Add a selectable/searchable text layer to a PDF using OCRmyPDF.
# Usage:
#   ./ocr-pdf-textlayer.sh input.pdf [output.pdf]
# Options via env vars:
#   LANGS="eng+deu"   # Tesseract language(s)
#   FORCE=1           # Overwrite output if exists
#   PDF_A=1           # Convert to PDF/A-2b
#   QUALITY=3         # ocrmypdf optimize level (0–3, default 2)
#   SKIPTEXT=1        # Skip pages that already have text (default on)

set -euo pipefail

if ! command -v ocrmypdf >/dev/null 2>&1; then
  echo "Error: ocrmypdf is not installed." >&2
  echo "Install on Debian/Ubuntu: sudo apt-get update && sudo apt-get install -y ocrmypdf" >&2
  echo "Install via pipx: pipx install ocrmypdf (requires tesseract + qpdf system packages)" >&2
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "Usage: $0 input.pdf [output.pdf]" >&2
  exit 1
fi

IN="$1"
OUT="${2:-${IN%.pdf}.ocr.pdf}"

# Defaults
LANGS="${LANGS:-eng}"
QUALITY="${QUALITY:-2}"
SKIPTEXT="${SKIPTEXT:-1}"
PDF_A="${PDF_A:-0}"
FORCE="${FORCE:-0}"

# Build flags
FLAGS=( --language "$LANGS" --optimize "$QUALITY" --rotate-pages --deskew --jobs "$(nproc)" )
[ "$SKIPTEXT" = "1" ] && FLAGS+=( --skip-text )
[ "$PDF_A" = "1" ] && FLAGS+=( --output-type pdfa --pdfa-image-compression lossless )
[ "$FORCE" = "1" ] && FLAGS+=( --force-ocr ) || true

# Run OCR; preserve vector graphics where possible, add invisible text layer.
echo "Running: ocrmypdf ${FLAGS[*]} \"$IN\" \"$OUT\""
ocrmypdf "${FLAGS[@]}" "$IN" "$OUT"

echo "Done. Searchable PDF written to: $OUT"
