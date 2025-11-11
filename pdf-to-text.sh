#!/usr/bin/env bash

################################################################################
# PDF to Text Conversion Script v1.0
# 
# DESCRIPTION:
#   Convert PDF files to plain text with flexible output options.
#   Supports single files, multiple files, and batch processing with
#   various layout preservation options.
#
# AUTHOR: Auto-generated
# LICENSE: MIT
################################################################################

set -euo pipefail

# Script configuration
SCRIPT_NAME="$(basename "$0")"
VERSION="1.0"

# Default settings
OUTPUT_DIR=""
OUTPUT_SUFFIX=".txt"
LAYOUT_MODE="layout"      # layout, raw, or simple
ENCODING="UTF-8"
PAGE_RANGE=""            # e.g., "1-5" or "3-"
FIRST_PAGE=""
LAST_PAGE=""
VERBOSE="false"
QUIET="false"
OVERWRITE="false"

# Global array for input files
INPUT_FILES=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print functions
print_error() {
    echo -e "${RED}✗ $1${NC}" >&2
    return 0
}

print_success() {
    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}✓ $1${NC}"
    return 0
}

print_info() {
    [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}ℹ $1${NC}"
    return 0
}

print_warning() {
    [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}⚠ $1${NC}"
    return 0
}

print_progress() {
    [[ "$QUIET" == "false" ]] && echo -e "${BLUE}→ $1${NC}"
    return 0
}

# Usage function
usage() {
    cat << EOF
$(echo -e "${GREEN}PDF to Text Conversion Script v$VERSION${NC}")

DESCRIPTION:
    Convert PDF files to plain text with options for layout preservation,
    encoding, and page range selection.

SYNOPSIS:
    $SCRIPT_NAME [OPTIONS] <input_files...>

OPTIONS:
    -o, --output-dir DIR    Output directory (default: same as input)
    -s, --suffix SUFFIX     Output file suffix (default: .txt)
    -l, --layout MODE       Layout mode: layout, raw, simple (default: layout)
                            • layout  - Maintain original layout
                            • raw     - Raw text extraction (no layout)
                            • simple  - Simple text with minimal formatting
    -e, --encoding ENC      Output encoding (default: UTF-8)
    -p, --pages RANGE       Page range (e.g., "1-5", "3-", "-10")
    -f, --first-page NUM    First page to extract
    -L, --last-page NUM     Last page to extract
    --overwrite             Overwrite existing output files
    -v, --verbose           Enable verbose output
    -q, --quiet             Suppress non-error output
    -h, --help              Show this help message
    --version               Show version information

LAYOUT MODES:
    layout:  Preserves the original PDF layout as much as possible
             (uses -layout flag in pdftotext)
    
    raw:     Extracts raw text without layout preservation
             (uses -raw flag in pdftotext)
    
    simple:  Simple text extraction with basic formatting
             (default pdftotext behavior)

EXAMPLES:
    # Convert single PDF to text
    $SCRIPT_NAME document.pdf

    # Convert multiple PDFs
    $SCRIPT_NAME file1.pdf file2.pdf file3.pdf

    # Convert all PDFs in directory to specific output folder
    $SCRIPT_NAME --output-dir ./text_output/ *.pdf

    # Extract only pages 1-10 with layout preservation
    $SCRIPT_NAME --layout layout --pages 1-10 document.pdf

    # Extract first 5 pages in raw mode
    $SCRIPT_NAME --layout raw --first-page 1 --last-page 5 report.pdf

    # Batch convert with custom suffix
    $SCRIPT_NAME --output-dir ./extracted/ --suffix .extracted.txt *.pdf

DEPENDENCIES:
    • pdftotext (from poppler-utils package)
      Install: sudo apt install poppler-utils

NOTES:
    • Output files will have the same basename as input with .txt extension
    • Existing files are NOT overwritten unless --overwrite is specified
    • Page numbering starts from 1
    • Use --pages or --first-page/--last-page, not both

EOF
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    command -v pdftotext >/dev/null 2>&1 || missing_deps+=("poppler-utils")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo "Install on Debian/Ubuntu: sudo apt install ${missing_deps[*]}" >&2
        exit 1
    fi
    
    return 0
}

# Get output path for a file
get_output_path() {
    local input="$1"
    local basename="${input%.*}"
    
    # Apply output directory if specified
    if [[ -n "${OUTPUT_DIR:-}" ]]; then
        basename="${OUTPUT_DIR}/$(basename "$basename")"
    fi
    
    echo "${basename}${OUTPUT_SUFFIX}"
}

# Convert single PDF to text
convert_pdf_to_text() {
    local input="$1"
    local output="$2"
    
    # Check if input exists
    if [[ ! -f "$input" ]]; then
        print_error "File not found: $input"
        return 1
    fi
    
    # Check if output exists and overwrite is disabled
    if [[ -f "$output" && "$OVERWRITE" == "false" ]]; then
        print_warning "Skipping (file exists): $(basename "$output")"
        return 0
    fi
    
    print_progress "Converting: $(basename "$input") → $(basename "$output")"
    
    # Build pdftotext command
    local cmd=(pdftotext)
    
    # Add layout mode flag
    case "$LAYOUT_MODE" in
        layout)
            cmd+=("-layout")
            ;;
        raw)
            cmd+=("-raw")
            ;;
        simple)
            # No additional flags for simple mode
            ;;
    esac
    
    # Add encoding
    [[ -n "$ENCODING" ]] && cmd+=("-enc" "$ENCODING")
    
    # Add page range options
    if [[ -n "$PAGE_RANGE" ]]; then
        # Parse page range (e.g., "1-5", "3-", "-10")
        if [[ "$PAGE_RANGE" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            cmd+=("-f" "${BASH_REMATCH[1]}" "-l" "${BASH_REMATCH[2]}")
        elif [[ "$PAGE_RANGE" =~ ^([0-9]+)-$ ]]; then
            cmd+=("-f" "${BASH_REMATCH[1]}")
        elif [[ "$PAGE_RANGE" =~ ^-([0-9]+)$ ]]; then
            cmd+=("-l" "${BASH_REMATCH[1]}")
        else
            print_warning "Invalid page range format: $PAGE_RANGE (use: 1-5, 3-, or -10)"
        fi
    else
        [[ -n "$FIRST_PAGE" ]] && cmd+=("-f" "$FIRST_PAGE")
        [[ -n "$LAST_PAGE" ]] && cmd+=("-l" "$LAST_PAGE")
    fi
    
    # Add input and output
    cmd+=("$input" "$output")
    
    print_info "Running: ${cmd[*]}"
    
    # Execute conversion
    if "${cmd[@]}" 2>&1 | grep -v "^$" || true; then
        if [[ -f "$output" && -s "$output" ]]; then
            local size=$(du -h "$output" | cut -f1)
            print_success "Created: $(basename "$output") ($size)"
            return 0
        else
            print_error "Conversion failed (empty or missing output): $(basename "$input")"
            [[ -f "$output" ]] && rm -f "$output"
            return 1
        fi
    else
        print_error "Conversion failed: $(basename "$input")"
        [[ -f "$output" ]] && rm -f "$output"
        return 1
    fi
}

# Validate input files
validate_input_files() {
    local -n files_ref=$1
    local valid_files=()
    local invalid_files=()
    
    [[ "$QUIET" == "false" ]] && echo "Validating ${#files_ref[@]} input file(s)..."
    
    for file in "${files_ref[@]}"; do
        if [[ ! -e "$file" ]]; then
            invalid_files+=("$file (not found)")
        elif [[ ! -f "$file" ]]; then
            invalid_files+=("$file (not a file)")
        elif [[ ! -r "$file" ]]; then
            invalid_files+=("$file (not readable)")
        elif [[ ! -s "$file" ]]; then
            invalid_files+=("$file (empty)")
        elif [[ ! "$file" =~ \.pdf$ ]]; then
            invalid_files+=("$file (not a PDF)")
        else
            valid_files+=("$file")
        fi
    done
    
    # Show invalid files
    if [[ ${#invalid_files[@]} -gt 0 ]]; then
        print_warning "Invalid/skipped files (${#invalid_files[@]}):"
        for file in "${invalid_files[@]}"; do
            echo "  ⚠ $file" >&2
        done
    fi
    
    # Check if we have any valid files
    if [[ ${#valid_files[@]} -eq 0 ]]; then
        print_error "No valid PDF files to process!"
        return 1
    fi
    
    [[ ${#invalid_files[@]} -gt 0 ]] && echo >&2
    print_success "Validated: ${#valid_files[@]} valid PDF(s), ${#invalid_files[@]} skipped"
    
    # Update array with only valid files
    files_ref=("${valid_files[@]}")
    return 0
}

# Parse arguments
parse_arguments() {
    INPUT_FILES=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --version)
                echo "PDF to Text Conversion Script v$VERSION"
                exit 0
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                mkdir -p "$OUTPUT_DIR"
                shift 2
                ;;
            -s|--suffix)
                OUTPUT_SUFFIX="$2"
                shift 2
                ;;
            -l|--layout)
                if [[ ! "$2" =~ ^(layout|raw|simple)$ ]]; then
                    print_error "Invalid layout mode: $2 (must be: layout, raw, or simple)"
                    exit 1
                fi
                LAYOUT_MODE="$2"
                shift 2
                ;;
            -e|--encoding)
                ENCODING="$2"
                shift 2
                ;;
            -p|--pages)
                PAGE_RANGE="$2"
                shift 2
                ;;
            -f|--first-page)
                FIRST_PAGE="$2"
                shift 2
                ;;
            -L|--last-page)
                LAST_PAGE="$2"
                shift 2
                ;;
            --overwrite)
                OVERWRITE="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -q|--quiet)
                QUIET="true"
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                echo "Run '$SCRIPT_NAME --help' for usage information"
                exit 1
                ;;
            *)
                INPUT_FILES+=("$1")
                shift
                ;;
        esac
    done
    
    # Validate arguments
    if [[ ${#INPUT_FILES[@]} -eq 0 ]]; then
        print_error "No input files specified"
        echo "Run '$SCRIPT_NAME --help' for usage information"
        return 1
    fi
    
    # Check for conflicting page options
    if [[ -n "$PAGE_RANGE" && (-n "$FIRST_PAGE" || -n "$LAST_PAGE") ]]; then
        print_error "Cannot use --pages with --first-page or --last-page"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    # Parse arguments
    if ! parse_arguments "$@"; then
        exit 1
    fi
    
    [[ "$VERBOSE" == "true" ]] && echo "PDF to Text Conversion Script v$VERSION"
    
    # Check dependencies
    check_dependencies
    
    # Validate input files
    if ! validate_input_files INPUT_FILES; then
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo
    
    print_info "Layout mode: $LAYOUT_MODE | Encoding: $ENCODING"
    [[ -n "$PAGE_RANGE" ]] && print_info "Page range: $PAGE_RANGE"
    [[ -n "$FIRST_PAGE" ]] && print_info "First page: $FIRST_PAGE"
    [[ -n "$LAST_PAGE" ]] && print_info "Last page: $LAST_PAGE"
    
    # Process files
    local success_count=0
    local fail_count=0
    local skip_count=0
    local failed_files=()
    
    for file in "${INPUT_FILES[@]}"; do
        local output="$(get_output_path "$file")"
        
        # Check if skipping existing file
        if [[ -f "$output" && "$OVERWRITE" == "false" ]]; then
            skip_count=$((skip_count + 1))
            print_warning "Skipping (exists): $(basename "$output")"
            continue
        fi
        
        if convert_pdf_to_text "$file" "$output"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
            failed_files+=("$file")
        fi
    done
    
    # Summary
    echo
    if [[ $fail_count -eq 0 && $skip_count -eq 0 ]]; then
        print_success "Completed: $success_count converted"
    elif [[ $fail_count -eq 0 ]]; then
        print_success "Completed: $success_count converted, $skip_count skipped"
    else
        print_warning "Completed: $success_count succeeded, $fail_count failed, $skip_count skipped"
        echo
        echo -e "${RED}Failed files:${NC}"
        for failed_file in "${failed_files[@]}"; do
            echo "  - $(basename "$failed_file")"
        done
    fi
    
    [[ $fail_count -eq 0 ]] && exit 0 || exit 1
}

# Run main function
main "$@"
