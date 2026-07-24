# Samraat's Collection o' Bash Scripts

A curated collection of useful bash scripts.

## 📁 Script Overview

### 📄 Document Processing
- **`compile-latex.sh`** - Enhanced LaTeX compilation script with bibliography support
- **`docx-to-pdf.sh`** - Convert DOCX files to PDF format
- **`markdown-to-pdf.sh`** - Convert Markdown files to PDF
- **`markdown-to-html.sh`** - Convert Markdown files to HTML
- **`merge-pdfs.sh`** - Merge multiple PDF files into one
- **`pdf-to-text.sh`** - Convert PDF files to plain text with layout options

### 🖼️ Image Processing
- **`pdf-to-png.sh`** - Convert PDF pages to PNG images
- **`shrink-jpg.sh`** - Compress JPEG images to reduce file size
- **`shrink-pdf.sh`** - Compress PDF files to reduce file size
- **`svg-to-pdf.sh`** - Convert SVG files to PDF format
- **`svg-to-png.sh`** - Convert SVG files to PNG format
- **`tiff-to-jpg.sh`** - Convert TIFF images to JPEG format
- **`tiff-to-png.sh`** - Convert TIFF images to PNG format

### 📱 OCR & Text Recognition
- **`ocr-convert.sh`** - 🌟 Universal OCR tool (PDF/images → searchable PDF/text, multi-language)
- **`ocr-pdf.sh`** - ⚠️ Legacy: Simple OCR text extraction
- **`ocr-pdf-textlayer.sh`** - ⚠️ Legacy: Add text layer to PDFs

### 💾 Backup & Synchronization
- **`auto-backup.sh`** - Automated backup script
- **`auto-backup-on-mount.sh`** - Helper for systemd user mount triggers; resolves the mounted device and launches `auto-backup.sh`
- **`backup.sh`** - Snapshot-based backup utility with locking, mount verification, and dry-run support
- **`backup-excludes.txt`** - Managed rsync exclusion list for `backup.sh`
- **`backup-mount.sh`** - Backup with mount operations
- **`sync-laptop-desktop.sh`** - Universal sync tool with VPN support (unison/rsync/rclone)

### 🎥 Media Processing
- **`video-trim.sh`** - Trim video files
- **`inkscape-export.sh`** - Inkscape export operations

### 🔧 File Management
- **`rename-file.sh`** - Rename individual files with patterns
- **`rename-files.sh`** - Batch rename multiple files

### 🔀 Version Control
- **`git-latex-diff.sh`** - Git integration for LaTeX diff operations

## 🚀 Getting Started

### Prerequisites
Most scripts require common Linux utilities. Specific requirements:
- **LaTeX scripts**: `pdflatex`, `bibtex`/`biber`
- **Image processing**: `imagemagick`, `ghostscript`
- **OCR scripts**: `tesseract-ocr`
- **Video processing**: `ffmpeg`

### Installation
1. Clone or download the scripts
2. Make them executable: `chmod +x *.sh`
3. Optionally, add the directory to your PATH

User-local install (recommended):
```bash
# make a personal bin and symlink the utilities there
mkdir -p "$HOME/bin"
ln -sf /path/to/this/directory/markdown-to-pdf.sh "$HOME/bin/markdown-to-pdf"
ln -sf /path/to/this/directory/markdown-to-html.sh "$HOME/bin/markdown-to-html"
chmod +x /path/to/this/directory/*.sh
# ensure ~/bin is in your PATH (add once to ~/.profile or ~/.bashrc)
grep -qxF 'export PATH="$HOME/bin:$PATH"' ~/.profile || echo 'export PATH="$HOME/bin:$PATH"' >> ~/.profile
source ~/.profile
```

System-wide install (requires sudo):
```bash
sudo ln -sf /path/to/this/directory/markdown-to-pdf.sh /usr/local/bin/markdown-to-pdf
sudo ln -sf /path/to/this/directory/markdown-to-html.sh /usr/local/bin/markdown-to-html
sudo chmod +x /path/to/this/directory/*.sh
```

### Usage Examples
```bash
# Compile LaTeX document with bibliography and view
./compile-latex.sh document.tex view --biber

# Compress a large PDF
./shrink-pdf.sh large_file.pdf

# Convert SVG to PNG with specific dimensions
./svg-to-png.sh image.svg 1920 1080

# Generate LaTeX diff between commits
./git-latex-diff.sh --git HEAD~1 HEAD document.tex

# Sync with configuration profile and VPN
./sync-laptop-desktop.sh --profile munro-desktop --verbose

# OCR convert scanned PDF to searchable PDF
./ocr-convert.sh document.pdf

# Extract text from multiple PDFs
./ocr-convert.sh --output text *.pdf

# Convert PDF to plain text with layout preservation
./pdf-to-text.sh document.pdf

# Extract first 10 pages to text
./pdf-to-text.sh --pages 1-10 report.pdf

# Batch convert PDFs to text (raw mode, no layout)
./pdf-to-text.sh --layout raw --output-dir ./text_files/ *.pdf
```

## `markdown-to-pdf.sh`

Convert Markdown files to PDF. The script prefers `pandoc` (direct MD→PDF) and falls back to `markdown` + `wkhtmltopdf`.

Prerequisites:
- `pandoc` (recommended) or `markdown` and `wkhtmltopdf`
- `mktemp` (standard on Linux)

Single-file usage:
```bash
# output filename optional
./markdown-to-pdf.sh notes.md
./markdown-to-pdf.sh notes.md my-notes.pdf
```

Batch (sequential, safe for spaces):
```bash
while IFS= read -r -d '' file; do
	./markdown-to-pdf.sh "$file"
done < <(find . -maxdepth 1 -name '*.md' -print0)
```

Parallel (xargs, limit concurrency):
```bash
find . -maxdepth 1 -name '*.md' -print0 | xargs -0 -n1 -P4 -I{} ./markdown-to-pdf.sh "{}"
```

Recursive find:
```bash
find . -type f -name '*.md' -exec ./markdown-to-pdf.sh {} \;
```

If you'd like a built-in `--parallel` or output-dir option added to the script, open an issue or request to implement it.

Notes and tips:
- The script now prefers `pandoc` with `xelatex` and will attempt to select a Unicode-capable `mainfont` and an emoji/symbol font when available. If you still see "Missing character" warnings for symbols like ✅ or ≥, install a broad Unicode font such as `fonts-noto-serif` and an emoji font like `fonts-noto-color-emoji`.
- You can override the PDF engine via the `PDF_ENGINE` environment variable, e.g. `PDF_ENGINE=pdflatex markdown-to-pdf file.md`.
- When running from other directories prefer the command name (no `./`), e.g. `find . -type f -name '*.md' -exec markdown-to-pdf {} +` so the tool is resolved via your `PATH`.
```

## 📚 Documentation

- **`BASH_CHEATSHEET.md`** - Bash command reference and cheat sheet

## 🔧 Configuration

### Environment Setup
Add useful aliases to your `~/.bashrc`:
```bash
# Add script directory to PATH
export PATH="$PATH:/path/to/this/directory"

# Useful aliases
alias latex-compile='compile-latex.sh'
alias pdf-shrink='shrink-pdf.sh'
alias latex-diff='git-latex-diff.sh'
```

## 📄 License

These scripts are provided as-is for educational and practical use.

---

*💡 **Tip**: Check the individual script files for specific usage instructions and options.*

## Auto-backup on mount via systemd user units

This repository includes a ready-to-enable systemd user `.path` + `.service` pair in `systemd-user/`.
The path unit watches for a mounted directory containing `MhasoBkp`, then `auto-backup-on-mount.sh` resolves the backing device and launches `auto-backup.sh` in `gnome-terminal`.

Install the units into your user systemd directory:

```bash
mkdir -p ~/.config/systemd/user
cp systemd-user/auto-backup-on-mount.path ~/.config/systemd/user/
cp systemd-user/auto-backup-on-mount.service ~/.config/systemd/user/
systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR
systemctl --user daemon-reload
systemctl --user enable --now auto-backup-on-mount.path
```

Check status and logs:

```bash
systemctl --user status auto-backup-on-mount.path
journalctl --user -u auto-backup-on-mount.service -n 50 --no-pager
```

Notes:
- The watched sentinel directory name is `MhasoBkp`, matching the existing check in `auto-backup.sh`.
- The helper script may also be run manually after `chmod +x auto-backup-on-mount.sh`.
- The service inherits GUI session variables from the user systemd manager, so re-run `systemctl --user import-environment ...` after login if `gnome-terminal` does not appear.

## `backup.sh`

The backup script now writes versioned snapshots under a host-specific directory on the mounted backup disk:

```text
<mount-point>/backups/<hostname>/home/
```

Within that tree it creates:
- `snapshots/<timestamp>` for each completed backup
- `latest` symlink pointing to the most recent completed snapshot
- `.incomplete-current` as a reusable staging directory for interrupted runs

Key behavior:
- Verifies the destination path is an active mount point before running.
- Uses a lock file to prevent concurrent backups.
- Supports `--dry-run` for safe preview runs.
- Keeps the newest 14 completed snapshots by default and prunes older ones after a successful backup.
- Supports `--retain-count N` to change how many completed snapshots are kept. Use `0` to disable pruning.
- Stores logs and summary files in the log directory you pass as the second argument.
- Uses `backup-excludes.txt` for rsync exclusions.
- Treats rsync exit code `24` as a warning instead of a hard failure.
- Requires a snapshot-capable Linux filesystem on the backup disk. `ext4`, `xfs`, `btrfs`, and `zfs` are supported; `vfat`/FAT-style filesystems are not.
- Fails fast with a clear message if the mounted backup disk cannot store symlinks/hardlinks.

Examples:

```bash
# Preview the next backup without writing any snapshot data
./backup.sh /media/mhasoba/3207-D6B6 /home/mhasoba/backup-logs --dry-run

# Keep the newest 30 completed snapshots
./backup.sh /media/mhasoba/3207-D6B6 /home/mhasoba/backup-logs --retain-count 30

# Run a snapshot backup and auto-unmount on success
./backup.sh /media/mhasoba/3207-D6B6 /home/mhasoba/backup-logs --auto-unmount
```

If you are using the automatic mount trigger, keep the `MhasoBkp` sentinel directory on the backup disk so `auto-backup-on-mount.sh` can detect the drive and launch `auto-backup.sh`.

## `md2pdf.sh`

A small wrapper that converts multiple Markdown files to PDF using `markdown-to-pdf.sh`.

Features:
- Accepts multiple input files by default.
- `-j N` to run up to N conversions in parallel (requires `xargs -P`).
- `-o DIR` to place output PDFs in a specified directory.

Examples:
```bash
# Convert all markdown files sequentially
./md2pdf.sh *.md

# Convert into an output directory with 4 parallel jobs
./md2pdf.sh -j 4 -o pdfs *.md

# Convert specific files
./md2pdf.sh README.md notes/meeting.md
```

## `markdown-to-html.sh`

Convert Markdown to HTML. Prefers `pandoc` and falls back to the classic `markdown` utility.

Examples:
```bash
# Convert a single file
markdown-to-html README.md

# Read from stdin and write to stdout
cat README.md | markdown-to-html -

# Convert many files
find . -type f -name '*.md' -exec markdown-to-html {} +
```