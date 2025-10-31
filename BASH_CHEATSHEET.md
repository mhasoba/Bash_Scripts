# Bash Command Reference & Cheat Sheet
*Last Updated: October 31, 2025*

A collection of useful bash commands, snippets, and references for system administration and development tasks.

---

## 🔄 File Synchronization

### Unison - File Synchronization
- **Purpose**: Bidirectional file synchronization between systems
- **Tutorial**: [File synchronization between Ubuntu servers](http://rbgeek.wordpress.com/2012/08/30/file-synchronization-between-two-ubuntu-servers-using-unison/)
- **Installation**: `sudo apt install unison`
- **Basic usage**: `unison /path/to/local ssh://user@remote//path/to/remote`

### Rsync - One-way Synchronization
```bash
# Sync local to remote (with progress)
rsync -avz --progress /local/path/ user@remote:/remote/path/

# Sync remote to local
rsync -avz --progress user@remote:/remote/path/ /local/path/

# Dry run (preview changes)
rsync -avz --dry-run /source/ /destination/
```

---

## 📁 File Management

### Replace Spaces with Underscores
```bash
# Replace spaces in all files in current directory
for f in *\ *; do mv "$f" "${f// /_}"; done

# More robust version with error checking
for f in *" "*; do 
    if [ -f "$f" ]; then
        mv "$f" "${f// /_}" && echo "Renamed: $f"
    fi
done

# Recursive version for all subdirectories
find . -name "* *" -type f | while IFS= read -r file; do
    mv "$file" "${file// /_}"
done
```

### Other Useful File Operations
```bash
# Find and rename files with specific extension
find . -name "*.txt" -exec rename 's/ /_/g' {} \;

# Remove special characters from filenames
for f in *; do mv "$f" "$(echo "$f" | sed 's/[^a-zA-Z0-9._-]/_/g')"; done

# Convert filenames to lowercase
for f in *; do mv "$f" "${f,,}"; done
```

---

## 🔐 SSH Configuration & Management

### SSH Key Generation (Modern Approach)
```bash
# Generate Ed25519 key (recommended, more secure than RSA)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Generate RSA key (if Ed25519 not supported)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Generate with custom filename
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_custom
```

### SSH Key Management
```bash
# List SSH directory contents
ls -la ~/.ssh/

# Check if ssh-agent is running
ps -e | grep [s]sh-agent

# Start ssh-agent if not running
eval "$(ssh-agent -s)"

# Add key to ssh-agent
ssh-add ~/.ssh/id_ed25519
ssh-add ~/.ssh/id_rsa

# List loaded keys
ssh-add -l

# Display public key
cat ~/.ssh/id_ed25519.pub
cat ~/.ssh/id_rsa.pub

# Copy public key to clipboard (if xclip installed)
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard
```

### SSH Connection & File Transfer
```bash
# Basic SSH connection
ssh user@hostname

# SSH with specific key
ssh -i ~/.ssh/custom_key user@hostname

# SSH with port forwarding
ssh -L 8080:localhost:80 user@hostname

# Copy files from remote to local
scp user@remote:/path/to/file /local/path/
scp -r user@remote:/path/to/directory/ /local/path/

# Copy files from local to remote
scp /local/file user@remote:/remote/path/
scp -r /local/directory/ user@remote:/remote/path/

# Using rsync over SSH (preferred for large transfers)
rsync -avz -e ssh user@remote:/remote/path/ /local/path/
```

### SSH Configuration (~/.ssh/config)
```bash
# Example SSH config for easy connections
Host myserver
    HostName server.example.com
    User myusername
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    
Host *.local
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

---

## 📦 Archive Creation & Extraction

### Tar Archives
```bash
# Create archive (no compression)
tar -cf archive.tar file1 file2 directory/

# Create compressed archive (gzip)
tar -czf archive.tar.gz file1 file2 directory/

# Create compressed archive (bzip2 - better compression)
tar -cjf archive.tar.bz2 file1 file2 directory/

# Create archive with progress
tar -czf - file1 file2 | pv > archive.tar.gz

# Extract archive
tar -xf archive.tar
tar -xzf archive.tar.gz
tar -xjf archive.tar.bz2

# List archive contents
tar -tf archive.tar
tar -tzf archive.tar.gz

# Extract to specific directory
tar -xzf archive.tar.gz -C /target/directory/

# Extract specific files
tar -xzf archive.tar.gz file1 directory/file2
```

### Zip Archives
```bash
# Create zip archive
zip -r archive.zip file1 file2 directory/

# Create zip with compression level (0-9, 9=max)
zip -r -9 archive.zip directory/

# Extract zip archive
unzip archive.zip

# Extract to specific directory
unzip archive.zip -d /target/directory/

# List zip contents
unzip -l archive.zip
```

---

## 🛠️ System Administration

### Process Management
```bash
# Find processes by name
ps aux | grep process_name
pgrep process_name

# Kill process by PID
kill PID
kill -9 PID  # Force kill

# Kill process by name
pkill process_name
killall process_name

# Monitor system resources
htop
top
iotop  # I/O monitoring
```

### Disk Usage & Management
```bash
# Check disk usage
df -h
du -sh /path/to/directory

# Find largest files/directories
du -sh * | sort -rh | head -10
find /path -type f -size +100M -exec ls -lh {} \;

# Check inode usage
df -i
```

---

## 🔍 Text Processing & Search

### Find & Grep
```bash
# Find files by name
find /path -name "*.txt"
find /path -iname "*.txt"  # Case insensitive

# Find and execute command
find /path -name "*.log" -exec rm {} \;

# Grep with context
grep -n "pattern" file.txt  # Show line numbers
grep -A 3 -B 3 "pattern" file.txt  # Show 3 lines after/before
grep -r "pattern" /directory/  # Recursive search
```

### Text Manipulation
```bash
# Replace text in files
sed 's/old_text/new_text/g' file.txt
sed -i 's/old_text/new_text/g' file.txt  # In-place editing

# Extract columns
cut -d',' -f1,3 file.csv  # Extract columns 1 and 3 from CSV
awk -F',' '{print $1, $3}' file.csv  # Same with awk
```

---

## 📚 Quick Reference

### Useful Aliases (add to ~/.bashrc)
```bash
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias h='history'
alias c='clear'
alias t='tree'
```

### Environment Variables
```bash
# View all environment variables
printenv
env

# Set temporary variable
export VAR_NAME="value"

# Add to PATH
export PATH="$PATH:/new/path"
```

---

*💡 **Tip**: Keep this file updated with new commands and techniques you discover!*

