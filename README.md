# Samraat's Collection o' Bash Scripts

A curated collection of useful bash scripts.

## 📁 Script Overview

### 📄 Document Processing
- **`compile-latex.sh`** - Enhanced LaTeX compilation script with bibliography support
- **`docx-to-pdf.sh`** - Convert DOCX files to PDF format
- **`markdown-to-pdf.sh`** - Convert Markdown files to PDF
- **`merge-pdfs.sh`** - Merge multiple PDF files into one

### 🖼️ Image Processing
- **`pdf-to-png.sh`** - Convert PDF pages to PNG images
- **`shrink-jpg.sh`** - Compress JPEG images to reduce file size
- **`shrink-pdf.sh`** - Compress PDF files to reduce file size
- **`svg-to-pdf.sh`** - Convert SVG files to PDF format
- **`svg-to-png.sh`** - Convert SVG files to PNG format
- **`tiff-to-jpg.sh`** - Convert TIFF images to JPEG format
- **`tiff-to-png.sh`** - Convert TIFF images to PNG format

### 📱 OCR & Text Recognition
- **`ocr-pdf.sh`** - Perform OCR on PDF files
- **`ocr-pdf-textlayer.sh`** - Add searchable text layer to PDF files

### 💾 Backup & Synchronization
- **`auto-backup.sh`** - Automated backup script
- **`backup.sh`** - General purpose backup utility
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