#!/usr/bin/env bash
set -euo pipefail

usage() {
	echo "Usage: $0 <input.md> [output.pdf]"
	exit 2
}

if [ "${1:-}" = "" ]; then
	usage
fi

input="$1"
if [ ! -f "$input" ]; then
	echo "Error: '$input' not found" >&2
	exit 1
fi

output="${2:-}"
if [ -z "$output" ]; then
	output="${input%.*}.pdf"
fi

command -v mktemp >/dev/null 2>&1 || { echo "mktemp is required" >&2; exit 1; }

cleanup() {
	[ -n "${tmp:-}" ] && rm -f "$tmp"
	[ -n "${tmpmd:-}" ] && rm -f "$tmpmd"
	[ -n "${tmpfilter:-}" ] && rm -f "$tmpfilter"
	[ -n "${tmpheader:-}" ] && rm -f "$tmpheader"
}
trap cleanup EXIT

# Prefer pandoc when available (direct MD -> PDF)
if command -v pandoc >/dev/null 2>&1; then
	# preprocess: replace Unicode minus (U+2212) with ASCII hyphen-minus
	# to avoid "Unicode character − (U+2212) not set up for use with LaTeX" errors
	tmpmd="$(mktemp --suffix=.md)"
	sed 's/−/-/g' "$input" > "$tmpmd"
	# use XeLaTeX for proper Unicode support
	pdf_engine="${PDF_ENGINE:-xelatex}"

	# Pick a main text font with broad Unicode coverage
	font_arg=()
	if command -v fc-match >/dev/null 2>&1; then
		for f in "DejaVu Serif" "Noto Serif" "FreeSerif" "Linux Libertine O" "Times New Roman"; do
			if fc-match "$f" >/dev/null 2>&1; then
				font_arg=(--variable "mainfont=$f")
				break
			fi
		done
	fi

	# Try to find an emoji/symbol-capable font for dingbats and emoji
	emoji_font=""
	if command -v fc-match >/dev/null 2>&1; then
		for ef in "Noto Color Emoji" "Symbola" "DejaVu Sans" "Apple Color Emoji" "Segoe UI Emoji" "Noto Emoji"; do
			if fc-match "$ef" >/dev/null 2>&1; then
				emoji_font="$ef"
				break
			fi
		done
	fi

	# Create pandoc header to define \emoji command (uses fontspec)
	tmpheader="$(mktemp --suffix=.tex)"
	{
		echo '\usepackage{amssymb}'
		echo '\usepackage{fontspec}'
		if [ -n "$emoji_font" ]; then
			# pass the found emoji font
			echo "\\newfontfamily\\emojiFont{$emoji_font}"
			echo '\newcommand{\\emoji}[1]{{\\emojiFont #1}}'
		else
			# fallback: define \emoji to be identity (may fallback to glyphs in main font)
			echo '\newcommand{\\emoji}[1]{#1}'
		fi
	} > "$tmpheader"

	# Create a small lua filter to replace problematic Unicode with LaTeX-friendly constructs
	tmpfilter="$(mktemp --suffix=.lua)"
	cat > "$tmpfilter" <<'LUAF'
-- pandoc lua filter: replace certain Unicode symbols with LaTeX-safe inlines
local pandoc = require('pandoc')

local repl = {
  ['≥'] = pandoc.Math('InlineMath','\\geq'),
  ['≈'] = pandoc.Math('InlineMath','\\approx'),
  ['✅'] = pandoc.RawInline('latex','\\emoji{✅}'),
  ['✔'] = pandoc.RawInline('latex','\\emoji{✔}'),
  ['✓'] = pandoc.RawInline('latex','\\emoji{✓}'),
  ['✗'] = pandoc.RawInline('latex','\\emoji{✗}'),
  ['⚠'] = pandoc.RawInline('latex','\\emoji{⚠}'),
}

function Str(el)
  if not el.text:find('[≥≈✅✔✓✗⚠]') then return nil end
  local out = {}
  for uchar in el.text:gmatch(utf8.charpattern) do
	local r = repl[uchar]
	if r then
	  table.insert(out, r)
	else
	  table.insert(out, pandoc.Str(uchar))
	end
  end
  return out
end

return { { Str = Str } }
LUAF

	pandoc "$tmpmd" --pdf-engine="$pdf_engine" --lua-filter="$tmpfilter" --include-in-header="$tmpheader" "${font_arg[@]}" -o "$output"
	echo "Wrote $output"
	exit 0
fi

# Fallback: markdown -> html -> wkhtmltopdf
for cmd in markdown wkhtmltopdf; do
	command -v "$cmd" >/dev/null 2>&1 || { echo "Please install '$cmd' or 'pandoc'." >&2; exit 1; }
done

tmp="$(mktemp --suffix=.html)"
markdown "$input" > "$tmp"
wkhtmltopdf "$tmp" "$output"
echo "Wrote $output"