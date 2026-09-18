#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_FILTER="$SCRIPT_DIR/docx-to-md-strip-images.lua"
VERSION="1.0"

OUTPUT_DIR=""
OUTPUT_SUFFIX=".md"
OVERWRITE=false
VERBOSE=false
QUIET=false
INPUT_FILES=()

print_error() {
    echo "Error: $1" >&2
}

print_warning() {
    [[ "$QUIET" == false ]] && echo "Warning: $1" >&2
}

print_info() {
    [[ "$VERBOSE" == true ]] && echo "$1"
}

print_success() {
    [[ "$QUIET" == false ]] && echo "Wrote $1"
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <input_files...>

Convert one or more DOCX files to Markdown using pandoc.

Options:
  -o, --output-dir DIR  Write converted files to DIR
  -s, --suffix SUFFIX   Output suffix (default: .md)
      --overwrite        Overwrite existing output files
  -v, --verbose          Show conversion details
  -q, --quiet            Suppress non-error output
  -h, --help             Show this help message
      --version          Show version information

Examples:
  $SCRIPT_NAME report.docx
  $SCRIPT_NAME meeting.docx notes.docx
  $SCRIPT_NAME --output-dir markdown *.docx
  $SCRIPT_NAME --overwrite --suffix .markdown report.docx

Dependency:
  pandoc (install on Debian/Ubuntu: sudo apt install pandoc)

Note: Embedded images are omitted, hard line breaks are normalized, and escaped apostrophes are cleaned.
EOF
}

check_dependencies() {
    if ! command -v pandoc >/dev/null 2>&1; then
        print_error "pandoc is required. Install it on Debian/Ubuntu with: sudo apt install pandoc"
        exit 1
    fi

    if [[ ! -f "$IMAGE_FILTER" ]]; then
        print_error "Image filter not found: $IMAGE_FILTER"
        exit 1
    fi
}

get_output_path() {
    local input="$1"
    local basename="${input##*/}"
    basename="${basename%.*}"

    if [[ -n "$OUTPUT_DIR" ]]; then
        printf '%s/%s%s\n' "$OUTPUT_DIR" "$basename" "$OUTPUT_SUFFIX"
    else
        printf '%s%s\n' "${input%.*}" "$OUTPUT_SUFFIX"
    fi
}

normalize_output() {
    sed -i "s/\\\\'/'/g" "$1"
}

convert_file() {
    local input="$1"
    local output="$2"

    if [[ ! -f "$input" ]]; then
        print_error "File not found: $input"
        return 1
    fi

    if [[ "${input,,}" != *.docx ]]; then
        print_error "Expected a .docx file: $input"
        return 1
    fi

    if [[ -f "$output" && "$OVERWRITE" == false ]]; then
        print_warning "Skipping existing file: $output"
        return 0
    fi

    print_info "Converting $input -> $output"
    if ! pandoc -f docx -t markdown --lua-filter="$IMAGE_FILTER" "$input" -o "$output"; then
        print_error "Conversion failed: $input"
        return 1
    fi

    normalize_output "$output"

    print_success "$output"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output-dir)
            [[ $# -ge 2 ]] || { print_error "$1 requires a directory"; usage >&2; exit 2; }
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -s|--suffix)
            [[ $# -ge 2 ]] || { print_error "$1 requires a suffix"; usage >&2; exit 2; }
            OUTPUT_SUFFIX="$2"
            shift 2
            ;;
        --overwrite)
            OVERWRITE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --version)
            echo "$SCRIPT_NAME $VERSION"
            exit 0
            ;;
        --)
            shift
            INPUT_FILES+=("$@")
            break
            ;;
        -*)
            print_error "Unknown option: $1"
            usage >&2
            exit 2
            ;;
        *)
            INPUT_FILES+=("$1")
            shift
            ;;
    esac
done

if [[ ${#INPUT_FILES[@]} -eq 0 ]]; then
    usage >&2
    exit 2
fi

check_dependencies

if [[ -n "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR"
fi

failures=0
for input in "${INPUT_FILES[@]}"; do
    output="$(get_output_path "$input")"
    if ! convert_file "$input" "$output"; then
        ((failures += 1))
    fi
done

if [[ $failures -gt 0 ]]; then
    print_error "$failures conversion(s) failed"
    exit 1
fi