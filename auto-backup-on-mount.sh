#!/bin/bash

set -euo pipefail

AUTO_BACKUP_SCRIPT="/home/mhasoba/Documents/Code_n_script/Bash/auto-backup.sh"
SENTINEL_DIR_NAME="MhasoBkp"
USER_NAME="${USER:-$(id -un)}"

search_roots=(
    "/run/media/$USER_NAME"
    "/media/$USER_NAME"
    "/media"
)

if [[ ! -x "$AUTO_BACKUP_SCRIPT" ]]; then
    echo "auto-backup script not found or not executable: $AUTO_BACKUP_SCRIPT" >&2
    exit 1
fi

for root in "${search_roots[@]}"; do
    [[ -d "$root" ]] || continue

    for mount_point in "$root"/*; do
        [[ -d "$mount_point" ]] || continue

        # Accept either layout:
        # 1) mount point itself named MhasoBkp
        # 2) mount point containing MhasoBkp subdirectory
        if [[ "$(basename "$mount_point")" != "$SENTINEL_DIR_NAME" && ! -d "$mount_point/$SENTINEL_DIR_NAME" ]]; then
            continue
        fi

        device_path="$(findmnt -n -o SOURCE --target "$mount_point" 2>/dev/null || true)"

        if [[ -n "$device_path" ]]; then
            exec "$AUTO_BACKUP_SCRIPT" "$device_path"
        fi
    done
done

echo "No mounted backup disk with $SENTINEL_DIR_NAME found under supported mount roots." >&2
exit 1