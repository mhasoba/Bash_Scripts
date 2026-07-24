#!/bin/bash
# Auto-backup with user confirmation and unmount option

set -euo pipefail

DEVICE="${1:-}"
BACKUP_SCRIPT="/home/mhasoba/Documents/Code_n_script/Bash/backup.sh"
BACKUP_LOG_DIR="/home/mhasoba/backup-logs"
LAUNCH_LOG="$BACKUP_LOG_DIR/auto-backup-launch.log"

if [[ -z "$DEVICE" ]]; then
    echo "Usage: $0 /dev/sdX1" >&2
    exit 1
fi

if [[ ! -x "$BACKUP_SCRIPT" ]]; then
    echo "Backup script not found or not executable: $BACKUP_SCRIPT" >&2
    exit 1
fi

mkdir -p "$BACKUP_LOG_DIR"

log_launch() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LAUNCH_LOG"
}

resolve_mount_point() {
    local device_path="$1"

    if command -v findmnt &> /dev/null; then
        findmnt -nr -o TARGET --source "$device_path" 2>/dev/null | head -n1 || true
        return 0
    fi

    lsblk -no MOUNTPOINT "$device_path" 2>/dev/null | awk 'NF { print; exit }' || true
}

launch_backup_prompt() {
    local mount_point="$1"

    export AUTO_BACKUP_SCRIPT="$BACKUP_SCRIPT"
    export AUTO_BACKUP_MOUNT="$mount_point"
    export AUTO_BACKUP_LOG_DIR="$BACKUP_LOG_DIR"

    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal --title='Auto Backup' -- bash -lc '
            echo "=== AUTO BACKUP DETECTED ==="
            echo "External drive detected: $AUTO_BACKUP_MOUNT"
            echo "Backup destination ready!"
            echo ""
            echo "Do you want to start the backup? (y/N)"
            read -r -n1 response
            echo ""

            if [[ "$response" =~ ^[Yy]$ ]]; then
                echo ""
                echo "Auto-unmount drive after backup? (Y/n)"
                read -r -n1 unmount_response
                echo ""

                if [[ "$unmount_response" =~ ^[Nn]$ ]]; then
                    echo "Starting backup (without auto-unmount)..."
                    "$AUTO_BACKUP_SCRIPT" "$AUTO_BACKUP_MOUNT" "$AUTO_BACKUP_LOG_DIR"
                else
                    echo "Starting backup (with auto-unmount)..."
                    "$AUTO_BACKUP_SCRIPT" "$AUTO_BACKUP_MOUNT" "$AUTO_BACKUP_LOG_DIR" --auto-unmount
                fi
            else
                echo "Backup cancelled."
            fi
            echo ""
            echo "Press any key to close this window..."
            read -r -n1
        '
        return $?
    fi

    if command -v x-terminal-emulator &> /dev/null; then
        x-terminal-emulator -e bash -lc '
            echo "=== AUTO BACKUP DETECTED ==="
            echo "External drive detected: $AUTO_BACKUP_MOUNT"
            echo "Backup destination ready!"
            echo ""
            echo "Do you want to start the backup? (y/N)"
            read -r -n1 response
            echo ""

            if [[ "$response" =~ ^[Yy]$ ]]; then
                echo ""
                echo "Auto-unmount drive after backup? (Y/n)"
                read -r -n1 unmount_response
                echo ""

                if [[ "$unmount_response" =~ ^[Nn]$ ]]; then
                    echo "Starting backup (without auto-unmount)..."
                    "$AUTO_BACKUP_SCRIPT" "$AUTO_BACKUP_MOUNT" "$AUTO_BACKUP_LOG_DIR"
                else
                    echo "Starting backup (with auto-unmount)..."
                    "$AUTO_BACKUP_SCRIPT" "$AUTO_BACKUP_MOUNT" "$AUTO_BACKUP_LOG_DIR" --auto-unmount
                fi
            else
                echo "Backup cancelled."
            fi
            echo ""
            echo "Press any key to close this window..."
            read -r -n1
        '
        return $?
    fi

    echo "No supported terminal emulator found. Running backup in the background." >&2
    log_launch "No terminal emulator found; running backup headlessly for $mount_point"

    if command -v notify-send &> /dev/null; then
        notify-send "Backup disk detected" "Running backup in the background; see $LAUNCH_LOG for details."
    fi

    "$AUTO_BACKUP_SCRIPT" "$mount_point" "$BACKUP_LOG_DIR" --auto-unmount >> "$LAUNCH_LOG" 2>&1 &
}

sleep 5
ACTUAL_MOUNT="$(resolve_mount_point "$DEVICE")"
log_launch "Resolved device $DEVICE to mount path: ${ACTUAL_MOUNT:-<none>}"

# Check for MhasoBkp (not mhasoba)
if [[ -n "$ACTUAL_MOUNT" && -d "$ACTUAL_MOUNT/MhasoBkp" ]]; then
    if command -v notify-send &> /dev/null; then
        notify-send "Backup disk detected" "Open the Auto Backup terminal window to confirm the backup."
    fi
    log_launch "Launching Auto Backup terminal for $ACTUAL_MOUNT"

    if launch_backup_prompt "$ACTUAL_MOUNT"; then
        log_launch "Backup launcher completed successfully for $ACTUAL_MOUNT"
    else
        log_launch "Backup launcher exited with status $?"
    fi
else
    log_launch "Backup sentinel missing for mount path: ${ACTUAL_MOUNT:-<none>}"
fi