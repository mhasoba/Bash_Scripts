#!/bin/bash

################################################################################
# LaTeX Compilation Script v2.0
# 
# DESCRIPTION:
#   A comprehensive LaTeX compilation script that automates the complete
#   compilation process including bibliography handling, cross-references,
#   and optional PDF viewing. Designed for reliability and ease of use.
#
# FEATURES:
#   ✓ Three-pass compilation for proper reference resolution
#   ✓ Automatic bibliography detection and processing (bibtex/biber)
#   ✓ Smart cleanup of auxiliary files
#   ✓ Colored output for better user experience
#   ✓ Comprehensive error handling and validation
#   ✓ Optional PDF viewing with system default viewer
#   ✓ Support for modern LaTeX workflows (biblatex + biber)
#   ✓ Quiet mode for automated builds
#   ✓ Dependency checking
#
# QUICK USAGE:
#   ./CompiLatex.sh document.tex          # Basic compilation
#   ./CompiLatex.sh document.tex view     # Compile and view PDF
#   ./CompiLatex.sh --help               # Show detailed help
#
# AUTHOR: Samraat Pawar, Assisted by GitHub Copilot (Claude Sonnet 4.5)
# VERSION: 2.0
# LAST MODIFIED: $(date +"%B %Y")
################################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Default settings
CLEANUP=true
QUIET=false
USE_BIBER=false
VIEW_PDF=false
PDF_VIEWER="evince"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}Success: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

print_info() {
    [[ "$QUIET" == "false" ]] && echo -e "$1"
}

# Version information
show_version() {
    cat << EOF
$(print_success "LaTeX Compilation Script")
Version: 2.0
Author: Enhanced compilation script with modern features
License: Open Source

Features in this version:
• Enhanced error handling and validation
• Support for both bibtex and biber
• Colored output and progress indicators  
• Comprehensive cleanup options
• Smart bibliography detection
• Improved file path handling
• Detailed help documentation

Run '$0 --help' for detailed usage information.
EOF
}

# Enhanced usage function with comprehensive documentation
usage() {
    cat << EOF
$(print_success "LaTeX Compilation Script v2.0")

DESCRIPTION:
    A robust LaTeX compilation script that handles the complete compilation process
    including bibliography processing, cross-references, and optional PDF viewing.
    Performs three compilation passes for proper reference resolution.

SYNOPSIS:
    $0 <file.tex> [view] [OPTIONS]

REQUIRED ARGUMENTS:
    file.tex            Input LaTeX file with .tex extension

OPTIONAL ARGUMENTS:
    view               Open the generated PDF after successful compilation

OPTIONS:
    --no-cleanup       Don't remove auxiliary files after compilation
                       (keeps .aux, .log, .bbl, .blg, etc.)
    
    --quiet           Suppress informational output, show only errors
    
    --biber           Use biber instead of bibtex for bibliography processing
                      (recommended for modern LaTeX documents using biblatex)
    
    --help, -h        Show this comprehensive help message
    
    --version, -v     Show version information and feature list

COMPILATION PROCESS:
    1. First pdflatex pass  - Initial compilation, generates .aux file
    2. Bibliography pass    - Runs bibtex/biber if citations detected
    3. Second pdflatex pass - Incorporates bibliography
    4. Third pdflatex pass  - Resolves all cross-references
    5. Optional cleanup     - Removes auxiliary files (unless --no-cleanup)
    6. Optional PDF view    - Opens PDF if 'view' argument provided

DEPENDENCIES:
    Required: pdflatex, bibtex
    Optional: biber (if --biber used), evince (if view requested)

EXAMPLES:
    # Basic compilation
    $0 thesis.tex
    
    # Compile and immediately view the PDF
    $0 thesis.tex view
    
    # Use biber for bibliography, keep auxiliary files, quiet mode
    $0 thesis.tex view --biber --no-cleanup --quiet
    
    # Modern workflow with biblatex
    $0 modern_paper.tex view --biber
    
    # Debug mode (keep aux files for inspection)
    $0 problematic.tex --no-cleanup

FILES GENERATED:
    document.pdf       - Final PDF output
    document.synctex   - SyncTeX file for editor integration
    
FILES CLEANED (unless --no-cleanup):
    Temporary files: *~, *.aux, *.log, *.nav, *.out, *.snm, *.toc, *.vrb
    Bibliography: *.bbl, *.blg, *.bcf, *.run.xml
    Other: *.dvi, *.lot, *.lof, *.fdb_latexmk, *.fls, *.synctex*, *.cut

EXIT CODES:
    0    Success - PDF generated successfully
    1    Error - Compilation failed, file not found, or missing dependencies

TROUBLESHOOTING:
    • If compilation fails, check the .log file for detailed error messages
    • Use --no-cleanup to inspect auxiliary files for debugging
    • Ensure all referenced files (.bib, images, etc.) are in correct paths
    • For bibliography issues, try switching between --biber and bibtex
    • Check that all required LaTeX packages are installed

NOTES:
    • The script automatically detects if bibliography processing is needed
    • SyncTeX is enabled for better editor integration
    • Files with spaces in names are supported (proper quoting used)
    • Script uses non-interactive mode to prevent hanging on errors

AUTHOR:
    Enhanced LaTeX compilation script for streamlined document processing

EOF
}

# Function to check if required tools are available
check_dependencies() {
    local missing_tools=()
    
    command -v pdflatex >/dev/null 2>&1 || missing_tools+=("pdflatex")
    command -v bibtex >/dev/null 2>&1 || missing_tools+=("bibtex")
    
    if [[ "$USE_BIBER" == "true" ]]; then
        command -v biber >/dev/null 2>&1 || missing_tools+=("biber")
    fi
    
    if [[ "$VIEW_PDF" == "true" ]]; then
        command -v "$PDF_VIEWER" >/dev/null 2>&1 || missing_tools+=("$PDF_VIEWER")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
}

# Parse command line arguments
parse_arguments() {
    # Check for help/version first, before requiring file argument
    for arg in "$@"; do
        case "$arg" in
            --help|-h)
                usage
                exit 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
        esac
    done
    
    if [[ $# -eq 0 ]]; then
        print_error "No input file specified"
        usage
        exit 1
    fi
    
    TEX_FILE="$1"
    shift
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            view)
                VIEW_PDF=true
                ;;
            --no-cleanup)
                CLEANUP=false
                ;;
            --quiet)
                QUIET=true
                ;;
            --biber)
                USE_BIBER=true
                ;;
            --help|-h)
                # Already handled above
                ;;
            --version|-v)
                # Already handled above
                ;;
            *)
                print_warning "Unknown option: $1"
                ;;
        esac
        shift
    done
}

# Validate input file
validate_input() {
    # Check if file has .tex extension
    if [[ "$TEX_FILE" != *.tex ]]; then
        print_error "File must have .tex extension: $TEX_FILE"
        exit 1
    fi
    
    # Check if file exists
    if [[ ! -f "$TEX_FILE" ]]; then
        print_error "File not found: $TEX_FILE"
        exit 1
    fi
    
    # Check if file is readable
    if [[ ! -r "$TEX_FILE" ]]; then
        print_error "File is not readable: $TEX_FILE"
        exit 1
    fi
}

# Compile LaTeX document
compile_latex() {
    local basename="${TEX_FILE%.tex}"
    local compile_success=true
    
    print_info "Compiling LaTeX document: $TEX_FILE"
    
    # First compilation
    print_info "First pdflatex pass..."
    if ! pdflatex -halt-on-error -interaction=nonstopmode -output-directory . -synctex=1 "$TEX_FILE"; then
        print_error "First pdflatex compilation failed"
        return 1
    fi
    
    # Bibliography compilation
    if [[ -f "${basename}.aux" ]]; then
        if grep -q "\\citation" "${basename}.aux" || grep -q "\\bibdata" "${basename}.aux"; then
            if [[ "$USE_BIBER" == "true" ]]; then
                print_info "Running biber..."
                if ! biber "$basename"; then
                    print_warning "Biber failed, but continuing..."
                fi
            else
                print_info "Running bibtex..."
                if ! bibtex "$basename"; then
                    print_warning "Bibtex failed, but continuing..."
                fi
            fi
        else
            print_info "No bibliography detected, skipping bibtex/biber"
        fi
    fi
    
    # Second compilation
    print_info "Second pdflatex pass..."
    if ! pdflatex -halt-on-error -interaction=nonstopmode -output-directory . -synctex=1 "$TEX_FILE"; then
        print_error "Second pdflatex compilation failed"
        return 1
    fi
    
    # Third compilation (for references)
    print_info "Third pdflatex pass..."
    if ! pdflatex -halt-on-error -interaction=nonstopmode -output-directory . -synctex=1 "$TEX_FILE"; then
        print_error "Third pdflatex compilation failed"
        return 1
    fi
    
    return 0
}

# Open PDF viewer
open_pdf() {
    local basename="${TEX_FILE%.tex}"
    local pdf_file="${basename}.pdf"
    
    if [[ -s "$pdf_file" ]]; then
        print_success "Opening $pdf_file with $PDF_VIEWER"
        "$PDF_VIEWER" "$pdf_file" &
    else
        print_error "PDF file is empty or doesn't exist: $pdf_file"
        return 1
    fi
}

# Cleanup auxiliary files
cleanup_files() {
    if [[ "$CLEANUP" == "true" ]]; then
        print_info "Cleaning up auxiliary files..."
        # Use find to be more precise and safe
        find . -maxdepth 1 \( \
            -name "*~" -o \
            -name "*.aux" -o \
            -name "*.blg" -o \
            -name "*.bcf" -o \
            -name "*.log" -o \
            -name "*.nav" -o \
            -name "*.out" -o \
            -name "*.snm" -o \
            -name "*.toc" -o \
            -name "*.vrb" -o \
            -name "*.bbl" -o \
            -name "*.dvi" -o \
            -name "*.lot" -o \
            -name "*.lof" -o \
            -name "*.fdb_latexmk" -o \
            -name "*.fls" -o \
            -name "*.synctex*" -o \
            -name "*.cut" -o \
            -name "*.run.xml" \
        \) -delete 2>/dev/null || true
    else
        print_info "Skipping cleanup (--no-cleanup specified)"
    fi
}

# Main function
main() {
    parse_arguments "$@"
    validate_input
    check_dependencies
    
    if compile_latex; then
        print_success "LaTeX compilation completed successfully"
        
        if [[ "$VIEW_PDF" == "true" ]]; then
            open_pdf
        fi
        
        cleanup_files
        exit 0
    else
        print_error "LaTeX compilation failed"
        cleanup_files
        exit 1
    fi
}

# Run main function with all arguments
main "$@"