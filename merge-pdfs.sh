#!/bin/bash

# Script to merge multiple PDFs in a directory into one PDF using pdftk
# Usage: ./merge_pdfs.sh [directory] [output_filename]

# Function to display usage
usage() {
    echo "Usage: $0 [directory] [output_filename]"
    echo "  directory: Directory containing PDF files (default: current directory)"
    echo "  output_filename: Name of the merged PDF file (default: merged_output.pdf)"
    echo ""
    echo "Examples:"
    echo "  $0                              # Merge PDFs in current directory to merged_output.pdf"
    echo "  $0 /path/to/pdfs                # Merge PDFs in specified directory to merged_output.pdf"
    echo "  $0 /path/to/pdfs combined.pdf   # Merge PDFs in specified directory to combined.pdf"
    exit 1
}

# Check if pdftk is installed
if ! command -v pdftk &> /dev/null; then
    echo "Error: pdftk is not installed or not in PATH"
    echo "Please install pdftk first:"
    echo "  Ubuntu/Debian: sudo apt-get install pdftk"
    echo "  CentOS/RHEL: sudo yum install pdftk"
    echo "  macOS: brew install pdftk-java"
    exit 1
fi

# Set default values
DIRECTORY="."
OUTPUT_FILE="merged_output.pdf"

# Parse command line arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

if [ $# -ge 1 ]; then
    DIRECTORY="$1"
fi

if [ $# -ge 2 ]; then
    OUTPUT_FILE="$2"
fi

# Check if directory exists
if [ ! -d "$DIRECTORY" ]; then
    echo "Error: Directory '$DIRECTORY' does not exist"
    exit 1
fi

# Change to the specified directory
cd "$DIRECTORY" || exit 1

# Find all PDF files and sort them naturally (handles numbers correctly)
# Use a safer method to handle filenames with spaces
mapfile -t PDF_FILES < <(find . -maxdepth 1 -name "*.pdf" -type f -print0 | sort -zV | tr '\0' '\n')

# Check if any PDF files were found
if [ ${#PDF_FILES[@]} -eq 0 ]; then
    echo "Error: No PDF files found in directory '$DIRECTORY'"
    exit 1
fi

# Display found files
echo "Found ${#PDF_FILES[@]} PDF files in '$DIRECTORY':"
for file in "${PDF_FILES[@]}"; do
    echo "  - $(basename "$file")"
done
echo ""

# Check if output file already exists
if [ -f "$OUTPUT_FILE" ]; then
    read -p "Output file '$OUTPUT_FILE' already exists. Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 1
    fi
fi

# Merge PDFs using pdftk
echo "Merging PDFs..."
if pdftk "${PDF_FILES[@]}" cat output "$OUTPUT_FILE"; then
    echo "Success! Merged PDF saved as: $OUTPUT_FILE"
    
    # Display file size information
    TOTAL_SIZE=0
    for file in "${PDF_FILES[@]}"; do
        if [ -f "$file" ]; then
            SIZE=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
            TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        fi
    done
    
    OUTPUT_SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null || echo 0)
    
    echo ""
    echo "File size information:"
    echo "  Total input files size: $(numfmt --to=iec $TOTAL_SIZE 2>/dev/null || echo "${TOTAL_SIZE} bytes")"
    echo "  Merged file size: $(numfmt --to=iec $OUTPUT_SIZE 2>/dev/null || echo "${OUTPUT_SIZE} bytes")"
else
    echo "Error: Failed to merge PDFs"
    exit 1
fi