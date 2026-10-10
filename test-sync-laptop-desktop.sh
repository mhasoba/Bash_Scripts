#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source <(sed -n '/^sync_unison() {/,/^# Rsync function/{ /^# Rsync function/d; p; }' "$SCRIPT_DIR/sync-laptop-desktop.sh")
source <(sed -n '/^perform_sync() {/,/^# Parse arguments/{ /^# Parse arguments/d; p; }' "$SCRIPT_DIR/sync-laptop-desktop.sh")
source <(sed -n '/^create_config() {/,/^# List available profiles/{ /^# List available profiles/d; p; }' "$SCRIPT_DIR/sync-laptop-desktop.sh")
source <(sed -n '/^load_config() {/,/^# Check if required tools/{ /^# Check if required tools/d; p; }' "$SCRIPT_DIR/sync-laptop-desktop.sh")
source <(sed -n '/^manage_vpn() {/,/^# Run pre\/post sync hooks/{ /^# Run pre\/post sync hooks/d; p; }' "$SCRIPT_DIR/sync-laptop-desktop.sh")
source <(sed -n '/^parse_arguments() {/,/^# Main function$/{ /^# Main function$/d; p; }' "$SCRIPT_DIR/sync-laptop-desktop.sh")
source <(sed -n '/^main() {/,/^# Run main function/{ /^# Run main function/d; p; }' "$SCRIPT_DIR/sync-laptop-desktop.sh")
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
print_info() { printf '%s\n' "$1"; }
print_warning() { printf '%s\n' "$1"; }
print_success() { printf '%s\n' "$1"; }
print_error() { printf '%s\n' "$1" >&2; }
unison() { printf '%s\n' "$@" > "$fixture/arguments"; }

UNISON_PROFILE=MunroDesktop
DRY_RUN=false
unset UNISON_OPTIONS
sync_unison > "$fixture/normal.log"
grep -qx -- '-batch=false' "$fixture/arguments"
grep -qx -- '-confirmbigdel=true' "$fixture/arguments"
if grep -q -- '-force\|-testserver' "$fixture/arguments"; then
    printf 'Normal sync must not force a winner or test the server only\n' >&2
    exit 1
fi
DRY_RUN=true
sync_unison > "$fixture/check.log"
grep -qx -- '-testserver' "$fixture/arguments"
grep -q 'does not preview file changes' "$fixture/check.log"
grep -q 'no files synchronized' "$fixture/check.log"

SYNC_TOOL=unison
RETRY_COUNT=1
PRE_SYNC_HOOK=pre
POST_SYNC_HOOK=post
run_hook() { printf '%s\n' "$1" >> "$fixture/hooks"; }
perform_sync > "$fixture/check-hooks.log"
[[ ! -e "$fixture/hooks" ]]
DRY_RUN=false
perform_sync > "$fixture/normal-hooks.log"
[[ "$(cat "$fixture/hooks")" == $'pre\npost' ]]
DRY_RUN=true

CONFIG_DIR="$fixture/config"
DEFAULT_CONFIG="$CONFIG_DIR/default.conf"
LOG_DIR="$fixture/logs"
create_config > "$fixture/generated.log"
for config_path in "$DEFAULT_CONFIG" "$CONFIG_DIR/example-unison.conf"; do
    bash -n "$config_path"
    grep -Fqx 'UNISON_OPTIONS="-sortbysize -times -batch=false -confirmbigdel=true"' "$config_path"
done
grep -Fqx 'VPN_REQUIRED="false"' "$CONFIG_DIR/example-unison.conf"
grep -Fqx 'VPN_CONNECTION=""' "$CONFIG_DIR/example-unison.conf"

SCRIPT_NAME=sync-laptop-desktop.sh
VERSION=2.0
LOCK_FILE="$fixture/sync.lock"
VPN_REQUIRED_OVERRIDE=''
VPN_CONNECTION_OVERRIDE=''
STARTUP_DELAY=0
check_dependencies() { :; }
create_lock() { :; }
check_connectivity() { :; }
nmcli() { printf '%s\n' "$*" >> "$fixture/vpn-calls"; }
printf '%s\n' 'VPN_REQUIRED="true"' 'VPN_CONNECTION="IC"' 'UNISON_PROFILE="MunroDesktop"' > "$fixture/legacy.conf"
(main --config-file "$fixture/legacy.conf" --no-vpn) > "$fixture/external-vpn.log"
[[ ! -e "$fixture/vpn-calls" ]]
grep -qx -- 'MunroDesktop' "$fixture/arguments"

sleep() { :; }
printf '%s\n' 'VPN_REQUIRED="false"' 'VPN_CONNECTION="IC"' 'UNISON_PROFILE="MunroDesktop"' > "$fixture/manual.conf"
(main --config-file "$fixture/manual.conf" --vpn "New-VPN") > "$fixture/managed-vpn.log"
[[ "$(cat "$fixture/vpn-calls")" == $'con up id New-VPN\ncon down id New-VPN' ]]

UNISON_PROFILE="profile; touch $fixture/should-not-exist"
UNISON_OPTIONS="-times \$(touch $fixture/should-not-exist-options)"
sync_unison > "$fixture/literal.log"
[[ ! -e "$fixture/should-not-exist" ]]
[[ ! -e "$fixture/should-not-exist-options" ]]
grep -Fxq "$UNISON_PROFILE" "$fixture/arguments"

UNISON_PROFILE=''
if sync_unison > "$fixture/missing.log" 2>&1; then
    printf 'Missing profile must fail\n' >&2
    exit 1
fi
printf 'Unison launcher tests passed; no real synchronization performed.\n'