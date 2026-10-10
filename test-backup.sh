#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source <(sed -n '/^# === START: Restore State Export ===$/,/^# === END: Restore State Export ===$/p' "$SCRIPT_DIR/backup.sh")
source <(sed -n '/^# === START: Snapshot Retention ===$/,/^# === END: Snapshot Retention ===$/p' "$SCRIPT_DIR/backup.sh")
source <(sed -n '/^# === START: Validation Functions ===$/,/^# === END: Validation Functions ===$/p' "$SCRIPT_DIR/backup.sh")

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
SOURCE_DIR="$fixture/home"
HOST_NAME=test-host
EXCLUDE_FILE="$SCRIPT_DIR/backup-excludes.txt"
mkdir -p "$SOURCE_DIR/.ssh" "$SOURCE_DIR/.config"
touch "$SOURCE_DIR/.inputrc"

retained_paths=(
    .config/Code/User/settings.json
    .config/Code/User/snippets/test.json
    .config/Code/User/globalStorage/github.copilot-chat/history.json
    .config/Code/User/workspaceStorage/test/state.vscdb
    .codex/config.toml
    .codex/rules/test.rules
    .codex/skills/test/SKILL.md
    .codex/sessions/test.jsonl
    .codex/state_5.sqlite
    .codex/state_5.sqlite-wal
    .codex/state_5.sqlite-shm
    Documents/project/.codex/auth.json
)
excluded_paths=(
    .vscode/extensions/test/package.json
    .config/Code/Cache/test
    .codex/cache/test
    .codex/tmp/test
    .codex/.tmp/test
    .codex/ipc/test
    .codex/thread-writer-locks/test
    .codex/.sqlite-maintenance.lock
    .codex/models_cache.json
    .codex/auth.json
)
for fixture_path in "${retained_paths[@]}" "${excluded_paths[@]}"; do
    mkdir -p "$SOURCE_DIR/$(dirname "$fixture_path")"
    printf 'fixture data\n' > "$SOURCE_DIR/$fixture_path"
done
mkdir -p "$fixture/filtered"
rsync -a --exclude-from="$EXCLUDE_FILE" "$SOURCE_DIR/" "$fixture/filtered/"
for fixture_path in "${retained_paths[@]}"; do
    [[ -f "$fixture/filtered/$fixture_path" ]]
done
for fixture_path in "${excluded_paths[@]}"; do
    [[ ! -e "$fixture/filtered/$fixture_path" ]]
done

apt-mark() { printf 'test-package\n'; }
dpkg-query() { printf 'test-package\t1.0\n'; }
snap() { printf 'mock failure\n' >&2; return 1; }
flatpak() { printf 'mock-flatpak\n'; }
systemctl() { printf 'mock.service enabled\n'; }
crontab() { return 1; }
dconf() { printf '[test]\nvalue=true\n'; }
code() {
    [[ "$*" == '--list-extensions --show-versions' ]] || return 1
    printf 'github.copilot-chat@1.0\nopenai.chatgpt@2.0\n'
}
ps() { printf '%s\n' "${MOCK_AI_PROCESSES-code}"; }
log_to_file() { printf '%s\n' "$1"; }
log_error() { printf '%s\n' "$*" >&2; }

original_umask="$(umask)"
export_system_state "$fixture/export"
[[ "$(umask)" == "$original_umask" ]]
[[ "$(stat -c %a "$fixture/export")" == 700 ]]
grep -q 'test-package' "$fixture/export/apt-manual-packages.txt"
grep -q 'WARNING: snap-list.txt' "$fixture/export/export-status.txt"
grep -q 'PRESENT: .inputrc' "$fixture/export/home-config-inventory.txt"
grep -q 'ABSENT: .zshrc' "$fixture/export/home-config-inventory.txt"
grep -q 'github.copilot-chat@1.0' "$fixture/export/vscode-extensions.txt"
grep -q 'live databases may be inconsistent' "$fixture/export/export-status.txt"
[[ "$(cat "$fixture/export/running-ai-apps.txt")" == code ]]
[[ -s "$fixture/export/RESTORE.txt" ]]
[[ -s "$fixture/export/os-release" ]]
cmp "$EXCLUDE_FILE" "$fixture/export/backup-excludes.txt"
export_state_command "$fixture/export" absent.txt backup_test_nonexistent_command
grep -q 'UNAVAILABLE: backup_test_nonexistent_command' "$fixture/export/export-status.txt"

MOCK_AI_PROCESSES=$'code\ncodex\ncode\nunrelated'
[[ "$(running_ai_apps)" == $'code\ncodex' ]]
MOCK_AI_PROCESSES=''
[[ -z "$(running_ai_apps)" ]]
export_system_state "$fixture/closed-apps"
if grep -q 'live databases may be inconsistent' "$fixture/closed-apps/export-status.txt"; then
    printf 'Closed applications should not generate a live-database warning\n' >&2
    exit 1
fi
unset MOCK_AI_PROCESSES
(
    code() { printf 'mock CLI failure\n' >&2; return 1; }
    export_system_state "$fixture/failed-cli"
    grep -q 'WARNING: vscode-extensions.txt failed' "$fixture/failed-cli/export-status.txt"
)
(
    command() {
        if [[ "$1" == -v && "$2" == code ]]; then
            return 1
        fi
        builtin command "$@"
    }
    export_system_state "$fixture/missing-cli"
    grep -q 'UNAVAILABLE: code' "$fixture/missing-cli/export-status.txt"
)
(
    ps() { return 1; }
    if running_ai_apps >/dev/null; then
        printf 'Failed process discovery must report failure\n' >&2
        exit 1
    fi
)

save_restore_state "$fixture/export" "$fixture/backup/state" 20261010_120000
cmp "$fixture/export/metadata.txt" "$fixture/backup/state/20261010_120000/metadata.txt"
[[ "$(stat -c %a "$fixture/backup/state/20261010_120000")" == 700 ]]
if save_restore_state "$fixture/export" "$fixture/backup/state" 20261010_120000; then
    printf 'Duplicate state timestamp should fail\n' >&2
    exit 1
fi
if save_restore_state "$fixture/missing" "$fixture/backup/state" 20261010_130000; then
    printf 'Missing export should fail\n' >&2
    exit 1
fi
[[ ! -e "$fixture/backup/state/20261010_130000" ]]

mkdir -p "$fixture/backup/snapshots/20261010_120000" "$fixture/backup/snapshots/20261010_130000"
save_restore_state "$fixture/export" "$fixture/backup/state" 20261010_130000
prune_old_snapshots "$fixture/backup/snapshots" 0
[[ -d "$fixture/backup/state/20261010_120000" ]]
prune_old_snapshots "$fixture/backup/snapshots" 1
[[ ! -d "$fixture/backup/snapshots/20261010_120000" ]]
[[ ! -d "$fixture/backup/state/20261010_120000" ]]
[[ -d "$fixture/backup/state/20261010_130000" ]]
ln -s snapshots/20261010_130000 "$fixture/backup/latest"
mv "$fixture/backup" "$fixture/moved-backup"
[[ -d "$fixture/moved-backup/latest" ]]

findmnt() {
    if [[ "$*" == *FSTYPE* ]]; then
        printf 'ext4\n'
    elif [[ "$*" == *TARGET* ]]; then
        printf '%s\n' "${MOCK_MOUNT_TARGET:-/media/mock-backup}"
    elif [[ "${@: -1}" == / ]]; then
        printf '/dev/mock-root\n'
    else
        printf '%s\n' "${MOCK_MOUNT_SOURCE:-/dev/mock-backup}"
    fi
}
validate_mounted_destination /media/mock-backup
MOCK_MOUNT_TARGET=/
if validate_mounted_destination /media/unmounted 2>/dev/null; then
    printf 'Unmounted destination should fail\n' >&2
    exit 1
fi
MOCK_MOUNT_TARGET=/media/mock-backup
MOCK_MOUNT_SOURCE='/dev/mock-root[/home]'
if validate_mounted_destination /media/mock-backup 2>/dev/null; then
    printf 'Bind mount of root device should fail\n' >&2
    exit 1
fi
unset MOCK_MOUNT_TARGET MOCK_MOUNT_SOURCE
hostname() { printf 'test-host\n'; }
rsync() {
    local argument=""
    for argument in "$@"; do
        [[ "$argument" != --dry-run ]] || return 0
    done
    cp -a "${@: -2:1}." "${@: -1}"
}
export -f apt-mark dpkg-query snap flatpak systemctl crontab dconf code ps findmnt hostname rsync
export SOURCE_DIR EXCLUDE_FILE
TMPDIR="$fixture/temporary-exports"
mkdir -p "$TMPDIR"
export TMPDIR
for mode in normal dry-run data-only; do
    mkdir -p "$fixture/$mode/disk" "$fixture/$mode/logs"
    options=()
    [[ "$mode" != dry-run ]] || options+=(--dry-run --auto-unmount)
    [[ "$mode" != data-only ]] || options+=(--no-state-export)
    if ! bash "$SCRIPT_DIR/backup.sh" "/mnt/..$fixture/$mode/disk" "$fixture/$mode/logs" "${options[@]}" > "$fixture/$mode/output.log" 2>&1; then
        cat "$fixture/$mode/output.log" >&2
        exit 1
    fi
    backup_root="$fixture/$mode/disk/backups/test-host/home"
    grep -q 'Live editor/AI databases may be inconsistent' "$fixture/$mode/output.log"
    [[ -z "$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -print)" ]]
    [[ -z "$(find "$fixture/$mode/logs" -maxdepth 1 -name 'restore-state-*' -print)" ]]
    if [[ "$mode" == dry-run ]]; then
        [[ ! -d "$backup_root" ]]
        if grep -q 'Attempting to unmount\|Auto-unmount enabled' "$fixture/$mode/output.log"; then
            printf 'Dry run must not attempt an unmount\n' >&2
            exit 1
        fi
        [[ ! -e "$backup_root/latest" ]]
        [[ ! -e "$backup_root/state" ]]
        [[ -z "$(find "$fixture/$mode/logs" -maxdepth 1 -name 'restore-state-*' -print)" ]]
    else
        [[ -f "$backup_root/latest/.inputrc" ]]
        [[ "$(readlink "$backup_root/latest")" == snapshots/* ]]
        snapshot_name="$(basename "$(readlink "$backup_root/latest")")"
        if [[ "$mode" == normal ]]; then
            [[ -f "$backup_root/state/$snapshot_name/RESTORE.txt" ]]
            [[ -s "$backup_root/state/$snapshot_name/vscode-extensions.txt" ]]
        else
            [[ ! -e "$backup_root/state" ]]
        fi
    fi
done

staging_dir="$fixture/data-only/disk/backups/test-host/home/snapshots/.incomplete-current"
mkdir -p "$staging_dir"
touch "$staging_dir/keep-this-file"
exec 8>"$fixture/data-only/logs/backup.sh.lock"
flock -n 8
if bash "$SCRIPT_DIR/backup.sh" "/mnt/..$fixture/data-only/disk" "$fixture/data-only/logs" --no-state-export > "$fixture/locked.log" 2>&1; then
    printf 'Concurrent backup should fail\n' >&2
    exit 1
fi
[[ -f "$staging_dir/keep-this-file" ]]
grep -q 'Another backup instance' "$fixture/locked.log"
exec 8>&-

source <(sed -n '/^launch_backup_prompt() {/,/^sleep 5/{ /^sleep 5/d; p; }' "$SCRIPT_DIR/auto-backup.sh")
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"
BACKUP_LOG_DIR="$fixture/prompt-logs"
BACKUP_TARGET_DIR_NAME=MhasoBkp
mkdir -p "$BACKUP_LOG_DIR"
log_launch() { printf '%s\n' "$1" >> "$BACKUP_LOG_DIR/launch.log"; }
command() {
    if [[ "$1" == -v && "$2" == gnome-terminal ]]; then
        [[ "$MOCK_TERMINAL" == gnome ]]
    elif [[ "$1" == -v && "$2" == x-terminal-emulator ]]; then
        [[ "$MOCK_TERMINAL" == fallback ]]
    else
        builtin command "$@"
    fi
}
gnome-terminal() { printf '%s' "${@: -1}" > "$fixture/gnome-prompt"; }
x-terminal-emulator() { printf '%s' "${@: -1}" > "$fixture/fallback-prompt"; }
MOCK_TERMINAL=gnome
launch_backup_prompt "$fixture/prompt-disk"
[[ -d "$fixture/prompt-disk/MhasoBkp" ]]
MOCK_TERMINAL=fallback
launch_backup_prompt "$fixture/prompt-disk"
cmp "$fixture/gnome-prompt" "$fixture/fallback-prompt"
MOCK_TERMINAL=none
if launch_backup_prompt "$fixture/unattended-disk" 2>/dev/null; then
    printf 'Missing terminal must fail without starting a backup\n' >&2
    exit 1
fi
[[ ! -e "$fixture/unattended-disk" ]]
grep -q 'confirmation required' "$BACKUP_LOG_DIR/launch.log"
printf 'Backup migration tests passed.\n'