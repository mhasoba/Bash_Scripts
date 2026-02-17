#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [-j jobs] [-o outdir] FILE [FILE...]

Converts one or more Markdown files to PDF using ./markdown-to-pdf.sh.
By default runs sequentially; use -j to run conversions in parallel.
If -o is provided, PDFs are written to that output directory.
EOF
  exit 2
}

jobs=1
outdir=""

while getopts ":j:o:" opt; do
  case "$opt" in
    j) jobs="$OPTARG" ;; 
    o) outdir="$OPTARG" ;; 
    *) usage ;;
  esac
done
shift $((OPTIND-1))

if [ $# -eq 0 ]; then
  usage
fi

files=()
for f in "$@"; do
  if [ -e "$f" ]; then
    files+=("$f")
  else
    echo "Warning: '$f' not found, skipping" >&2
  fi
done

if [ ${#files[@]} -eq 0 ]; then
  echo "No input files found." >&2
  exit 1
fi

if [ -n "$outdir" ]; then
  mkdir -p "$outdir"
fi

run_one() {
  local infile="$1"
  local base
  base="$(basename "$infile")"
  base="${base%.*}.pdf"
  if [ -n "$outdir" ]; then
    ./markdown-to-pdf.sh "$infile" "$outdir/$base"
  else
    ./markdown-to-pdf.sh "$infile"
  fi
}

export -f run_one

if [ "$jobs" -le 1 ]; then
  for f in "${files[@]}"; do
    run_one "$f"
  done
else
  # Use xargs for parallelism; requires GNU xargs supporting -0 and -P
  printf '%s\0' "${files[@]}" | xargs -0 -n1 -P"$jobs" -I{} bash -c 'run_one "$@"' _ {}
fi

echo "All done."
