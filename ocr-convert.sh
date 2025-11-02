#!/usr/bin/env bash

################################################################################
# Universal OCR Conversion Script v2.0
# 
# DESCRIPTION:
#   Modern OCR tool supporting multiple input formats (PDF, images) with
#   flexible output options (searchable PDF, plain text, or both).
#   Uses OCRmyPDF for best quality PDF text layers and Tesseract for
#   text extraction.
#
# FEATURES:
#   ✓ Batch processing of multiple files
#   ✓ Multiple output formats (searchable PDF, text, both)
#   ✓ Multi-language support (100+ languages)
#   ✓ Image preprocessing (deskew, denoise, rotation)
#   ✓ PDF/A archival format support
#   ✓ Parallel processing for speed
#   ✓ Progress monitoring
#   ✓ Quality optimization
#   ✓ Skip already-OCRed pages
#
# SUPPORTED INPUTS: PDF, PNG, JPG, JPEG, TIFF, BMP, GIF
################################################################################

set -euo pipefail

# Script configuration
SCRIPT_NAME="$(basename "$0")"
VERSION="2.0"
TMPDIR_BASE="/tmp/ocr-convert"

# Default settings
OUTPUT_FORMAT="pdf"      # pdf, text, both
LANGUAGE="eng"           # Tesseract language codes
QUALITY="2"              # OCRmyPDF optimization level (0-3)
DPI="300"               # Image DPI for conversion
SKIP_TEXT="true"        # Skip pages with existing text
PDF_A="false"           # Convert to PDF/A-2b archival format
FORCE_OCR="false"       # Re-OCR pages with text
DESKEW="true"           # Automatically deskew images
ROTATE="true"           # Auto-rotate pages
CLEAN="true"            # Clean up temporary files
VERBOSE="false"
QUIET="false"
PARALLEL="true"         # Use parallel processing
MAX_JOBS="0"            # 0 = auto-detect cores

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print functions
print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}✓ $1${NC}"
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
$(echo -e "${GREEN}Universal OCR Conversion Script v$VERSION${NC}")

DESCRIPTION:
    Modern OCR tool for converting PDFs and images to searchable PDFs and/or
    plain text. Supports batch processing with advanced image preprocessing.

SYNOPSIS:
    $SCRIPT_NAME [OPTIONS] <input_files...>

OPTIONS:
    -o, --output FORMAT     Output format: pdf, text, both (default: pdf)
    -l, --language LANG     Tesseract language code(s) (default: eng)
                           Multiple: eng+fra+deu (English+French+German)
    -q, --quality LEVEL     Optimization level 0-3 (default: 2)
                           0=none, 1=lossless, 2=lossy, 3=aggressive
    -d, --dpi DPI          DPI for image conversion (default: 300)
    --output-dir DIR       Output directory (default: same as input)
    --suffix SUFFIX        Output file suffix (default: .ocr)
    
    --skip-text            Skip pages with existing text (default: on)
    --no-skip-text         OCR all pages even with text
    --force-ocr            Force re-OCR of all pages
    --pdf-a                Convert to PDF/A-2b archival format
    
    --no-deskew            Disable automatic deskewing
    --no-rotate            Disable automatic rotation
    --no-clean             Keep temporary files
    --no-parallel          Disable parallel processing
    --jobs NUM             Max parallel jobs (default: auto)
    
    -v, --verbose          Enable verbose output
    --quiet                Suppress non-error output
    --help, -h             Show this help
    --version              Show version
    --list-languages       List available OCR languages

LANGUAGE CODES:
    Common languages:
    eng     English          fra     French           deu     German
    spa     Spanish          ita     Italian          por     Portuguese
    rus     Russian          jpn     Japanese         chi_sim Chinese (Simplified)
    chi_tra Chinese (Trad)   ara     Arabic           hin     Hindi
    
    Use + to combine: eng+fra+deu for multi-language documents

EXAMPLES:
    # Convert single PDF to searchable PDF
    $SCRIPT_NAME document.pdf

    # Convert multiple files to searchable PDFs
    $SCRIPT_NAME *.pdf

    # Extract text from scanned PDF
    $SCRIPT_NAME --output text document.pdf

    # Create both searchable PDF and text file
    $SCRIPT_NAME --output both document.pdf

    # Multi-language document (English + French)
    $SCRIPT_NAME --language eng+fra document.pdf

    # High quality with PDF/A archival format
    $SCRIPT_NAME --quality 1 --pdf-a important_document.pdf

    # Batch process with custom output directory
    $SCRIPT_NAME --output-dir ./ocr_output/ *.pdf

    # Process images to searchable PDF
    $SCRIPT_NAME page1.jpg page2.png page3.tiff

    # Force re-OCR of PDF that already has text
    $SCRIPT_NAME --force-ocr --no-skip-text document.pdf

OUTPUT FILES:
    PDF output:     input.ocr.pdf (searchable PDF with text layer)
    Text output:    input.ocr.txt (plain text extracted from OCR)
    Both:           Creates both files above

REQUIREMENTS:
    Required: tesseract-ocr (4.0+), ocrmypdf (13.0+)
    Optional: pdftoppm (for PDF to image), imagemagick (for preprocessing)
    
    Install on Debian/Ubuntu:
        sudo apt install tesseract-ocr ocrmypdf poppler-utils
    
    Install additional languages:
        sudo apt install tesseract-ocr-fra tesseract-ocr-deu
        
    List installed languages: tesseract --list-langs

NOTES:
    • OCRmyPDF preserves vector graphics and only OCRs raster content
    • PDF/A format recommended for long-term archival
    • Higher quality settings produce larger files but better text accuracy
    • Parallel processing significantly speeds up multi-page documents
    • Use --no-skip-text if OCR quality of existing text is poor

EOF
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    local missing_tools=()
    
    # Check required tools
    command -v tesseract >/dev/null 2>&1 || missing_deps+=("tesseract-ocr")
    
    # For PDF output, need ocrmypdf
    if [[ "$OUTPUT_FORMAT" == "pdf" || "$OUTPUT_FORMAT" == "both" ]]; then
        command -v ocrmypdf >/dev/null 2>&1 || missing_deps+=("ocrmypdf")
    fi
    
    # For text extraction from PDFs
    if [[ "$OUTPUT_FORMAT" == "text" || "$OUTPUT_FORMAT" == "both" ]]; then
        command -v pdftoppm >/dev/null 2>&1 || missing_tools+=("pdftoppm (install poppler-utils)")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo "Install on Debian/Ubuntu: sudo apt install ${missing_deps[*]}" >&2
        exit 1
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_warning "Optional tools not found: ${missing_tools[*]}"
    fi
    
    # Check if language is installed
    if ! tesseract --list-langs 2>/dev/null | grep -qw "${LANGUAGE%%+*}"; then
        print_warning "Language '${LANGUAGE%%+*}' may not be installed"
        echo "Install with: sudo apt install tesseract-ocr-${LANGUAGE%%+*}" >&2
    fi
}

# List available languages
list_languages() {
    echo -e "${GREEN}Available Tesseract OCR Languages:${NC}"
    echo
    
    if command -v tesseract >/dev/null 2>&1; then
        tesseract --list-langs 2>&1 | tail -n +2 | sort | column
    else
        print_error "Tesseract not installed"
        exit 1
    fi
}

# Get number of CPU cores
get_cpu_cores() {
    if [[ "$MAX_JOBS" -gt 0 ]]; then
        echo "$MAX_JOBS"
    else
        nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "2"
    fi
}

# Determine file type
get_file_type() {
    local file="$1"
    local ext="${file##*.}"
    ext="${ext,,}"  # lowercase
    
    case "$ext" in
        pdf)
            echo "pdf"
            ;;
        jpg|jpeg|png|tiff|tif|bmp|gif)
            echo "image"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Generate output path
get_output_path() {
    local input="$1"
    local format="$2"
    local basename="${input%.*}"
    
    # Apply output directory if specified
    if [[ -n "${OUTPUT_DIR:-}" ]]; then
        basename="${OUTPUT_DIR}/$(basename "$basename")"
    fi
    
    # Apply suffix
    local suffix="${OUTPUT_SUFFIX:-.ocr}"
    
    case "$format" in
        pdf)
            echo "${basename}${suffix}.pdf"
            ;;
        text)
            echo "${basename}${suffix}.txt"
            ;;
    esac
}

# Convert image to PDF
image_to_pdf() {
    local image="$1"
    local output_pdf="$2"
    
    print_info "Converting image to PDF: $(basename "$image")"
    
    # Use imagemagick if available, otherwise basic conversion
    if command -v convert >/dev/null 2>&1; then
        convert -density "$DPI" "$image" -compress jpeg -quality 85 "$output_pdf"
    else
        # Fallback: use img2pdf if available
        if command -v img2pdf >/dev/null 2>&1; then
            img2pdf --output "$output_pdf" "$image"
        else
            print_error "Cannot convert image to PDF. Install imagemagick or img2pdf"
            return 1
        fi
    fi
}

# OCR PDF to searchable PDF using OCRmyPDF
ocr_to_pdf() {
    local input="$1"
    local output="$2"
    local is_temp_input="${3:-false}"
    
    print_progress "Creating searchable PDF: $(basename "$output")"
    
    # Build OCRmyPDF flags
    local flags=()
    flags+=("--language" "$LANGUAGE")
    flags+=("--optimize" "$QUALITY")
    flags+=("--jobs" "$(get_cpu_cores)")
    
    [[ "$DESKEW" == "true" ]] && flags+=("--deskew")
    [[ "$ROTATE" == "true" ]] && flags+=("--rotate-pages")
    [[ "$SKIP_TEXT" == "true" ]] && flags+=("--skip-text")
    [[ "$FORCE_OCR" == "true" ]] && flags+=("--force-ocr")
    [[ "$PDF_A" == "true" ]] && flags+=("--output-type" "pdfa")
    [[ "$VERBOSE" == "true" ]] && flags+=("--verbose" "1")
    [[ "$QUIET" == "true" ]] && flags+=("--quiet")
    
    # Run OCRmyPDF
    print_info "Running: ocrmypdf ${flags[*]} \"$input\" \"$output\""
    
    if ocrmypdf "${flags[@]}" "$input" "$output" 2>&1 | grep -v "^$"; then
        print_success "Created searchable PDF: $(basename "$output")"
        
        # Clean up temporary input if it was an image conversion
        [[ "$is_temp_input" == "true" && "$CLEAN" == "true" ]] && rm -f "$input"
        return 0
    else
        print_error "OCR failed for: $(basename "$input")"
        return 1
    fi
}

# Extract text from PDF using Tesseract
extract_text_from_pdf() {
    local input="$1"
    local output="$2"
    
    print_progress "Extracting text: $(basename "$output")"
    
    local tmpdir="$(mktemp -d "$TMPDIR_BASE.XXXXXX")"
    
    # Convert PDF to images
    print_info "Converting PDF pages to images..."
    if ! pdftoppm -png -r "$DPI" "$input" "$tmpdir/page"; then
        print_error "Failed to convert PDF to images"
        rm -rf "$tmpdir"
        return 1
    fi
    
    # OCR each page
    > "$output"
    local page_count=0
    local total_pages=$(find "$tmpdir" -name "page-*.png" | wc -l)
    
    print_info "Processing $total_pages pages..."
    
    for img in "$tmpdir"/page-*.png; do
        [[ ! -f "$img" ]] && continue
        ((page_count++))
        
        [[ "$QUIET" == "false" ]] && echo -ne "\r  Processing page $page_count/$total_pages..."
        
        # Run Tesseract
        if tesseract "$img" stdout -l "$LANGUAGE" --dpi "$DPI" 2>/dev/null >> "$output"; then
            echo -e "\n\n--- Page $page_count ---\n" >> "$output"
        else
            print_warning "Failed to OCR page $page_count"
        fi
    done
    
    [[ "$QUIET" == "false" ]] && echo
    
    # Clean up
    [[ "$CLEAN" == "true" ]] && rm -rf "$tmpdir"
    
    print_success "Extracted text: $(basename "$output")"
}

# Extract text from image using Tesseract
extract_text_from_image() {
    local input="$1"
    local output="$2"
    
    print_progress "Extracting text from image: $(basename "$output")"
    
    if tesseract "$input" "${output%.txt}" -l "$LANGUAGE" --dpi "$DPI" 2>/dev/null; then
        print_success "Extracted text: $(basename "$output")"
    else
        print_error "Failed to extract text from: $(basename "$input")"
        return 1
    fi
}

# Validate input files before processing
validate_input_files() {
    local -n files_ref=$1
    local valid_files=()
    local missing_files=()
    local unsupported_files=()
    local empty_files=()
    local unreadable_files=()
    
    [[ "$QUIET" == "false" ]] && echo "Validating ${#files_ref[@]} input file(s)..."
    
    for file in "${files_ref[@]}"; do
        # Check if file exists
        if [[ ! -e "$file" ]]; then
            missing_files+=("$file")
            continue
        fi
        
        # Check if it's a regular file
        if [[ ! -f "$file" ]]; then
            print_warning "Not a regular file (skipping): $file"
            continue
        fi
        
        # Check if file is readable
        if [[ ! -r "$file" ]]; then
            unreadable_files+=("$file")
            continue
        fi
        
        # Check if file is empty
        if [[ ! -s "$file" ]]; then
            empty_files+=("$file")
            continue
        fi
        
        # Check file type
        local file_type="$(get_file_type "$file")"
        if [[ "$file_type" == "unknown" ]]; then
            unsupported_files+=("$file")
            continue
        fi
        
        # File is valid
        valid_files+=("$file")
    done
    
    # Report issues
    local has_issues=false
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        has_issues=true
        print_error "Missing files (${#missing_files[@]}):"
        for file in "${missing_files[@]}"; do
            echo "  ✗ $file" >&2
        done
    fi
    
    if [[ ${#unreadable_files[@]} -gt 0 ]]; then
        has_issues=true
        print_error "Unreadable files - check permissions (${#unreadable_files[@]}):"
        for file in "${unreadable_files[@]}"; do
            echo "  ✗ $file" >&2
        done
    fi
    
    if [[ ${#empty_files[@]} -gt 0 ]]; then
        has_issues=true
        print_warning "Empty files (${#empty_files[@]}):"
        for file in "${empty_files[@]}"; do
            echo "  ⚠ $file" >&2
        done
    fi
    
    if [[ ${#unsupported_files[@]} -gt 0 ]]; then
        has_issues=true
        print_warning "Unsupported file types (${#unsupported_files[@]}):"
        for file in "${unsupported_files[@]}"; do
            echo "  ⚠ $file (supported: PDF, PNG, JPG, TIFF, BMP, GIF)" >&2
        done
    fi
    
    # Check if we have any valid files
    if [[ ${#valid_files[@]} -eq 0 ]]; then
        print_error "No valid files to process!"
        
        if [[ ${#files_ref[@]} -gt 0 ]]; then
            echo >&2
            echo "Possible causes:" >&2
            echo "  • Files don't exist at specified paths" >&2
            echo "  • Incorrect file extensions or types" >&2
            echo "  • Permission denied (cannot read files)" >&2
            echo "  • All files are empty" >&2
            echo "  • Wildcard pattern matched no files (e.g., *.pdf in empty directory)" >&2
            echo >&2
            echo "Tip: Use 'ls' to verify files exist, or check file permissions with 'ls -l'" >&2
        fi
        
        return 1
    fi
    
    # Show validation summary
    if [[ "$has_issues" == "true" ]]; then
        echo >&2
    fi
    
    print_success "Validated: ${#valid_files[@]} valid file(s), $((${#files_ref[@]} - ${#valid_files[@]})) skipped/failed"
    
    # Update the array with only valid files
    files_ref=("${valid_files[@]}")
    return 0
}

# Process a single file
process_file() {
    local input="$1"
    
    # Validate input exists (redundant check, but safe)
    if [[ ! -f "$input" ]]; then
        print_error "File not found: $input"
        return 1
    fi
    
    # Determine file type
    local file_type="$(get_file_type "$input")"
    
    if [[ "$file_type" == "unknown" ]]; then
        print_error "Unsupported file type: $input"
        return 1
    fi
    
    print_info "Processing: $(basename "$input") [type: $file_type]"
    
    local success=true
    local temp_pdf=""
    
    # Handle based on output format
    case "$OUTPUT_FORMAT" in
        pdf)
            local output_pdf="$(get_output_path "$input" "pdf")"
            
            if [[ "$file_type" == "image" ]]; then
                # Convert image to temp PDF, then OCR
                temp_pdf="$(mktemp "$TMPDIR_BASE.XXXXXX.pdf")"
                if image_to_pdf "$input" "$temp_pdf"; then
                    ocr_to_pdf "$temp_pdf" "$output_pdf" "true" || success=false
                else
                    success=false
                fi
            else
                # Direct PDF OCR
                ocr_to_pdf "$input" "$output_pdf" "false" || success=false
            fi
            ;;
            
        text)
            local output_txt="$(get_output_path "$input" "text")"
            
            if [[ "$file_type" == "image" ]]; then
                extract_text_from_image "$input" "$output_txt" || success=false
            else
                extract_text_from_pdf "$input" "$output_txt" || success=false
            fi
            ;;
            
        both)
            local output_pdf="$(get_output_path "$input" "pdf")"
            local output_txt="$(get_output_path "$input" "text")"
            
            if [[ "$file_type" == "image" ]]; then
                # Convert to PDF and OCR
                temp_pdf="$(mktemp "$TMPDIR_BASE.XXXXXX.pdf")"
                if image_to_pdf "$input" "$temp_pdf"; then
                    ocr_to_pdf "$temp_pdf" "$output_pdf" "true" || success=false
                    extract_text_from_image "$input" "$output_txt" || success=false
                else
                    success=false
                fi
            else
                # Process PDF for both outputs
                ocr_to_pdf "$input" "$output_pdf" "false" || success=false
                extract_text_from_pdf "$input" "$output_txt" || success=false
            fi
            ;;
    esac
    
    if [[ "$success" == "true" ]]; then
        print_success "Completed: $(basename "$input")"
        return 0
    else
        print_error "Failed: $(basename "$input")"
        return 1
    fi
}

# Parse arguments
parse_arguments() {
    # Use global INPUT_FILES array instead of local
    INPUT_FILES=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -l|--language)
                LANGUAGE="$2"
                shift 2
                ;;
            -q|--quality)
                QUALITY="$2"
                shift 2
                ;;
            -d|--dpi)
                DPI="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                mkdir -p "$OUTPUT_DIR"
                shift 2
                ;;
            --suffix)
                OUTPUT_SUFFIX="$2"
                shift 2
                ;;
            --skip-text)
                SKIP_TEXT="true"
                shift
                ;;
            --no-skip-text)
                SKIP_TEXT="false"
                shift
                ;;
            --force-ocr)
                FORCE_OCR="true"
                SKIP_TEXT="false"
                shift
                ;;
            --pdf-a)
                PDF_A="true"
                shift
                ;;
            --no-deskew)
                DESKEW="false"
                shift
                ;;
            --no-rotate)
                ROTATE="false"
                shift
                ;;
            --no-clean)
                CLEAN="false"
                shift
                ;;
            --no-parallel)
                PARALLEL="false"
                shift
                ;;
            --jobs)
                MAX_JOBS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            --quiet)
                QUIET="true"
                shift
                ;;
            --list-languages|--help|-h|--version)
                # Already handled in main()
                shift
                ;;
            -*)
                print_error "Unknown option: $1" >&2
                echo "Run '$SCRIPT_NAME --help' for usage information" >&2
                return 1
                ;;
            *)
                INPUT_FILES+=("$1")
                shift
                ;;
        esac
    done
    
    # Validate arguments
    if [[ ${#INPUT_FILES[@]} -eq 0 ]]; then
        print_error "No input files specified" >&2
        echo "Run '$SCRIPT_NAME --help' for usage information" >&2
        return 1
    fi
    
    # Validate output format
    if [[ ! "$OUTPUT_FORMAT" =~ ^(pdf|text|both)$ ]]; then
        print_error "Invalid output format: $OUTPUT_FORMAT (must be: pdf, text, or both)"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    # Handle help/version before anything else
    for arg in "$@"; do
        case "$arg" in
            --help|-h)
                usage
                exit 0
                ;;
            --version)
                echo "Universal OCR Conversion Script v$VERSION"
                exit 0
                ;;
            --list-languages)
                list_languages
                exit 0
                ;;
        esac
    done
    
    # Parse arguments (this sets global variables including INPUT_FILES)
    if ! parse_arguments "$@"; then
        exit 1
    fi
    
    [[ "$VERBOSE" == "true" ]] && echo "Universal OCR Conversion Script v$VERSION"
    
    # Create temp directory
    mkdir -p "$TMPDIR_BASE"
    
    # Validate input files before processing
    if ! validate_input_files INPUT_FILES; then
        exit 1
    fi
    
    [[ "$QUIET" == "false" && "$VERBOSE" == "false" ]] && echo
    
    # Check dependencies
    check_dependencies
    
    print_info "Processing ${#INPUT_FILES[@]} file(s) with output format: $OUTPUT_FORMAT"
    print_info "Language: $LANGUAGE | Quality: $QUALITY | DPI: $DPI"
    
    # Process files
    local success_count=0
    local fail_count=0
    
    for file in "${INPUT_FILES[@]}"; do
        if process_file "$file"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    # Summary
    echo
    print_success "Completed: $success_count succeeded, $fail_count failed"
    
    # Cleanup temp directory
    [[ "$CLEAN" == "true" ]] && rm -rf "$TMPDIR_BASE"
    
    [[ $fail_count -eq 0 ]] && exit 0 || exit 1
}

# Run main function
main "$@"
