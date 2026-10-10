#!/bin/bash

# Backup script for home directory
# Author: Samraat Pawar (mhasoba)
# Version: 2.1 - Added auto-unmount functionality

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# === START: Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SOURCE_DIR:-${HOME:-/home/mhasoba}}"
SCRIPT_NAME="$(basename "$0")"
LOG_PREFIX="rsync"
DATE_FORMAT="+%F-%H%M"
AUTO_UNMOUNT=false  # Default: don't auto-unmount
HOST_NAME="$(hostname -s 2>/dev/null || hostname || echo unknown-host)"
BACKUP_NAMESPACE="backups"
EXCLUDE_FILE="${EXCLUDE_FILE:-$SCRIPT_DIR/backup-excludes.txt}"
MIN_INCREMENTAL_FREE_BYTES=$((5 * 1024 * 1024 * 1024))
DRY_RUN=false
SNAPSHOT_RETENTION_COUNT=14
EXPORT_SYSTEM_STATE=true
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
Usage: $SCRIPT_NAME BackupDestinationPath LogFileDestinationPath [--dry-run] [--retain-count N] [--auto-unmount] [--no-state-export]

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
        --no-state-export       Skip machine-state export files (package lists/settings)

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
    
    # Try to unmount, retrying and nudging file managers that may be
    # holding the mount point open (e.g. Nautilus browsing the folder)
    local attempt
    for attempt in 1 2 3; do
        if umount "$mount_point" 2>/dev/null; then
            log_info "Successfully unmounted $mount_point"
            log_to_file "Drive unmounted successfully"

            if command -v notify-send &> /dev/null; then
                notify-send "Backup Complete" "Drive unmounted safely. You can now remove the device."
            fi

            return 0
        fi

        if [[ $attempt -lt 3 ]] && command -v fuser &> /dev/null; then
            # Ask file-manager style processes (nautilus/nemo/dolphin/thunar/pcmanfm)
            # holding the mount point to release it; they just re-open a new
            # window on next launch, so this is safe and non-destructive.
            local holder_pids
            holder_pids=$(fuser -m "$mount_point" 2>/dev/null || true)
            for pid in $holder_pids; do
                local pcomm
                pcomm=$(ps -o comm= -p "$pid" 2>/dev/null || echo "")
                if [[ "$pcomm" =~ ^(nautilus|nemo|dolphin|thunar|pcmanfm|caja)$ ]]; then
                    log_info "Closing $pcomm (PID $pid) which is holding $mount_point open"
                    kill "$pid" 2>/dev/null || true
                fi
            done
            sleep 1
        fi
    done

    log_error "Failed to unmount $mount_point - device may be busy"
    log_to_file "WARNING: Failed to unmount drive - please unmount manually"

    # Show what processes might be using the mount point
    if command -v lsof &> /dev/null; then
        log_info "Processes using the mount point:"
        lsof +D "$mount_point" 2>/dev/null | head -10 || true
    fi

    return 1
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
    local mount_point=""
    local device_path=""
    local root_device=""

    mount_point="$(findmnt -rn -o TARGET --target "$dest" 2>/dev/null)" || return 1
    case "$mount_point" in
        /mnt|/mnt/*|/media|/media/*|/run/media|/run/media/*) ;;
        *)
            log_error "Destination '$dest' is not on an approved backup mount"
            return 1
            ;;
    esac

    device_path="$(findmnt -rn -o SOURCE --target "$dest" 2>/dev/null)" || return 1
    root_device="$(findmnt -rn -o SOURCE --target / 2>/dev/null)" || return 1
    if [[ "$device_path" != /dev/* || "${device_path%%\[*}" == "${root_device%%\[*}" ]]; then
        log_error "Destination '$dest' must be on a separate mounted backup device"
        return 1
    fi

    return 0
}

validate_snapshot_capable_filesystem() {
    local dest="$1"
    local fs_type=""

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

# === START: Restore State Export ===
running_ai_apps() {
    ps -u "$(id -u)" -o comm= |
        awk '$1 ~ /^(code|code-insiders|codex|codex-cli)$/ { print $1 }' |
        sort -u
}

export_state_command() {
    local export_root="$1"
    local output_name="$2"
    shift 2

    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'UNAVAILABLE: %s\n' "$1" >> "$export_root/export-status.txt"
    elif "$@" > "$export_root/$output_name" 2>> "$export_root/export-errors.log"; then
        printf 'OK: %s\n' "$output_name" >> "$export_root/export-status.txt"
    else
        printf 'WARNING: %s failed; output may be incomplete\n' "$output_name" >> "$export_root/export-status.txt"
    fi
}

export_system_state() (
    local export_root="$1"
    local config_path=""

    umask 077
    mkdir -p "$export_root" || return 1
    chmod 700 "$export_root" || return 1
    mkdir -p "$export_root/etc" || return 1
    : > "$export_root/export-status.txt" || return 1
    : > "$export_root/export-errors.log" || return 1

    {
        echo "generated_at=$(date '+%Y-%m-%dT%H:%M:%S%z')"
        echo "host=$HOST_NAME"
        echo "user=${USER:-unknown}"
        echo "uid=$(id -u)"
        echo "gid=$(id -g)"
        echo "source_dir=$SOURCE_DIR"
    } > "$export_root/metadata.txt" || return 1

    export_state_command "$export_root" dpkg-package-versions.tsv dpkg-query -W -f='${binary:Package}\t${Version}\n' || return 1
    export_state_command "$export_root" apt-manual-packages.txt apt-mark showmanual || return 1
    export_state_command "$export_root" snap-list.txt snap list || return 1
    export_state_command "$export_root" flatpak-apps.txt flatpak list --app --columns=application || return 1
    export_state_command "$export_root" flatpak-remotes.txt flatpak remotes --show-details || return 1
    export_state_command "$export_root" systemd-user-enabled-units.txt systemctl --user list-unit-files --state=enabled || return 1
    export_state_command "$export_root" user-crontab.txt crontab -l || return 1
    export_state_command "$export_root" dconf-settings.ini dconf dump / || return 1
    export_state_command "$export_root" vscode-extensions.txt code --list-extensions --show-versions || return 1
    export_state_command "$export_root" running-ai-apps.txt running_ai_apps || return 1
    if [[ -s "$export_root/running-ai-apps.txt" ]]; then
        printf 'WARNING: VS Code/Codex processes detected; live databases may be inconsistent\n' >> "$export_root/export-status.txt" || return 1
    fi

    cp "$EXCLUDE_FILE" "$export_root/backup-excludes.txt" || return 1
    cp /etc/os-release "$export_root/os-release" || return 1
    for config_path in .inputrc .bashrc .bash_profile .profile .bash_aliases .bash_history .zshrc .zsh_history .tmux.conf .config .local/share .local/bin bin .gitconfig .ssh .gnupg .codex; do
        if [[ -e "$SOURCE_DIR/$config_path" || -L "$SOURCE_DIR/$config_path" ]]; then
            printf 'PRESENT: %s\n' "$config_path"
        else
            printf 'ABSENT: %s\n' "$config_path"
        fi
    done > "$export_root/home-config-inventory.txt" || return 1

    for etc_file in /etc/fstab /etc/hostname /etc/hosts /etc/default/grub /etc/apt/sources.list; do
        if [[ -r "$etc_file" ]]; then
            cp -a "$etc_file" "$export_root/etc/" 2>> "$export_root/export-errors.log" ||
                printf 'WARNING: could not copy %s\n' "$etc_file" >> "$export_root/export-status.txt" || return 1
        fi
    done

    if [[ -d /etc/apt/sources.list.d ]]; then
        mkdir -p "$export_root/etc/apt" || return 1
        cp -a /etc/apt/sources.list.d "$export_root/etc/apt/" 2>> "$export_root/export-errors.log" ||
            printf 'WARNING: could not copy APT sources\n' >> "$export_root/export-status.txt" || return 1
    fi

    cat > "$export_root/RESTORE.txt" <<'EOF'
Ubuntu migration checklist
==========================
This bundle accompanies the home snapshot with the same timestamp.
Check export-status.txt and export-errors.log for unavailable or failed exports.
home-config-inventory.txt records source presence, not successful copying.
Check backup-excludes.txt and the rsync log for excluded or unreadable files.

Restore documents first, then selected shell dotfiles, .config, .local/share,
.local/bin, bin, and .gitconfig. Close applications before restoring settings.
Preview home copies with rsync --dry-run; avoid --delete unless intentional.
Restore .ssh and .gnupg securely, keeping restrictive permissions and ownership
appropriate for the new account. Shell history and application profiles can
contain secrets too. Store the backup on encrypted storage; this script does
not encrypt it. A compressed tarball alone would not provide encryption.

VS Code, Copilot, and Codex migration
-----------------------------------
Restore selected VS Code User settings, keybindings, snippets, and profiles
first. Review vscode-extensions.txt and reinstall compatible extensions using
their IDs (the text before @), rather than copying old extension binaries.
The inventory covers the default profile of the current user's code CLI;
export other profiles or remote editor environments separately if needed.
Sign in to GitHub/OpenAI again instead of blindly restoring authentication.
The default exclusions omit .codex/auth.json, caches, temporary IPC/lock files,
and .vscode/extensions. Configuration, rules, skills, sessions, and database
files (including SQLite WAL/SHM files) remain eligible for the home backup.
Other retained settings and histories can contain credentials and private code.
Older snapshots may still contain authentication and previously excluded data.

Check running-ai-apps.txt and the backup log for live-database warnings.
Process detection is best effort, not a guarantee that applications are closed.
Close VS Code and Codex before a migration backup and before restoring history
or databases. rsync does not create a transaction-consistent live database copy.
Prefer selective restoration over replacing the entire editor profile.

Review apt-manual-packages.txt for packages available on the new Ubuntu release.
After configuring compatible repositories, selected packages can be installed
with: sudo xargs -r -a apt-manual-packages.txt apt-get install
snap-list.txt is an inventory, not a directly executable installation list.
Review Flatpak remotes and reinstall selected apps from flatpak-apps.txt.

Optionally restore GNOME preferences in the new user's desktop session:
  dconf dump / > dconf-before-restore.ini
  dconf load / < dconf-settings.ini
This overwrites preferences; review release and extension compatibility first.
Review user-crontab.txt before installing with crontab user-crontab.txt.
Re-enable selected user services after updating machine-specific script paths.
Use etc/ files as references; do not overwrite fstab, hostname, or APT sources
wholesale on a new installation. This is not a full operating-system image.
EOF
    [[ -s "$export_root/RESTORE.txt" ]] || return 1
    return 0
)

save_restore_state() {
    local export_root="$1"
    local state_root="$2"
    local snapshot_name="$3"
    local staging_dir="$state_root/.incomplete-current"

    [[ ! -e "$state_root/$snapshot_name" ]] || return 1
    mkdir -p "$state_root" || return 1
    rm -rf "$staging_dir" || return 1
    mkdir -m 700 "$staging_dir" || return 1
    cp -a "$export_root/." "$staging_dir/" || return 1
    mv "$staging_dir" "$state_root/$snapshot_name" || return 1
}
# === END: Restore State Export ===

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
        rm -rf "$(dirname "$snapshots_dir")/state/$snapshot_name"
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
    if [[ -n "${restore_state_dir:-}" && -d "$restore_state_dir" ]]; then
        rm -rf "$restore_state_dir"
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
restore_state_dir=""

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
        --no-state-export)
            EXPORT_SYSTEM_STATE=false
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

for dependency in rsync flock findmnt; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        log_error "Required command not installed: $dependency"
        exit 1
    fi
done

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

if [[ -L "$latest_link" || -d "$latest_link" ]]; then
    latest_snapshot="$(readlink -f "$latest_link" 2>/dev/null || true)"
fi

# === END: Argument Validation ===

# === START: Single-run Lock ===
lock_file="$log_dest/${SCRIPT_NAME}.lock"
exec 9>"$lock_file"

if ! flock -n 9; then
    log_error "Another backup instance is already running"
    exit 1
fi
# === END: Single-run Lock ===

if [[ "$DRY_RUN" == true ]]; then
    temp_snapshot_dir="$(mktemp -d "${TMPDIR:-/tmp}/backup-dry-run.XXXXXX")"
else
    temp_snapshot_dir="$snapshot_root/.incomplete-current"
    if ! mkdir -p "$temp_snapshot_dir"; then
        log_error "Cannot create staging snapshot directory: $temp_snapshot_dir"
        exit 1
    fi
fi
rsync_target="$temp_snapshot_dir"

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
log_to_file "Backup destination: $backup_dest"
log_to_file "Backup root: $backup_data_root"
log_to_file "Snapshot root: $snapshot_root"
log_to_file "Current snapshot: $run_snapshot_name"
log_to_file "Dry run: $DRY_RUN"
log_to_file "Snapshot retention count: $SNAPSHOT_RETENTION_COUNT"
log_to_file "Machine-state export: $EXPORT_SYSTEM_STATE"
log_to_file "Log file: $logpath"
log_to_file "Auto-unmount: $AUTO_UNMOUNT"
log_to_file ""
# === END: Log File Setup ===

if active_ai_apps="$(running_ai_apps)"; then
    if [[ -n "$active_ai_apps" ]]; then
        log_info "WARNING: VS Code/Codex is running; close applications for a consistent migration backup"
        log_to_file "WARNING: Live editor/AI databases may be inconsistent. Active processes: $(printf '%s' "$active_ai_apps" | paste -sd ',' -)"
    fi
else
    log_to_file "WARNING: Unable to check VS Code/Codex processes; database consistency is unverified"
fi

if [[ "$EXPORT_SYSTEM_STATE" == true && "$DRY_RUN" == false ]]; then
    restore_state_dir="$(mktemp -d "${TMPDIR:-/tmp}/backup-state.XXXXXX")"
    if export_system_state "$restore_state_dir"; then
        log_to_file "Restore state exported to: $restore_state_dir"
    else
        log_to_file "ERROR: Failed to write restore state bundle; backup not started"
        exit 1
    fi
elif [[ "$DRY_RUN" == true ]]; then
    log_to_file "Dry run: skipping machine-state export"
fi

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

    if [[ "$DRY_RUN" == true ]]; then
        log_to_file "Dry run mode: skipping strict free-space enforcement checks"
    else
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

unreadable_files="$(grep -oP '^\S+ \S+ \[\d+\] rsync: \[sender\] read errors mapping "\K[^"]+' "$logpath" 2>/dev/null | sort -u || true)"
unreadable_count=0
[[ -n "$unreadable_files" ]] && unreadable_count=$(printf '%s\n' "$unreadable_files" | wc -l)

if [[ $rsync_exit_code -eq 0 ]]; then
    log_info "Backup completed successfully!"
    log_to_file "Status: SUCCESS"
    echo "✓ Backup completed successfully!" > "$summary_file"
    backup_success=true
elif [[ $rsync_exit_code -eq 23 || $rsync_exit_code -eq 24 ]]; then
    # 23/24 mean some files were skipped (unreadable or vanished); the rest of the
    # tree is still consistent, so the snapshot is kept rather than discarded.
    log_info "Backup completed with warnings (rsync exit code: $rsync_exit_code)"
    log_to_file "Status: SUCCESS WITH WARNINGS (rsync exit code $rsync_exit_code)"
    echo "⚠ Backup completed with warnings (rsync exit code $rsync_exit_code)" > "$summary_file"
    backup_success=true
    final_exit_code=0
else
    log_error "Backup completed with errors (exit code: $rsync_exit_code)"
    log_to_file "Status: COMPLETED WITH ERRORS (exit code: $rsync_exit_code)"
    echo "⚠ Backup completed with errors (exit code: $rsync_exit_code)" > "$summary_file"
    backup_success=false
fi

if (( unreadable_count > 0 )); then
    log_error "$unreadable_count source file(s) could not be read - possible disk damage"
    log_to_file ""
    log_to_file "=== UNREADABLE SOURCE FILES ($unreadable_count) ==="
    log_to_file "$unreadable_files"
    log_to_file "These files are NOT in the backup. Check source disk health."

    if command -v notify-send &> /dev/null; then
        notify-send -u critical "Backup warning" \
            "$unreadable_count source file(s) unreadable. Check source disk health."
    fi
fi

if [[ "$DRY_RUN" == false && "$backup_success" == true ]]; then
    if [[ "$EXPORT_SYSTEM_STATE" == true ]]; then
        if ! save_restore_state "$restore_state_dir" "$backup_data_root/state" "$run_snapshot_name"; then
            log_to_file "ERROR: Could not save restore state on backup disk; snapshot not finalized"
            exit 1
        fi
        log_to_file "Restore state saved to: $backup_data_root/state/$run_snapshot_name"
    fi
    rm -rf "$final_snapshot_dir"
    mv "$temp_snapshot_dir" "$final_snapshot_dir"
    ln -sfn "snapshots/$run_snapshot_name" "$latest_link"
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
    echo "Backup destination: $backup_dest"
    echo "Backup root: $backup_data_root"
    echo "Snapshot root: $snapshot_root"
    echo "Snapshot name: $run_snapshot_name"
    if [[ "$EXPORT_SYSTEM_STATE" == true && "$DRY_RUN" == false && "$backup_success" == true ]]; then
        echo "Restore state: $backup_data_root/state/$run_snapshot_name"
    fi
    echo "Dry run: $DRY_RUN"
    echo "Snapshot retention count: $SNAPSHOT_RETENTION_COUNT"
    echo "Unreadable source files: $unreadable_count"
    echo "Duration: $duration_text"
    echo "Log file: $logpath"
    echo ""
    echo "For detailed information, see the log file."
} >> "$summary_file"

log_info "Summary saved to: $summary_file"
log_info "Total backup time: $duration_text"

# === START: Auto-unmount ===
if [[ "$AUTO_UNMOUNT" == true && "$backup_success" == true && "$DRY_RUN" == false ]]; then
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