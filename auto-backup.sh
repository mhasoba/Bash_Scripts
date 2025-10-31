#!/bin/bash
# Auto-backup with user confirmation and unmount option

DEVICE="$1"
BACKUP_SCRIPT="/home/mhasoba/Documents/Code_n_script/Bash/backup.sh"

sleep 5
ACTUAL_MOUNT=$(lsblk -no MOUNTPOINT "$DEVICE" | grep -v '^$')

# Check for MhasoBkp (not mhasoba)
if [[ -n "$ACTUAL_MOUNT" && -d "$ACTUAL_MOUNT/MhasoBkp" ]]; then
    # Open terminal with confirmation dialog
    gnome-terminal -- bash -c "
        echo '=== AUTO BACKUP DETECTED ==='
        echo 'External drive detected: $ACTUAL_MOUNT'
        echo 'Backup destination ready!'
        echo ''
        echo 'Do you want to start the backup? (y/N)'
        read -n1 response
        echo ''
        
        if [[ \"\$response\" =~ ^[Yy]$ ]]; then
            echo ''
            echo 'Auto-unmount drive after backup? (Y/n)'
            read -n1 unmount_response
            echo ''
            
            if [[ \"\$unmount_response\" =~ ^[Nn]$ ]]; then
                echo 'Starting backup (without auto-unmount)...'
                '$BACKUP_SCRIPT' '$ACTUAL_MOUNT' '/home/mhasoba/backup-logs'
            else
                echo 'Starting backup (with auto-unmount)...'
                '$BACKUP_SCRIPT' '$ACTUAL_MOUNT' '/home/mhasoba/backup-logs' --auto-unmount
            fi
        else
            echo 'Backup cancelled.'
        fi
        echo ''
        echo 'Press any key to close this window...'
        read -n1
    "
fi