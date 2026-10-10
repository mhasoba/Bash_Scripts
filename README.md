# Samraat's Collection o' Bash Scripts

A curated collection of useful bash scripts.

## Table of Contents

- [Samraat's Collection o' Bash Scripts](#samraats-collection-o-bash-scripts)
	- [Table of Contents](#table-of-contents)
	- [📁 Script Overview](#-script-overview)
		- [📄 Document Processing](#-document-processing)
		- [🖼️ Image Processing](#️-image-processing)
		- [📱 OCR \& Text Recognition](#-ocr--text-recognition)
		- [🎙️ Audio Transcription](#️-audio-transcription)
		- [💾 Backup \& Synchronization](#-backup--synchronization)
		- [🎥 Media Processing](#-media-processing)
		- [🔧 File Management](#-file-management)
		- [🔀 Version Control](#-version-control)
		- [Supporting Files](#supporting-files)
	- [🚀 Getting Started](#-getting-started)
		- [Prerequisites](#prerequisites)
		- [Installation](#installation)
		- [Usage Examples](#usage-examples)
	- [Detailed Guides](#detailed-guides)
		- [docx-to-pdf.sh](#docx-to-pdfsh)
		- [docx-to-md.sh](#docx-to-mdsh)
		- [markdown-to-pdf.sh](#markdown-to-pdfsh)
		- [backup.sh](#backupsh)
			- [Migrating to a fresh Ubuntu installation](#migrating-to-a-fresh-ubuntu-installation)
			- [VS Code, Copilot, and Codex backups](#vs-code-copilot-and-codex-backups)
		- [md2pdf.sh](#md2pdfsh)
		- [Audio transcription tools](#audio-transcription-tools)
		- [markdown-to-html.sh](#markdown-to-htmlsh)
	- [📚 Documentation](#-documentation)
	- [🔧 Configuration](#-configuration)
		- [Environment Setup](#environment-setup)
	- [📄 License](#-license)

## 📁 Script Overview

### 📄 Document Processing
- **`compile-latex.sh`** - Enhanced LaTeX compilation script with bibliography support
- **`docx-to-md.sh`** - Convert DOCX files to Markdown
- **`docx-to-pdf.sh`** - Convert DOCX files to PDF format
- **`markdown-to-pdf.sh`** - Convert Markdown files to PDF
- **`md2pdf.sh`** - Batch-convert Markdown files to PDF, with parallel jobs and output-directory support
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

### 🎙️ Audio Transcription
- **[`transcription/transcribe-audio.sh`](transcription/transcribe-audio.sh)** - OpenAI Whisper CLI alternative for plain transcription
- **[`transcription/`](transcription/README.md)** - WhisperX pipeline for speaker-labeled transcription, including batch processing

### 💾 Backup & Synchronization
- **`auto-backup.sh`** - Automated backup script
- **`auto-backup-on-mount.sh`** - Helper for systemd user mount triggers; resolves the mounted device and launches `auto-backup.sh`
- **`backup.sh`** - Snapshot-based backup utility with locking, mount verification, and dry-run support
- **`backup-excludes.txt`** - Managed rsync exclusion list for `backup.sh`
- **`sync-laptop-desktop.sh`** - Universal sync tool with VPN support (unison/rsync/rclone)

### 🎥 Media Processing
- **`video-trim.sh`** - Trim video files
- **`inkscape-export.sh`** - Inkscape export operations

### 🔧 File Management
- **`rename-file.sh`** - Rename individual files with patterns
- **`rename-files.sh`** - Batch rename multiple files

### 🔀 Version Control
- **`git-latex-diff.sh`** - Git integration for LaTeX diff operations

### Supporting Files
- **`docx-to-md-strip-images.lua`** - Pandoc filter used by the DOCX-to-Markdown conversion

## 🚀 Getting Started

### Prerequisites
Most scripts require common Linux utilities. Specific requirements:
- **LaTeX scripts**: `pdflatex`, `bibtex`/`biber`
- **DOCX to PDF**: `pandoc`, `texlive-xetex` (default PDF engine)
- **DOCX to Markdown**: `pandoc`
- **Image processing**: `imagemagick`, `ghostscript`
- **OCR scripts**: `tesseract-ocr`
- **Video processing**: `ffmpeg`
- **Audio transcription**: `python3`, `ffmpeg`, `openai-whisper` or `whisperx`, and `python3-venv` for the virtualenv-based wrapper
- **Speaker diarization**: a Hugging Face access token in `HF_TOKEN`

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

# Convert one or more DOCX files to Markdown
./docx-to-md.sh report.docx notes.docx

# Write Markdown files to a separate directory
./docx-to-md.sh --output-dir markdown *.docx

# Convert DOCX files to A4 PDFs in a separate directory
./docx-to-pdf.sh --output-dir pdfs *.docx

# Adjust document layout while converting
./docx-to-pdf.sh --margin 20mm --font-size 12pt --line-spacing 1.5 report.docx
```

## Detailed Guides

### docx-to-pdf.sh

Convert one or more DOCX files to PDF using `pandoc` and XeLaTeX.

Prerequisite:
```bash
sudo apt install pandoc texlive-xetex
```

By default, PDFs use A4 paper with 1-inch margins, 11pt text, and 1.15 line spacing. Embedded DOCX images are preserved through Pandoc's normal conversion path.

Examples:
```bash
# Write report.pdf beside report.docx
./docx-to-pdf.sh report.docx

# Convert several documents into a dedicated directory
./docx-to-pdf.sh --output-dir pdfs meeting.docx notes.docx

# Use a font and US Letter paper
./docx-to-pdf.sh --font "Noto Serif" --paper-size letter report.docx

# Customize the document layout and replace an existing PDF
./docx-to-pdf.sh --margin 20mm --font-size 12pt --line-spacing 1.5 --overwrite report.docx

# Use another installed LaTeX engine
./docx-to-pdf.sh --pdf-engine lualatex report.docx
```

Use `--suffix` to select a different output suffix. Existing PDFs are skipped unless `--overwrite` is supplied. `--font` requires either `xelatex` or `lualatex`; use `--pdf-engine` to choose another installed LaTeX engine.

### docx-to-md.sh

Convert one or more DOCX files to Markdown using `pandoc`.

Prerequisite:
```bash
sudo apt install pandoc
```

Examples:
```bash
# The output defaults to report.md beside report.docx
./docx-to-md.sh report.docx

# Convert several documents at once
./docx-to-md.sh meeting.docx notes.docx

# Use a separate output directory and replace existing Markdown files
./docx-to-md.sh --output-dir markdown --overwrite *.docx
```

Use `--suffix .markdown` to select a different output suffix. Existing output files are skipped unless `--overwrite` is supplied. The utility preserves text structure that Pandoc supports, such as headings, lists, and tables; embedded images are omitted, hard line breaks are normalized, and escaped apostrophes are cleaned.

### markdown-to-pdf.sh

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

For parallel conversions or an output directory, use [`md2pdf.sh`](#md2pdfsh), which wraps this converter and provides both options.

Notes and tips:
- The script now prefers `pandoc` with `xelatex` and will attempt to select a Unicode-capable `mainfont` and an emoji/symbol font when available. If you still see "Missing character" warnings for symbols like ✅ or ≥, install a broad Unicode font such as `fonts-noto-serif` and an emoji font like `fonts-noto-color-emoji`.
- You can override the PDF engine via the `PDF_ENGINE` environment variable, e.g. `PDF_ENGINE=pdflatex markdown-to-pdf file.md`.
- When running from other directories prefer the command name (no `./`), e.g. `find . -type f -name '*.md' -exec markdown-to-pdf {} +` so the tool is resolved via your `PATH`.
```

### Laptop/desktop synchronization with Unison

The local `~/.unison/MunroDesktop.prf` profile selects personal documents,
desktop files, music, shell dotfiles, Git configuration, `bin`, templates,
custom fonts, stable VS Code settings/keybindings/snippets/prompts, Codex
rules/skills, and selected application preferences. Scripts in this repository
are already covered by the selected `Documents` directory.

Clementine and Inkscape are limited to preference files rather than entire
state directories. Zotero, VirtualBox, Skype, Transmission, and whole JabRef
state directories are no longer selected; JabRef's selected Java preferences
remain. Files already present on either machine are not deleted just because
their paths were removed from the profile.

Keep editor workspace/global storage, Copilot/Codex conversations and databases,
authentication, SSH/GPG keys, keyrings, caches, history, and generated Python
launchers in `.local/bin` machine-local. Codex `config.toml` is not selected
because it needs a separate check for credentials and machine-specific paths.
These files can still be backed up without continuously merging them.

Before the first sync, review `.bashrc`, `.profile`, `.gitconfig`, editor and
application preferences for host-specific paths or credentials. Use conditional
settings or separate per-machine overrides where needed. Close applications
whose preferences are being synchronized. Betterbird remains in its separate
profile and must be closed on both machines; prefer application-native sync
for mail and Zotero libraries. Avoid concurrent edits to the same Git working
tree on both machines; use Git remotes for collaborating on repository history.

The installed `munro-desktop` launcher configuration and generated examples use
`-batch=false -confirmbigdel=true`, without `-force newer`. Conflicting edits
must be reviewed rather than resolved by timestamps. `UNISON_OPTIONS` accepts
whitespace-separated arguments, not shell expressions or shell-quoted values;
put complex settings such as SSH arguments in the Unison profile.

```bash
# Connect using OpenVPN 3 first (replace the path with your VPN configuration)
openvpn3 session-start --config /path/to/vpn.ovpn

# Interactive reconciliation; inspect conflicts before accepting changes
./sync-laptop-desktop.sh --profile munro-desktop --no-vpn --verbose

# Connectivity check ONLY: does not preview pending file changes
./sync-laptop-desktop.sh --profile munro-desktop --no-vpn --dry-run --verbose

# Isolated launcher checks: no network access or real synchronization
bash -n sync-laptop-desktop.sh test-sync-laptop-desktop.sh
bash test-sync-laptop-desktop.sh
```

The old NetworkManager IC VPN is no longer used for this workflow. Connect with
OpenVPN 3 before launching sync; `--no-vpn` overrides legacy VPN settings in the
launcher configuration and leaves your VPN session connected after sync.
Generated Unison examples disable VPN management. Dry runs skip pre/post-sync
hooks. Without `--no-vpn`, the launcher can still manage a configured
NetworkManager VPN. The local Unison profile controls both roots
when launched here; if initiating sync from the desktop, install equivalent
preferences there with appropriate root ordering. These installed profiles live
outside this repository. The empty `default.prf` is not a usable sync profile;
select `munro-desktop` explicitly or configure another profile.

### Auto-backup on mount via systemd user units

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
- The launchers resolve sibling scripts relative to their own location. The installed service still needs the correct absolute installation path.
- GNOME Terminal and `x-terminal-emulator` share the same confirmation prompt. If neither is available, the launcher reports an error rather than starting an unattended backup.

Use only the user-systemd trigger. If an older installation has the legacy
`/etc/udev/rules.d/99-auto-backup.rules` rule calling `auto-backup.sh`, review
its contents and retire it on that machine (administrator access required):

```bash
sudo mv /etc/udev/rules.d/99-auto-backup.rules /etc/udev/rules.d/99-auto-backup.rules.disabled
sudo udevadm control --reload-rules
```

Do not replay device events with `udevadm trigger` merely to test a backup.

### backup.sh

The backup script now writes versioned snapshots under a host-specific directory on the mounted backup disk:

```text
<mount-point>/backups/<hostname>/home/
```

Within that tree it creates:
- `snapshots/<timestamp>` for each completed backup
- `latest` symlink pointing to the most recent completed snapshot
- `state/<timestamp>` containing migration exports for the matching snapshot
- `.incomplete-current` as a reusable staging directory for interrupted runs

Key behavior:
- Verifies the destination is on a separate device mounted under `/mnt`, `/media`, or `/run/media`. Ordinary internal-disk directories and root-device bind mounts are rejected; subdirectories of valid backup mounts are supported.
- Uses a lock file to prevent concurrent backups.
- Supports `--dry-run` for safe preview runs.
- Keeps the newest 14 completed snapshots by default and prunes older ones after a successful backup.
- Supports `--retain-count N` to change how many completed snapshots are kept. Use `0` to disable pruning.
- Exports a restore-state bundle into temporary staging, then saves it under `state/<timestamp>` on the backup disk before finalizing the home snapshot. Temporary exports are removed on exit and matching disk bundles are pruned with snapshots. Existing local `restore-state-*` exports are left untouched.
- Uses a relative `latest` link so new snapshots remain accessible after moving the backup disk to another mount path. Existing snapshots are unchanged.
- Dry runs skip machine-state exports and do not write a state bundle to the disk.
- Supports `--no-state-export` when you want a data-only backup run.
- Stores logs and summary files in the log directory you pass as the second argument.
- Uses `backup-excludes.txt` for rsync exclusions.
- Treats rsync exit code `24` as a warning instead of a hard failure.
- Requires a snapshot-capable Linux filesystem on the backup disk. `ext4`, `xfs`, `btrfs`, and `zfs` are supported; `vfat`/FAT-style filesystems are not.
- Fails fast with a clear message if the mounted backup disk cannot store symlinks/hardlinks.
- If you want automatic launch on mount, keep the `MhasoBkp` directory on the drive. The automatic flow now writes the backup into that directory and uses it as the backup destination.

Examples:

```bash
# Preview the next backup without writing any snapshot data
./backup.sh /media/mhasoba/3207-D6B6/MhasoBkp /home/mhasoba/backup-logs --dry-run

# Keep the newest 30 completed snapshots
./backup.sh /media/mhasoba/3207-D6B6/MhasoBkp /home/mhasoba/backup-logs --retain-count 30

# Run a snapshot backup and auto-unmount on success
./backup.sh /media/mhasoba/3207-D6B6/MhasoBkp /home/mhasoba/backup-logs --auto-unmount

# Data-only run (skip machine-state export files)
./backup.sh /media/mhasoba/3207-D6B6/MhasoBkp /home/mhasoba/backup-logs --no-state-export
```

If you are using the automatic mount trigger, the backup lands in `MhasoBkp/` on the mounted drive, and `auto-backup-on-mount.sh` will launch `auto-backup.sh` when that mount is detected.

#### Migrating to a fresh Ubuntu installation

The home snapshot includes hidden files such as `.inputrc`, `.bashrc`, `.profile`,
`.bash_profile`, `.bash_history`, `.zshrc`, `.zsh_history`, `.tmux.conf`, and
`.gitconfig`, as well as `.config`, `.local/share`, `.local/bin`, `bin`, `.ssh`,
and `.gnupg`, when present and not excluded. Cache paths are excluded, including
known VS Code caches. Chrome profiles remain explicitly excluded; review
`backup-excludes.txt` before relying on a profile being available for restoration.
Virtual environments are not blanket-excluded because they may contain files
you need; add specific rebuildable paths to your exclusion list if desired.

For each completed run, `home/state/<timestamp>/` contains:

- APT manual-package and package-version lists, Snap inventory, Flatpak apps and remotes.
- A dconf export of the user's GNOME settings, user crontab, and enabled user-service inventory.
- A VS Code extension/version inventory and best-effort running-editor/AI process report.
- OS/account metadata, selected readable `/etc` files, and the exclusions used.
- A source configuration inventory, export status/errors, and `RESTORE.txt` guidance.

The configuration inventory reports presence, not successful backup coverage.
Check the rsync log and export status for missing or unreadable data. Optional
commands that are unavailable or fail are reported; inability to write or save
the bundle prevents snapshot finalization. `--no-state-export` retains the
existing data-only behaviour. No packages are installed during backup.

Mount the drive and cancel the automatic backup prompt before restoring. Choose
a completed timestamp from `home/snapshots/` (not `.incomplete-current`) and
recover documents first, then selected application settings with applications
closed. The matching `state/<timestamp>/RESTORE.txt` explains package and desktop
settings restoration. Review package availability and repository compatibility
on the new Ubuntu release; never restore `/etc` wholesale.

Use encrypted storage for SSH/GPG keys, browser sessions, shell history, and
other credentials. Bundle directories use mode `700`, but this is not encryption;
the script does not encrypt the disk or create an additional credentials tarball.

#### VS Code, Copilot, and Codex backups

Settings, keybindings, snippets, profiles, and local Copilot/workspace storage
under `.config/Code/User` remain included. Codex configuration, rules, skills,
sessions, and databases under `.codex` remain included, including SQLite WAL and
SHM files. Inclusion is subject to the exclusion list and successful file reads.

The default policy excludes `.vscode/extensions` binaries, Codex cache/model
cache files, temporary directories, IPC and transient lock files, and
`.codex/auth.json`. It does not blanket-exclude database journals. Existing
snapshots are unchanged and can still contain credentials until normal retention
removes them; other retained profiles, histories, and project files may contain
secrets too. Use encrypted storage regardless of the authentication exclusion.
To deliberately include authentication, use a separate `EXCLUDE_FILE` without
that rule only after considering credential exposure and encrypted storage.

Migration bundles contain `vscode-extensions.txt`, exported using
`code --list-extensions --show-versions`. Missing or failing CLIs are recorded
in `export-status.txt`. This inventories the current user's default CLI profile;
additional profiles and remote editor installations need separate inventories.
No extensions are installed or applications stopped during backup.

Before a migration backup, close VS Code and Codex. The script warns in the log
if likely processes are running, even with `--no-state-export`, and records them
in `running-ai-apps.txt` when state export is enabled. Detection is best effort;
an empty process report does not guarantee a consistent live database copy.
Plain rsync is not a transaction-consistent database backup.

On the new installation, restore settings first, review the extension inventory,
and reinstall compatible extensions by ID (the portion before `@`). Sign in to
GitHub/OpenAI again. Restore histories or databases selectively with applications
closed rather than replacing the entire editor profile blindly. Consult the
matching migration bundle's `RESTORE.txt` for the rest of the restore checklist.

Run isolated migration checks without mounting a disk or starting a real backup:

```bash
bash -n backup.sh test-backup.sh
bash test-backup.sh
```

The checks cover exports, retention, mount validation, lock handling, dry runs,
and both terminal launchers using mocked commands. AI settings/history retention
and cache/authentication exclusions are checked with real rsync on temporary
fixtures; extension discovery and process detection are mocked. A real-drive dry run can be
performed with `backup.sh <mounted-backup-directory> <log-directory> --dry-run`;
it writes local logs but does not create snapshots or unmount the disk.

### md2pdf.sh

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

### Audio transcription tools

The OpenAI Whisper CLI and WhisperX speaker-diarization tools are grouped under [`transcription/`](transcription/README.md). Use the OpenAI Whisper script for a simple transcript in TXT, SRT, VTT, JSON, or TSV; use WhisperX for aligned word timestamps and speaker labels.

The WhisperX scripts read `HF_TOKEN` from the repository-root `.env` when it is not already exported. The file is ignored by Git; restrict local access with `chmod 600 .env`.

### markdown-to-html.sh

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