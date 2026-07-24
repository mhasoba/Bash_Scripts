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
HOST_NAME="$(hostname -s 2>/dev/null || hostname || echo unknown-host)"
BACKUP_NAMESPACE="backups"
EXCLUDE_FILE="/home/mhasoba/Documents/Code_n_script/Bash/backup-excludes.txt"
MIN_INCREMENTAL_FREE_BYTES=$((5 * 1024 * 1024 * 1024))
DRY_RUN=false
SNAPSHOT_RETENTION_COUNT=14
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
Usage: $SCRIPT_NAME BackupDestinationPath LogFileDestinationPath [--dry-run] [--retain-count N] [--auto-unmount]

Description:
  Backs up $SOURCE_DIR to the specified destination with comprehensive logging.
  Only allows backup to mounted media/external devices for safety.

Arguments:
  BackupDestinationPath     Directory where backup will be stored (must be writable)
  LogFileDestinationPath    Directory where log file will be created (must be writable)

Options:
  -h, --help               Show this help message and exit
    --dry-run                Show what would change without writing backup data
    --retain-count N         Keep only the newest N completed snapshots (0 disables pruning)
  --auto-unmount          Automatically unmount the backup drive after completion

Examples:
  $SCRIPT_NAME /media/myBackup ~/bkplogs/
  $SCRIPT_NAME /mnt/external-drive /tmp/logs/ --auto-unmount

Safety Features:
  - Only allows backup to /mnt/*, /media/*, or /run/media/* destinations
    - Verifies the destination is an active mount point
    - Uses a lock to prevent concurrent backup runs
    - Stores versioned snapshots under a host-specific backup directory
    - Prunes old completed snapshots after successful backups
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

validate_file_readable() {
    local file_path="$1"
    local purpose="$2"

    if [[ ! -f "$file_path" ]]; then
        log_error "$purpose file '$file_path' does not exist"
        return 1
    fi

    if [[ ! -r "$file_path" ]]; then
        log_error "$purpose file '$file_path' is not readable"
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

validate_mounted_destination() {
    local dest="$1"

    if ! command -v findmnt &> /dev/null; then
        log_error "findmnt is not installed. Please install util-linux first."
        return 1
    fi

    if ! findmnt -rn --target "$dest" >/dev/null 2>&1; then
        log_error "Destination '$dest' is not an active mount point"
        return 1
    fi

    return 0
}

validate_snapshot_capable_filesystem() {
    local dest="$1"
    local fs_type=""

    if ! command -v findmnt &> /dev/null; then
        log_error "findmnt is not installed. Please install util-linux first."
        return 1
    fi

    fs_type="$(findmnt -n -o FSTYPE --target "$dest" 2>/dev/null || true)"

    case "$fs_type" in
        ext2|ext3|ext4|xfs|btrfs|zfs)
            return 0
            ;;
        "")
            log_error "Could not determine filesystem type for '$dest'"
            return 1
            ;;
        *)
            log_error "Destination filesystem '$fs_type' does not support the snapshot layout used by this backup script"
            log_error "Use a Linux filesystem such as ext4, xfs, btrfs, or zfs for the backup disk"
            return 1
            ;;
    esac
}

validate_non_negative_integer() {
    local value="$1"
    local purpose="$2"

    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        log_error "$purpose must be a non-negative integer"
        return 1
    fi

    return 0
}
# === END: Validation Functions ===

# === START: Snapshot Retention ===
prune_old_snapshots() {
    local snapshots_dir="$1"
    local keep_count="$2"
    local snapshot_path=""
    local snapshot_name=""
    local snapshots=()
    local prune_count=0
    local index=0

    if (( keep_count == 0 )); then
        log_to_file "Snapshot pruning disabled"
        return 0
    fi

    shopt -s nullglob
    for snapshot_path in "$snapshots_dir"/*; do
        [[ -d "$snapshot_path" ]] || continue
        snapshot_name="$(basename "$snapshot_path")"
        [[ "$snapshot_name" == .* ]] && continue
        snapshots+=("$snapshot_path")
    done
    shopt -u nullglob

    if (( ${#snapshots[@]} <= keep_count )); then
        log_to_file "Snapshot pruning not needed (have ${#snapshots[@]}, keep $keep_count)"
        return 0
    fi

    prune_count=$((${#snapshots[@]} - keep_count))
    log_to_file "Pruning $prune_count old snapshot(s); keeping newest $keep_count"

    for (( index=0; index<prune_count; index++ )); do
        snapshot_path="${snapshots[$index]}"
        snapshot_name="$(basename "$snapshot_path")"
        rm -rf "$snapshot_path"
        log_to_file "Pruned snapshot: $snapshot_name"
    done

    return 0
}
# === END: Snapshot Retention ===

# === START: Cleanup Function ===
cleanup() {
    local exit_code=$?

    if [[ -n "${temp_snapshot_dir:-}" && -d "$temp_snapshot_dir" && ( "$DRY_RUN" == true || $exit_code -eq 0 ) ]]; then
        rm -rf "$temp_snapshot_dir"
    fi

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
backup_data_root=""
snapshot_root=""
latest_link=""
latest_snapshot=""
run_snapshot_name=""
temp_snapshot_dir=""
rsync_target=""

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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --retain-count)
            if [[ $# -lt 2 ]]; then
                log_error "--retain-count requires a value"
                exit 1
            fi
            SNAPSHOT_RETENTION_COUNT="$2"
            shift 2
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
validate_non_negative_integer "$SNAPSHOT_RETENTION_COUNT" "Snapshot retention count" || exit 1
validate_destination "$backup_dest" || exit 1
validate_mounted_destination "$backup_dest" || exit 1
validate_snapshot_capable_filesystem "$backup_dest" || exit 1
validate_directory "$backup_dest" "Backup destination" || exit 1
validate_directory "$log_dest" "Log destination" || exit 1
validate_file_readable "$EXCLUDE_FILE" "Exclude list" || exit 1

backup_data_root="$backup_dest/$BACKUP_NAMESPACE/$HOST_NAME/home"
snapshot_root="$backup_data_root/snapshots"
latest_link="$backup_data_root/latest"
run_snapshot_name="$(date '+%Y%m%d_%H%M%S')"

if ! mkdir -p "$snapshot_root"; then
    log_error "Cannot create snapshot directory: $snapshot_root"
    exit 1
fi

if [[ -L "$latest_link" || -d "$latest_link" ]]; then
    latest_snapshot="$(readlink -f "$latest_link" 2>/dev/null || true)"
fi

if [[ "$DRY_RUN" == true ]]; then
    temp_snapshot_dir="$(mktemp -d "${TMPDIR:-/tmp}/backup-dry-run.XXXXXX")"
    rsync_target="$temp_snapshot_dir"
else
    temp_snapshot_dir="$snapshot_root/.incomplete-current"
    rsync_target="$temp_snapshot_dir"

    if ! mkdir -p "$rsync_target"; then
        log_error "Cannot create staging snapshot directory: $rsync_target"
        exit 1
    fi
fi
# === END: Argument Validation ===

# === START: Dependency Check ===
if ! command -v rsync &> /dev/null; then
    log_error "rsync is not installed. Please install it first."
    exit 1
fi

if ! command -v flock &> /dev/null; then
    log_error "flock is not installed. Please install util-linux first."
    exit 1
fi

if ! command -v findmnt &> /dev/null; then
    log_error "findmnt is not installed. Please install util-linux first."
    exit 1
fi
# === END: Dependency Check ===

# === START: Single-run Lock ===
lock_file="$log_dest/${SCRIPT_NAME}.lock"
exec 9>"$lock_file"

if ! flock -n 9; then
    log_error "Another backup instance is already running"
    exit 1
fi
# === END: Single-run Lock ===

# === START: Log File Setup ===
logpath="$log_dest/${LOG_PREFIX}-$(date "$DATE_FORMAT").log"

# Check if we can create the log file
if ! touch "$logpath" 2>/dev/null; then
    log_error "Cannot create log file: $logpath"
    exit 1
fi

log_info "Log file: $logpath"
log_info "Auto-unmount: $AUTO_UNMOUNT"
log_info "Dry run: $DRY_RUN"
> "$logpath"  # Clear the log file

# Write initial log entries
log_to_file "=== BACKUP SESSION STARTED ==="
log_to_file "Backup started at: $(date '+%Y-%m-%d, %T, %A')"
log_to_file "Backup source: $SOURCE_DIR"
log_to_file "Backup mount point: $backup_dest"
log_to_file "Backup root: $backup_data_root"
log_to_file "Snapshot root: $snapshot_root"
log_to_file "Current snapshot: $run_snapshot_name"
log_to_file "Dry run: $DRY_RUN"
log_to_file "Snapshot retention count: $SNAPSHOT_RETENTION_COUNT"
log_to_file "Log file: $logpath"
log_to_file "Auto-unmount: $AUTO_UNMOUNT"
log_to_file ""
# === END: Log File Setup ===

# === START: Pre-backup Information ===
log_info "Gathering system information..."

log_to_file "=== SYSTEM INFORMATION ==="
if command -v df &> /dev/null; then
    source_size=$(du -sh "$SOURCE_DIR" 2>/dev/null | awk '{print $1}' || echo "Unknown")
    source_size_bytes=$(du -sb "$SOURCE_DIR" 2>/dev/null | awk '{print $1}' || echo 0)
    dest_info=$(df -h "$backup_dest" 2>/dev/null | awk 'NR==2 {print $2, $3, $4, $5}' || echo "Unknown Unknown Unknown Unknown")
    dest_available_bytes=$(df -B1 "$backup_dest" 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)
    read -r dest_total dest_used dest_available dest_percent <<< "$dest_info"
    
    log_to_file "Source directory size: $source_size"
    log_to_file "Destination total space: ${dest_total:-Unknown}"
    log_to_file "Destination used space: ${dest_used:-Unknown} (${dest_percent:-Unknown})"
    log_to_file "Destination available space: ${dest_available:-Unknown}"
    log_to_file "Destination available bytes: ${dest_available_bytes:-0}"

    if [[ -n "$latest_snapshot" && ! -d "$latest_snapshot" ]]; then
        latest_snapshot=""
    fi

    if [[ -z "$latest_snapshot" ]]; then
        if (( dest_available_bytes < source_size_bytes )); then
            log_error "Insufficient free space for the initial snapshot"
            log_to_file "Required bytes for initial snapshot: $source_size_bytes"
            exit 1
        fi
    elif (( dest_available_bytes < MIN_INCREMENTAL_FREE_BYTES )); then
        log_error "Insufficient free space for an incremental snapshot"
        log_to_file "Minimum incremental free-space threshold: $MIN_INCREMENTAL_FREE_BYTES"
        exit 1
    fi
else
    log_to_file "df command not available - skipping disk space analysis"
fi

log_to_file ""
# === END: Pre-backup Information ===

# === START: Backup Process ===
log_info "Starting backup process..."
log_to_file "=== BACKUP PROCESS ==="
[[ -n "$latest_snapshot" ]] && log_to_file "Using link-dest base: $latest_snapshot"
log_to_file "Rsync target: $rsync_target"

START=$(date +%s)

# Rsync with comprehensive options
rsync_exit_code=0
rsync_args=(
      -aAX
    --human-readable
    --info=progress2
    --no-inc-recursive
    --delete
    --delete-excluded
    --partial
    --partial-dir=.rsync-partial
    --log-file="$logpath"
    --iconv=utf8,utf8
      --exclude-from="$EXCLUDE_FILE"
)

if [[ "$DRY_RUN" == true ]]; then
    rsync_args+=(--dry-run)
fi

if [[ -n "$latest_snapshot" ]]; then
    rsync_args+=(--link-dest="$latest_snapshot")
fi

rsync_args+=("$SOURCE_DIR/" "$rsync_target/")

rsync "${rsync_args[@]}" || rsync_exit_code=$?

FINISH=$(date +%s)
DURATION=$((FINISH - START))
HOURS=$((DURATION / 3600))
MINUTES=$(((DURATION % 3600) / 60))
SECONDS=$((DURATION % 60))

log_to_file ""
log_to_file "=== BACKUP COMPLETED ==="
# === END: Backup Process ===

# === START: Summary ===
summary_file="$log_dest/Backup_Summary_$(date '+%Y%m%d_%H%M%S').txt"
final_snapshot_dir="$snapshot_root/$run_snapshot_name"
final_exit_code=$rsync_exit_code

if [[ $rsync_exit_code -eq 0 ]]; then
    log_info "Backup completed successfully!"
    log_to_file "Status: SUCCESS"
    echo "✓ Backup completed successfully!" > "$summary_file"
    backup_success=true
elif [[ $rsync_exit_code -eq 24 ]]; then
    log_info "Backup completed with warnings (some files vanished during transfer)"
    log_to_file "Status: SUCCESS WITH WARNINGS (rsync exit code 24)"
    echo "⚠ Backup completed with warnings (rsync exit code 24)" > "$summary_file"
    backup_success=true
    final_exit_code=0
else
    log_error "Backup completed with errors (exit code: $rsync_exit_code)"
    log_to_file "Status: COMPLETED WITH ERRORS (exit code: $rsync_exit_code)"
    echo "⚠ Backup completed with errors (exit code: $rsync_exit_code)" > "$summary_file"
    backup_success=false
fi

if [[ "$DRY_RUN" == false && "$backup_success" == true ]]; then
    rm -rf "$final_snapshot_dir"
    mv "$temp_snapshot_dir" "$final_snapshot_dir"
    ln -sfn "$final_snapshot_dir" "$latest_link"
    log_to_file "Snapshot finalized at: $final_snapshot_dir"
    prune_old_snapshots "$snapshot_root" "$SNAPSHOT_RETENTION_COUNT"
elif [[ "$DRY_RUN" == true ]]; then
    log_to_file "Dry run completed; no snapshot written"
else
    log_to_file "Snapshot staging directory preserved for retry: $temp_snapshot_dir"
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
    echo "Mount point: $backup_dest"
    echo "Backup root: $backup_data_root"
    echo "Snapshot root: $snapshot_root"
    echo "Snapshot name: $run_snapshot_name"
    echo "Dry run: $DRY_RUN"
    echo "Snapshot retention count: $SNAPSHOT_RETENTION_COUNT"
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

exit $final_exit_code
# === END: Summary ===