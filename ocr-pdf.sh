#!/bin/bash
# Usage: ./ocr-pdf.sh input.pdf output.txt

if [ $# -lt 2 ]; then
  echo "Usage: $0 input.pdf output.txt"
  exit 1
fi

INPUT="$1"
OUTPUT="$2"
TMPDIR=$(mktemp -d)

# Convert PDF to images (one PNG per page)
pdftoppm -png "$INPUT" "$TMPDIR/page"

# Run OCR on each page and append to output
> "$OUTPUT"
for img in "$TMPDIR"/page-*.png; do
  tesseract "$img" stdout >> "$OUTPUT"
  echo -e "\n\n" >> "$OUTPUT"
done

# Clean up
rm -rf "$TMPDIR"

echo "OCR complete. Output written to $OUTPUT"