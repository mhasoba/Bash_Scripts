#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="2.0"

OUTPUT_DIR=""
OUTPUT_SUFFIX=".pdf"
PDF_ENGINE="xelatex"
FONT=""
PAPER_SIZE="a4"
MARGIN="1in"
FONT_SIZE="11pt"
LINE_SPACING="1.15"
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

Convert one or more DOCX files to PDF using pandoc and a LaTeX PDF engine.

Options:
  -o, --output-dir DIR     Write converted files to DIR
  -s, --suffix SUFFIX      Output suffix (default: .pdf)
      --pdf-engine ENGINE  PDF engine (default: xelatex)
      --font FONT_NAME     Main text font (requires xelatex or lualatex)
      --paper-size SIZE    Paper size (default: a4)
      --margin LENGTH      Uniform page margin (default: 1in)
      --font-size SIZE     Document font size (default: 11pt)
      --line-spacing NUM   Line-spacing factor (default: 1.15)
      --overwrite          Overwrite existing output files
  -v, --verbose            Show conversion details
  -q, --quiet              Suppress non-error output
  -h, --help               Show this help message
      --version            Show version information

Examples:
  $SCRIPT_NAME report.docx
  $SCRIPT_NAME --output-dir pdfs meeting.docx notes.docx
  $SCRIPT_NAME --font "Noto Serif" --paper-size letter report.docx
  $SCRIPT_NAME --margin 20mm --font-size 12pt --line-spacing 1.5 report.docx

Dependencies:
  pandoc and the selected PDF engine
  Default engine: sudo apt install pandoc texlive-xetex
EOF
}

validate_options() {
    if [[ -z "$OUTPUT_SUFFIX" || -z "$PDF_ENGINE" || -z "$PAPER_SIZE" || -z "$MARGIN" || -z "$FONT_SIZE" ]]; then
        print_error "Output suffix, engine, paper size, margin, and font size must not be empty"
        exit 2
    fi

    if [[ ! "$LINE_SPACING" =~ ^[0-9]+([.][0-9]+)?$ ]] || [[ "$LINE_SPACING" == "0" || "$LINE_SPACING" == "0.0" || "$LINE_SPACING" == "0.00" ]]; then
        print_error "Line spacing must be a positive number: $LINE_SPACING"
        exit 2
    fi

    if [[ -n "$FONT" && "$PDF_ENGINE" == "pdflatex" ]]; then
        print_error "--font requires xelatex or lualatex"
        exit 2
    fi
}

check_dependencies() {
    if ! command -v pandoc >/dev/null 2>&1; then
        print_error "pandoc is required. Install it on Debian/Ubuntu with: sudo apt install pandoc"
        exit 1
    fi

    if ! command -v "$PDF_ENGINE" >/dev/null 2>&1; then
        if [[ "$PDF_ENGINE" == "xelatex" ]]; then
            print_error "xelatex is required. Install it on Debian/Ubuntu with: sudo apt install texlive-xetex"
        else
            print_error "Selected PDF engine not found: $PDF_ENGINE"
        fi
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

convert_file() {
    local input="$1"
    local output="$2"
    local command=(
        pandoc
        -f docx
        -s
        "--pdf-engine=$PDF_ENGINE"
        -V "papersize=$PAPER_SIZE"
        -V "geometry:margin=$MARGIN"
        -V "fontsize=$FONT_SIZE"
        -V "linestretch=$LINE_SPACING"
        "$input"
        -o "$output"
    )

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

    if [[ -n "$FONT" ]]; then
        command+=(-V "mainfont=$FONT")
    fi

    print_info "Converting $input -> $output"
    if ! "${command[@]}"; then
        print_error "Conversion failed: $input"
        return 1
    fi

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
        --pdf-engine)
            [[ $# -ge 2 ]] || { print_error "$1 requires an engine"; usage >&2; exit 2; }
            PDF_ENGINE="$2"
            shift 2
            ;;
        --font)
            [[ $# -ge 2 ]] || { print_error "$1 requires a font name"; usage >&2; exit 2; }
            FONT="$2"
            shift 2
            ;;
        --paper-size)
            [[ $# -ge 2 ]] || { print_error "$1 requires a paper size"; usage >&2; exit 2; }
            PAPER_SIZE="$2"
            shift 2
            ;;
        --margin)
            [[ $# -ge 2 ]] || { print_error "$1 requires a length"; usage >&2; exit 2; }
            MARGIN="$2"
            shift 2
            ;;
        --font-size)
            [[ $# -ge 2 ]] || { print_error "$1 requires a size"; usage >&2; exit 2; }
            FONT_SIZE="$2"
            shift 2
            ;;
        --line-spacing)
            [[ $# -ge 2 ]] || { print_error "$1 requires a number"; usage >&2; exit 2; }
            LINE_SPACING="$2"
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

validate_options
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
