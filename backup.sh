#!/bin/bash

# Backup script for home directory
# Author: Samraat Pawar (mhasoba)
# Version: 2.1 - Added auto-unmount functionality

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# === START: Configuration ===
SOURCE_DIR="/home/mhasoba"
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="rsync"
DATE_FORMAT="+%F-%H%M"
AUTO_UNMOUNT=false  # Default: don't auto-unmount
# === END: Configuration ===

# === START: Logging Functions ===
log_info() {
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_to_file() {
    echo "$1" | tee -a "$logpath"
}
# === END: Logging Functions ===

# === START: Show Help Function ===
show_help() {
cat << EOF
Usage: $SCRIPT_NAME BackupDestinationPath LogFileDestinationPath [--auto-unmount]

Description:
  Backs up $SOURCE_DIR to the specified destination with comprehensive logging.
  Only allows backup to mounted media/external devices for safety.

Arguments:
  BackupDestinationPath     Directory where backup will be stored (must be writable)
  LogFileDestinationPath    Directory where log file will be created (must be writable)

Options:
  -h, --help               Show this help message and exit
  --auto-unmount          Automatically unmount the backup drive after completion

Examples:
  $SCRIPT_NAME /media/myBackup ~/bkplogs/
  $SCRIPT_NAME /mnt/external-drive /tmp/logs/ --auto-unmount

Safety Features:
  - Only allows backup to /mnt/*, /media/*, or /run/media/* destinations
  - Validates all paths before execution  
  - Creates timestamped log files
  - Handles interruptions gracefully
  - Provides detailed progress and summary information
  - Optional auto-unmount after successful backup

EOF
}
# === END: Show Help Function ===

# === START: Unmount Function ===
safely_unmount() {
    local mount_point="$1"
    local device_path=""
    
    # Find the device associated with the mount point
    device_path=$(findmnt -n -o SOURCE "$mount_point" 2>/dev/null || echo "")
    
    if [[ -z "$device_path" ]]; then
        log_error "Cannot determine device for mount point: $mount_point"
        return 1
    fi
    
    log_info "Attempting to unmount $device_path from $mount_point"
    log_to_file "Unmounting backup drive: $device_path"
    
    # Sync to ensure all data is written
    sync
    sleep 2
    
    # Try to unmount
    if umount "$mount_point" 2>/dev/null; then
        log_info "Successfully unmounted $mount_point"
        log_to_file "Drive unmounted successfully"
        
        # Optional: Show notification
        if command -v notify-send &> /dev/null; then
            notify-send "Backup Complete" "Drive unmounted safely. You can now remove the device."
        fi
        
        return 0
    else
        log_error "Failed to unmount $mount_point - device may be busy"
        log_to_file "WARNING: Failed to unmount drive - please unmount manually"
        
        # Show what processes might be using the mount point
        if command -v lsof &> /dev/null; then
            log_info "Processes using the mount point:"
            lsof +D "$mount_point" 2>/dev/null | head -10 || true
        fi
        
        return 1
    fi
}
# === END: Unmount Function ===

# === START: Validation Functions ===
validate_directory() {
    local dir="$1"
    local purpose="$2"
    
    if [[ ! -d "$dir" ]]; then
        log_error "$purpose directory '$dir' does not exist"
        return 1
    fi
    
    if [[ ! -r "$dir" ]]; then
        log_error "$purpose directory '$dir' is not readable"
        return 1
    fi
    
    if [[ ! -w "$dir" ]]; then
        log_error "$purpose directory '$dir' is not writable"
        return 1
    fi
    
    return 0
}

validate_source() {
    if [[ ! -d "$SOURCE_DIR" ]]; then
        log_error "Source directory '$SOURCE_DIR' does not exist"
        return 1
    fi
    
    if [[ ! -r "$SOURCE_DIR" ]]; then
        log_error "Source directory '$SOURCE_DIR' is not readable"
        return 1
    fi
    
    return 0
}

validate_destination() {
    local dest="$1"
    
    case "$dest" in
        "/mnt"|"/mnt/"*|"/media"|"/media/"*|"/run/media"|"/run/media/"*)
            return 0
            ;;
        *)
            log_error "Destination '$dest' not allowed. Only /mnt/*, /media/*, or /run/media/* are permitted for safety."
            return 1
            ;;
    esac
}
# === END: Validation Functions ===

# === START: Cleanup Function ===
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script interrupted or failed with exit code $exit_code"
        if [[ -n "${logpath:-}" ]]; then
            echo "Backup interrupted at: $(date '+%Y-%m-%d, %T, %A')" >> "$logpath"
        fi
    fi
    exit $exit_code
}

trap cleanup EXIT INT TERM
# === END: Cleanup Function ===

# === START: Argument Validation ===
# Parse arguments
backup_dest=""
log_dest=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --auto-unmount)
            AUTO_UNMOUNT=true
            shift
            ;;
        *)
            if [[ -z "$backup_dest" ]]; then
                backup_dest="$1"
            elif [[ -z "$log_dest" ]]; then
                log_dest="$1"
            else
                log_error "Too many arguments"
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$backup_dest" || -z "$log_dest" ]]; then
    log_error "Invalid number of arguments. Expected 2, got fewer"
    echo "Usage: $SCRIPT_NAME BackupDestinationPath LogFileDestinationPath [--auto-unmount]" >&2
    echo "Use '$SCRIPT_NAME --help' for more information." >&2
    exit 1
fi

# Validate all paths
validate_source || exit 1
validate_directory "$backup_dest" "Backup destination" || exit 1
validate_directory "$log_dest" "Log destination" || exit 1
validate_destination "$backup_dest" || exit 1
# === END: Argument Validation ===

# === START: Dependency Check ===
if ! command -v rsync &> /dev/null; then
    log_error "rsync is not installed. Please install it first."
    exit 1
fi
# === END: Dependency Check ===

# === START: Log File Setup ===
logpath="$log_dest/${LOG_PREFIX}-$(date "$DATE_FORMAT").log"

# Check if we can create the log file
if ! touch "$logpath" 2>/dev/null; then
    log_error "Cannot create log file: $logpath"
    exit 1
fi

log_info "Log file: $logpath"
log_info "Auto-unmount: $AUTO_UNMOUNT"
> "$logpath"  # Clear the log file

# Write initial log entries
log_to_file "=== BACKUP SESSION STARTED ==="
log_to_file "Backup started at: $(date '+%Y-%m-%d, %T, %A')"
log_to_file "Backup source: $SOURCE_DIR"
log_to_file "Backup destination: $backup_dest"
log_to_file "Log file: $logpath"
log_to_file "Auto-unmount: $AUTO_UNMOUNT"
log_to_file ""
# === END: Log File Setup ===

# === START: Pre-backup Information ===
log_info "Gathering system information..."

log_to_file "=== SYSTEM INFORMATION ==="
if command -v df &> /dev/null; then
    source_size=$(du -sh "$SOURCE_DIR" 2>/dev/null | awk '{print $1}' || echo "Unknown")
    dest_info=$(df -h "$backup_dest" 2>/dev/null | awk 'NR==2 {print $2, $3, $4, $5}' || echo "Unknown Unknown Unknown Unknown")
    read -r dest_total dest_used dest_available dest_percent <<< "$dest_info"
    
    log_to_file "Source directory size: $source_size"
    log_to_file "Destination total space: ${dest_total:-Unknown}"
    log_to_file "Destination used space: ${dest_used:-Unknown} (${dest_percent:-Unknown})"
    log_to_file "Destination available space: ${dest_available:-Unknown}"
else
    log_to_file "df command not available - skipping disk space analysis"
fi

log_to_file ""
# === END: Pre-backup Information ===

# === START: Backup Process ===
log_info "Starting backup process..."
log_to_file "=== BACKUP PROCESS ==="

START=$(date +%s)

# Rsync with comprehensive options
rsync_exit_code=0
rsync -aAX \
      --human-readable \
      --info=progress2 \
      --no-inc-recursive \
      --delete \
      --delete-excluded \
      --log-file="$logpath" \
      --iconv=utf8,utf8 \
      --exclude={'/dev/*','/proc/*','/sys/*','/tmp/*','/run/*','/mnt/*','/media/*','/lost+found','.cache/google-chrome/*','.cache/mozilla/*','.cache/chromium/*','julia*/*','*.tmp','*.swp'} \
      "$SOURCE_DIR/" "$backup_dest/" || rsync_exit_code=$?

FINISH=$(date +%s)
DURATION=$((FINISH - START))
HOURS=$((DURATION / 3600))
MINUTES=$(((DURATION % 3600) / 60))
SECONDS=$((DURATION % 60))

log_to_file ""
log_to_file "=== BACKUP COMPLETED ==="
# === END: Backup Process ===

# === START: Summary ===
summary_file="$backup_dest/Backup_Summary_$(date '+%Y%m%d_%H%M%S').txt"

if [[ $rsync_exit_code -eq 0 ]]; then
    log_info "Backup completed successfully!"
    log_to_file "Status: SUCCESS"
    echo "✓ Backup completed successfully!" > "$summary_file"
    backup_success=true
else
    log_error "Backup completed with errors (exit code: $rsync_exit_code)"
    log_to_file "Status: COMPLETED WITH ERRORS (exit code: $rsync_exit_code)"
    echo "⚠ Backup completed with errors (exit code: $rsync_exit_code)" > "$summary_file"
    backup_success=false
fi

duration_text=""
[[ $HOURS -gt 0 ]] && duration_text="${HOURS}h "
[[ $MINUTES -gt 0 ]] && duration_text="${duration_text}${MINUTES}m "
duration_text="${duration_text}${SECONDS}s"

log_to_file "Total duration: $duration_text"
log_to_file "Backup completed at: $(date '+%Y-%m-%d, %T, %A')"
log_to_file "Log saved to: $logpath"

# Write summary file
{
    echo "Backup Summary"
    echo "=============="
    echo "Date: $(date '+%Y-%m-%d, %T, %A')"
    echo "Source: $SOURCE_DIR"
    echo "Destination: $backup_dest"
    echo "Duration: $duration_text"
    echo "Log file: $logpath"
    echo ""
    echo "For detailed information, see the log file."
} >> "$summary_file"

log_info "Summary saved to: $summary_file"
log_info "Total backup time: $duration_text"

# === START: Auto-unmount ===
if [[ "$AUTO_UNMOUNT" == true && "$backup_success" == true ]]; then
    log_info "Auto-unmount enabled - attempting to unmount backup drive..."
    log_to_file ""
    log_to_file "=== AUTO-UNMOUNT ==="
    
    # Wait a bit to ensure all file operations are complete
    sleep 3
    
    if safely_unmount "$backup_dest"; then
        log_to_file "Drive unmounted successfully"
    else
        log_to_file "Failed to auto-unmount - manual unmount required"
    fi
elif [[ "$AUTO_UNMOUNT" == true && "$backup_success" == false ]]; then
    log_info "Backup had errors - skipping auto-unmount for safety"
    log_to_file "Auto-unmount skipped due to backup errors"
fi
# === END: Auto-unmount ===

exit $rsync_exit_code
# === END: Summary ===