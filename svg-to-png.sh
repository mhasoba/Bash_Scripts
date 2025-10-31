#!/bin/bash

# Converts all SVG documents in a given directory to PNG
# This assumes you have installed imagemagick: apt-get install imagemagick

# === START: Configuration ===
DENSITY=500         # DPI for conversion
RESIZE=800         # Max width/height in pixels
OUTPUT_DIR="png_output"  # Directory for output files
# === END: Configuration ===

# === START: Help Function ===
show_help() {
cat << EOF
Usage: $0 [directory]

Description:
  Converts all SVG files in the specified directory (or current directory) to PNG format.
  
Arguments:
  directory   Optional directory containing SVG files (default: current directory)
  
Options:
  -h, --help  Show this help message and exit

Examples:
  $0                    # Convert SVGs in current directory
  $0 /path/to/svgs      # Convert SVGs in specified directory
EOF
}
# === END: Help Function ===

# === START: Argument Processing ===
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Set target directory
TARGET_DIR="${1:-.}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory '$TARGET_DIR' does not exist." >&2
    exit 1
fi

if [[ ! -r "$TARGET_DIR" ]]; then
    echo "Error: Directory '$TARGET_DIR' is not readable." >&2
    exit 1
fi
# === END: Argument Processing ===

# === START: Setup Output Directory ===
if [[ ! -d "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR"
    if [[ $? -ne 0 ]]; then
        echo "Error: Cannot create output directory '$OUTPUT_DIR'." >&2
        exit 1
    fi
fi
# === END: Setup Output Directory ===

# === START: Check Dependencies ===
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick 'convert' command not found. Please install imagemagick." >&2
    exit 1
fi
# === END: Check Dependencies ===

# === START: SVG Conversion ===
cd "$TARGET_DIR" || exit 1

svg_count=$(find . -maxdepth 1 -name "*.svg" -type f | wc -l)

if [[ $svg_count -eq 0 ]]; then
    echo "No SVG files found in '$TARGET_DIR'."
    exit 0
fi

echo "Found $svg_count SVG file(s) to convert..."
converted=0
failed=0

for f in *.svg; do
    # Skip if no matching files (in case glob doesn't match)
    [[ ! -f "$f" ]] && continue
    
    output_file="$OUTPUT_DIR/$(basename "$f" .svg).png"
    
    echo "Converting: $f -> $output_file"
    
    # Use timeout to prevent hanging
    if timeout 60 convert -density "$DENSITY" -resize "$RESIZE" -background white -alpha remove "$f" "$output_file" 2>/dev/null; then
        if [[ -f "$output_file" ]]; then
            echo "  ✓ Success"
            ((converted++))
        else
            echo "  ✗ Failed: Output file not created"
            ((failed++))
        fi
    else
        echo "  ✗ Failed: Conversion error or timeout"
        ((failed++))
    fi
done
# === END: SVG Conversion ===

# === START: Summary ===
echo ""
echo "Conversion complete:"
echo "  Successfully converted: $converted"
echo "  Failed: $failed"
echo "  Output directory: $OUTPUT_DIR"

if [[ $failed -gt 0 ]]; then
    exit 1
fi
# === END: Summary ===

