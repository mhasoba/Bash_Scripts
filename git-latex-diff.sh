#!/bin/bash

################################################################################
# Git LaTeX Diff Script v2.0
# 
# DESCRIPTION:
#   Advanced LaTeX diff visualization tool with Git integration. Generates
#   visual comparisons between LaTeX document versions showing additions,
#   deletions, and modifications in a compiled PDF format.
#
# FEATURES:
#   ✓ Git integration for comparing commits/branches
#   ✓ File-to-file comparison mode
#   ✓ Multiple output formats (PDF, HTML, TeX)
#   ✓ Configurable PDF viewer
#   ✓ Comprehensive error handling
#   ✓ Cleanup options
#   ✓ Verbose and quiet modes
#   ✓ Custom latexdiff options
#
# DEPENDENCIES: latexdiff, pdflatex, git (optional)
################################################################################

set -euo pipefail

# Configuration
SCRIPT_NAME="$(basename "$0")"
VERSION="2.0"
DEFAULT_VIEWER="evince"
DEFAULT_OUTPUT_DIR=""
CLEANUP=true
VERBOSE=false
QUIET=false
OUTPUT_FORMAT="pdf"
VIEWER=""
LATEXDIFF_OPTIONS=""

# Colors for output
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
    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}Success: $1${NC}"
}

print_info() {
    [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}Info: $1${NC}"
}

print_warning() {
    [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}Warning: $1${NC}"
}

# Usage function
usage() {
    cat << EOF
$(echo -e "${GREEN}Git LaTeX Diff v$VERSION${NC}")

DESCRIPTION:
    Generate visual diffs of LaTeX documents with Git integration or direct file comparison.
    Creates a PDF showing additions (blue), deletions (red), and changes (blue).

USAGE:
    # Git mode - Compare commits/branches
    $SCRIPT_NAME --git <commit1> <commit2> <file.tex>
    $SCRIPT_NAME --git HEAD~1 HEAD document.tex
    $SCRIPT_NAME --git main feature-branch paper.tex

    # File mode - Direct comparison
    $SCRIPT_NAME <old_file.tex> <new_file.tex>
    $SCRIPT_NAME version1.tex version2.tex

    # Git working tree comparison
    $SCRIPT_NAME --git HEAD <file.tex>  # Compare HEAD with working tree

OPTIONS:
    --git                 Enable Git mode for commit/branch comparison
    --output-dir DIR      Specify output directory (default: temp directory)
    --format FORMAT       Output format: pdf, html, tex (default: pdf)
    --viewer VIEWER       PDF viewer to use (default: evince)
    --no-cleanup          Don't remove temporary files
    --no-view             Don't open viewer automatically
    --verbose, -v         Enable verbose output
    --quiet, -q           Suppress non-error output
    --latexdiff-opts OPTS Additional options for latexdiff
    --help, -h            Show this help
    --version             Show version information

LATEXDIFF OPTIONS:
    Common latexdiff options you can pass via --latexdiff-opts:
    --flatten             Flatten input before processing
    --encoding=utf8       Set input encoding
    --packages=PACKAGES   Add LaTeX packages to diff preamble
    --config CONFIG       Use specific latexdiff configuration

EXAMPLES:
    # Compare current working version with last commit
    $SCRIPT_NAME --git HEAD thesis.tex

    # Compare two specific commits
    $SCRIPT_NAME --git abc1234 def5678 paper.tex

    # Compare branches
    $SCRIPT_NAME --git main develop thesis.tex

    # Direct file comparison with custom options
    $SCRIPT_NAME old.tex new.tex --format html --no-view

    # Verbose mode with custom latexdiff options
    $SCRIPT_NAME --git HEAD~2 HEAD paper.tex -v --latexdiff-opts "--flatten --encoding=utf8"

    # Output to specific directory without cleanup
    $SCRIPT_NAME old.tex new.tex --output-dir ./diffs --no-cleanup

EXIT CODES:
    0    Success
    1    Error (missing files, compilation failure, etc.)
    2    Missing dependencies

NOTES:
    • Git mode requires the file to be tracked in the repository
    • PDF compilation requires a working LaTeX installation
    • Temporary files are created in /tmp unless --output-dir specified
    • Use --no-cleanup for debugging compilation issues

EOF
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    command -v latexdiff >/dev/null 2>&1 || missing_deps+=("latexdiff")
    command -v pdflatex >/dev/null 2>&1 || missing_deps+=("pdflatex")
    
    if [[ "$GIT_MODE" == "true" ]]; then
        command -v git >/dev/null 2>&1 || missing_deps+=("git")
    fi
    
    if [[ "$OUTPUT_FORMAT" == "pdf" && "$NO_VIEW" == "false" ]]; then
        command -v "$VIEWER" >/dev/null 2>&1 || missing_deps+=("$VIEWER")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install missing tools and try again."
        exit 2
    fi
}

# Parse arguments
parse_arguments() {
    GIT_MODE=false
    NO_VIEW=false
    NO_CLEANUP=false
    
    if [[ $# -eq 0 ]]; then
        print_error "No arguments provided"
        usage
        exit 1
    fi
    
    # Check for help/version first
    for arg in "$@"; do
        case "$arg" in
            --help|-h)
                usage
                exit 0
                ;;
            --version)
                echo "Git LaTeX Diff v$VERSION"
                exit 0
                ;;
        esac
    done
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --git)
                GIT_MODE=true
                ;;
            --output-dir)
                DEFAULT_OUTPUT_DIR="$2"
                shift
                ;;
            --format)
                OUTPUT_FORMAT="$2"
                shift
                ;;
            --viewer)
                VIEWER="$2"
                shift
                ;;
            --no-cleanup)
                NO_CLEANUP=true
                ;;
            --no-view)
                NO_VIEW=true
                ;;
            --verbose|-v)
                VERBOSE=true
                ;;
            --quiet|-q)
                QUIET=true
                ;;
            --latexdiff-opts)
                LATEXDIFF_OPTIONS="$2"
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                exit 1
                ;;
            *)
                # Collect positional arguments
                ARGS+=("$1")
                ;;
        esac
        shift
    done
    
    # Set defaults
    [[ -z "$VIEWER" ]] && VIEWER="$DEFAULT_VIEWER"
    
    # Validate arguments
    if [[ "$GIT_MODE" == "true" ]]; then
        if [[ ${#ARGS[@]} -lt 2 ]]; then
            print_error "Git mode requires at least 2 arguments: commit/branch and file"
            usage
            exit 1
        fi
    else
        if [[ ${#ARGS[@]} -lt 2 ]]; then
            print_error "File mode requires 2 arguments: old_file new_file"
            usage
            exit 1
        fi
    fi
}

# Git mode: extract files from commits
git_extract_file() {
    local commit="$1"
    local file="$2"
    local output="$3"
    
    print_info "Extracting $file from commit $commit"
    
    if [[ "$commit" == "WORKING" ]]; then
        # Use working tree version
        if [[ ! -f "$file" ]]; then
            print_error "File not found in working tree: $file"
            return 1
        fi
        cp "$file" "$output"
    else
        # Extract from git
        if ! git show "$commit:$file" > "$output" 2>/dev/null; then
            print_error "Failed to extract $file from commit $commit"
            return 1
        fi
    fi
}

# Generate diff
generate_diff() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"
    
    print_info "Generating LaTeX diff between $old_file and $new_file"
    
    local cmd="latexdiff $LATEXDIFF_OPTIONS \"$old_file\" \"$new_file\""
    print_info "Running: $cmd"
    
    if ! eval "$cmd" > "$output_file"; then
        print_error "latexdiff failed"
        return 1
    fi
    
    print_success "Diff generated: $output_file"
}

# Compile diff to PDF
compile_diff() {
    local tex_file="$1"
    local output_dir="$2"
    
    print_info "Compiling diff to PDF: $tex_file"
    
    local basename="$(basename "$tex_file" .tex)"
    
    # Run pdflatex
    if ! pdflatex -interaction=nonstopmode -output-directory "$output_dir" "$tex_file" >/dev/null 2>&1; then
        print_error "PDF compilation failed. Check $output_dir/$basename.log"
        return 1
    fi
    
    # Run again for references
    pdflatex -interaction=nonstopmode -output-directory "$output_dir" "$tex_file" >/dev/null 2>&1
    
    local pdf_file="$output_dir/$basename.pdf"
    if [[ ! -f "$pdf_file" ]]; then
        print_error "PDF not generated: $pdf_file"
        return 1
    fi
    
    print_success "PDF compiled: $pdf_file"
    echo "$pdf_file"
}

# Convert to HTML
convert_to_html() {
    local tex_file="$1"
    local output_dir="$2"
    
    local basename="$(basename "$tex_file" .tex)"
    local html_file="$output_dir/$basename.html"
    
    # Basic TeX to HTML conversion (simplified)
    print_info "Converting to HTML: $html_file"
    
    # This is a basic conversion - for better results, consider htlatex
    if command -v htlatex >/dev/null 2>&1; then
        htlatex "$tex_file" "" "" -d"$output_dir/" >/dev/null 2>&1
    else
        print_warning "htlatex not found. Creating basic HTML wrapper."
        cat > "$html_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>LaTeX Diff</title>
    <style>
        body { font-family: 'Computer Modern', serif; margin: 40px; }
        pre { background: #f5f5f5; padding: 20px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>LaTeX Diff Output</h1>
    <pre>$(cat "$tex_file" | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g')</pre>
</body>
</html>
EOF
    fi
    
    print_success "HTML generated: $html_file"
    echo "$html_file"
}

# Open file with appropriate viewer
open_result() {
    local file="$1"
    local format="$2"
    
    if [[ "$NO_VIEW" == "true" ]]; then
        print_info "Skipping viewer (--no-view specified)"
        return 0
    fi
    
    print_info "Opening $file with appropriate viewer"
    
    case "$format" in
        pdf)
            "$VIEWER" "$file" &
            ;;
        html)
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$file" &
            elif command -v firefox >/dev/null 2>&1; then
                firefox "$file" &
            else
                print_warning "No HTML viewer found. File saved as: $file"
            fi
            ;;
        tex)
            if command -v code >/dev/null 2>&1; then
                code "$file" &
            elif command -v gedit >/dev/null 2>&1; then
                gedit "$file" &
            else
                print_info "TeX file saved as: $file"
            fi
            ;;
    esac
}

# Cleanup function
cleanup_files() {
    if [[ "$CLEANUP" == "true" && -n "$TMPDIR" && -d "$TMPDIR" ]]; then
        print_info "Cleaning up temporary files: $TMPDIR"
        rm -rf "$TMPDIR"
    else
        [[ -n "$TMPDIR" ]] && print_info "Temporary files preserved: $TMPDIR"
    fi
}

# Main function
main() {
    local ARGS=()
    
    parse_arguments "$@"
    check_dependencies
    
    # Setup output directory
    if [[ -n "$DEFAULT_OUTPUT_DIR" ]]; then
        TMPDIR="$DEFAULT_OUTPUT_DIR"
        mkdir -p "$TMPDIR"
        CLEANUP=false  # Don't cleanup user-specified directory
    else
        TMPDIR=$(mktemp -d /tmp/git-latexdiff.XXXXXX)
    fi
    
    # Handle cleanup on exit
    if [[ "$NO_CLEANUP" == "true" ]]; then
        CLEANUP=false
    fi
    trap cleanup_files EXIT
    
    local old_file new_file diff_tex result_file
    
    if [[ "$GIT_MODE" == "true" ]]; then
        # Git mode
        local commit1="${ARGS[0]}"
        local commit2="${ARGS[1]:-WORKING}"
        local target_file="${ARGS[2]:-${ARGS[1]}}"
        
        # If only 2 args in git mode, second is the file
        if [[ ${#ARGS[@]} -eq 2 ]]; then
            commit2="WORKING"
            target_file="${ARGS[1]}"
        fi
        
        print_info "Git mode: comparing $commit1 vs $commit2 for $target_file"
        
        old_file="$TMPDIR/old.tex"
        new_file="$TMPDIR/new.tex"
        
        git_extract_file "$commit1" "$target_file" "$old_file" || exit 1
        git_extract_file "$commit2" "$target_file" "$new_file" || exit 1
    else
        # File mode
        old_file="${ARGS[0]}"
        new_file="${ARGS[1]}"
        
        # Validate files exist
        if [[ ! -f "$old_file" ]]; then
            print_error "Old file not found: $old_file"
            exit 1
        fi
        
        if [[ ! -f "$new_file" ]]; then
            print_error "New file not found: $new_file"
            exit 1
        fi
        
        print_info "File mode: comparing $old_file vs $new_file"
    fi
    
    # Generate diff
    diff_tex="$TMPDIR/diff.tex"
    generate_diff "$old_file" "$new_file" "$diff_tex" || exit 1
    
    # Process based on output format
    case "$OUTPUT_FORMAT" in
        pdf)
            result_file=$(compile_diff "$diff_tex" "$TMPDIR") || exit 1
            ;;
        html)
            result_file=$(convert_to_html "$diff_tex" "$TMPDIR") || exit 1
            ;;
        tex)
            result_file="$diff_tex"
            print_success "TeX diff saved: $result_file"
            ;;
        *)
            print_error "Unknown output format: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac
    
    # Open result
    open_result "$result_file" "$OUTPUT_FORMAT"
    
    print_success "Diff complete! Output: $result_file"
}

# Run main function
main "$@"
