#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <input.md|-> [output.html]"
    echo
    echo "If input is '-', read markdown from stdin. If output is omitted,"
    echo "the output filename will be <input>.html (or stdout if input is '-')."
    exit 2
}

if [ "${1:-}" = "" ]; then
    usage
fi

input="$1"
output="${2:-}"

if [ "$input" = "-" ]; then
    # read from stdin
    if [ -z "$output" ]; then
        if command -v pandoc >/dev/null 2>&1; then
            pandoc -f markdown -t html -s -o -
            exit 0
        elif command -v markdown >/dev/null 2>&1; then
            markdown -q -
            exit 0
        else
            echo "Please install pandoc or markdown." >&2
            exit 1
        fi
    else
        # write stdin -> output file
        if command -v pandoc >/dev/null 2>&1; then
            pandoc -f markdown -t html -s -o "$output"
            echo "Wrote $output"
            exit 0
        elif command -v markdown >/dev/null 2>&1; then
            markdown -q - > "$output"
            echo "Wrote $output"
            exit 0
        else
            echo "Please install pandoc or markdown." >&2
            exit 1
        fi
    fi
fi

if [ ! -f "$input" ]; then
    echo "Error: '$input' not found" >&2
    exit 1
fi

if [ -z "$output" ]; then
    output="${input%.*}.html"
fi

# Prefer pandoc for a robust conversion
if command -v pandoc >/dev/null 2>&1; then
    tmpmd="$(mktemp --suffix=.md)"
    # Normalize Unicode minus to ASCII, remove possible UTF-8 BOM,
    # and convert CRLF -> LF to avoid mismatches when detecting frontmatter.
    awk 'NR==1 { if (substr($0,1,3) == "\357\273\277") $0 = substr($0,4) } { gsub("−","-"); sub(/\r$/,""); print }' "$input" > "$tmpmd"

    # If the file starts with YAML/TOML front-matter (--- or +++), strip it.
    first_line="$(head -n1 "$tmpmd" || true)"
    # trim trailing CR (if any) then check for YAML/TOML front-matter markers
    if printf "%s" "$first_line" | tr -d '\r' | grep -qE '^(-{3}|\+{3})\s*$'; then
        # look for a closing marker (---, ..., or +++) after the first line
        # find a closing marker (---, ..., or +++) taking possible CR into account
        close_rel=$(tail -n +2 "$tmpmd" | sed 's/\r$//' | grep -nE '^(---|\.\.\.|\+\+\+)\s*$' | head -n1 | cut -d: -f1 || true)
        if [ -n "$close_rel" ]; then
            close_line=$((close_rel+1))
            sed "1,${close_line}d" "$tmpmd" > "${tmpmd}.nofm" && mv "${tmpmd}.nofm" "$tmpmd"
        else
            # no explicit closing marker; remove until the first blank line after the header
            awk 'NR==1{next} { if ($0=="" && !done){done=1; next} if (!done) next; print }' "$tmpmd" > "${tmpmd}.nofm" && mv "${tmpmd}.nofm" "$tmpmd"
        fi
    else
        # Document does not start with front-matter; sanitize isolated marker
        # lines (---, ..., +++) which some pandoc versions can misinterpret
        # as YAML blocks when present. Replace them with an explicit HTML
        # horizontal rule so content renders but isn't parsed as YAML.
        sed -i -e 's/^[[:space:]]*---[[:space:]]*$/<hr \/>/' \
               -e 's/^[[:space:]]*\.\.\.[[:space:]]*$/<hr \/>/' \
               -e 's/^[[:space:]]*\+\+\+[[:space:]]*$/<hr \/>/' "$tmpmd"
    fi
    fi

    # If the original file did not include an explicit title in its front-matter,
    # provide a sensible default title (filename) to avoid pandoc's "nonempty <title>"
    # warning. Check the original input for a title: only examine the leading block.
    has_title=0
    if head -n50 "$input" | grep -qE '^title:\s+'; then
        has_title=1
    fi
    title_arg=()
    if [ "$has_title" -eq 0 ]; then
        base="$(basename "$input")"
        name="${base%.*}"
        title_arg=(--metadata "title=$name")
    fi

    pandoc "$tmpmd" -f markdown -t html -s "${title_arg[@]}" -o "$output"
    rm -f "$tmpmd"
    echo "Wrote $output"
    exit 0
fi

# Fallback: use classic `markdown` program
if command -v markdown >/dev/null 2>&1; then
    markdown "$input" > "$output"
    echo "Wrote $output"
    exit 0
fi

echo "Please install 'pandoc' or the 'markdown' utility to convert markdown to HTML." >&2
exit 1
