#!/bin/bash

################################################################################
# Universal Sync Script v2.0
# 
# DESCRIPTION:
#   A generalized synchronization script supporting multiple sync tools
#   (unison, rsync, rclone) with VPN connectivity, configuration profiles,
#   and comprehensive error handling.
#
# FEATURES:
#   ✓ Multiple sync backends (unison, rsync, rclone)
#   ✓ VPN connection management
#   ✓ Configuration profiles
#   ✓ Dry-run mode
#   ✓ Logging and progress monitoring
#   ✓ Pre/post sync hooks
#   ✓ Network connectivity checks
#   ✓ Automatic retry on failure
#
# USAGE:
#   ./sync-laptop-desktop.sh [OPTIONS] [PROFILE]
#   ./sync-laptop-desktop.sh --config-file custom.conf
################################################################################

set -euo pipefail

# Script configuration
SCRIPT_NAME="$(basename "$0")"
VERSION="2.0"
CONFIG_DIR="${HOME}/.config/sync-tools"
DEFAULT_CONFIG="${CONFIG_DIR}/default.conf"
LOG_DIR="${HOME}/.local/share/sync-tools/logs"
LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"

# Default settings
SYNC_TOOL="unison"
VPN_CONNECTION=""
VPN_REQUIRED="false"
UNISON_PROFILE=""
RSYNC_SOURCE=""
RSYNC_DEST=""
RCLONE_SOURCE=""
RCLONE_DEST=""
DRY_RUN="false"
VERBOSE="false"
QUIET="false"
PRE_SYNC_HOOK=""
POST_SYNC_HOOK=""
RETRY_COUNT="3"
RETRY_DELAY="5"
CONNECTION_TIMEOUT="30"
STARTUP_DELAY="0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print functions
print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
    logger -t "$SCRIPT_NAME" "ERROR: $1"
}

print_success() {
    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}Success: $1${NC}"
    logger -t "$SCRIPT_NAME" "SUCCESS: $1"
}

print_info() {
    [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}Info: $1${NC}"
    logger -t "$SCRIPT_NAME" "INFO: $1"
}

print_warning() {
    [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}Warning: $1${NC}"
    logger -t "$SCRIPT_NAME" "WARNING: $1"
}

# Usage function
usage() {
    cat << EOF
$(echo -e "${GREEN}Universal Sync Script v$VERSION${NC}")

DESCRIPTION:
    Generalized synchronization script with VPN support, multiple backends,
    and configuration profiles for automated file synchronization.

USAGE:
    $SCRIPT_NAME [OPTIONS] [PROFILE]
    $SCRIPT_NAME --list-profiles
    $SCRIPT_NAME --create-config

OPTIONS:
    --config-file FILE      Use specific configuration file
    --profile PROFILE       Use named configuration profile
    --sync-tool TOOL        Sync tool: unison, rsync, rclone (default: unison)
    --vpn CONNECTION        VPN connection name for nmcli
    --no-vpn               Disable VPN connection
    --dry-run              Show what would be synced without doing it
    --verbose, -v          Enable verbose output
    --quiet, -q            Suppress non-error output
    --retry-count NUM      Number of retry attempts (default: 3)
    --startup-delay NUM    Delay before starting sync (default: 0 seconds)
    --list-profiles        List available configuration profiles
    --create-config        Create default configuration files
    --help, -h             Show this help
    --version              Show version information

SYNC TOOLS:
    unison                 Bidirectional sync with conflict resolution
    rsync                  One-way sync with incremental updates  
    rclone                 Cloud storage sync (supports 40+ providers)

EXAMPLES:
    # Use default profile
    $SCRIPT_NAME

    # Use specific profile with VPN
    $SCRIPT_NAME --profile work --vpn "Company-VPN"

    # Dry run with verbose output
    $SCRIPT_NAME --profile home --dry-run --verbose

    # One-way rsync without VPN
    $SCRIPT_NAME --sync-tool rsync --no-vpn --config-file rsync.conf

    # Cloud sync with rclone
    $SCRIPT_NAME --sync-tool rclone --profile cloud-backup

CONFIGURATION:
    Configuration files are stored in: $CONFIG_DIR
    Logs are stored in: $LOG_DIR
    
    Run '$SCRIPT_NAME --create-config' to generate example configurations.

EOF
}

# Create configuration directories and default config
create_config() {
    mkdir -p "$CONFIG_DIR" "$LOG_DIR"
    
    if [[ ! -f "$DEFAULT_CONFIG" ]]; then
        cat > "$DEFAULT_CONFIG" << 'EOFCONFIG'
# Universal Sync Configuration
# Copy this file and modify for different profiles

# Sync tool: unison, rsync, or rclone
SYNC_TOOL="unison"

# VPN Settings
VPN_REQUIRED="false"
VPN_CONNECTION=""                    # nmcli connection name

# Unison Settings (for bidirectional sync)
UNISON_PROFILE="default"            # Unison profile name
UNISON_OPTIONS="-sortbysize -batch -times -force newer -confirmbigdel=false"

# Rsync Settings (for one-way sync)
RSYNC_SOURCE="/home/user/Documents/"
RSYNC_DEST="user@remote:/backup/Documents/"
RSYNC_OPTIONS="-avz --progress --delete"

# Rclone Settings (for cloud sync)
RCLONE_SOURCE="/home/user/Documents/"
RCLONE_DEST="remote:backup/Documents/"
RCLONE_OPTIONS="--progress --transfers 4"

# General Settings
STARTUP_DELAY="5"                   # Seconds to wait before sync
RETRY_COUNT="3"                     # Retry attempts on failure
RETRY_DELAY="10"                    # Seconds between retries
CONNECTION_TIMEOUT="30"             # Network connection timeout

# Hooks (optional scripts to run before/after sync)
PRE_SYNC_HOOK=""                    # Script to run before sync
POST_SYNC_HOOK=""                   # Script to run after sync

EOFCONFIG
        
        print_success "Created default configuration: $DEFAULT_CONFIG"
    fi
    
    # Create example profiles
    cat > "$CONFIG_DIR/example-unison.conf" << 'EOFCONFIG'
# Example Unison Profile
SYNC_TOOL="unison"
VPN_REQUIRED="true"
VPN_CONNECTION="IC"
UNISON_PROFILE="MunroDesktop"
UNISON_OPTIONS="-sortbysize -batch -times -force newer -confirmbigdel=false"
STARTUP_DELAY="5"
EOFCONFIG

    cat > "$CONFIG_DIR/example-rsync.conf" << 'EOFCONFIG'
# Example Rsync Profile
SYNC_TOOL="rsync"
VPN_REQUIRED="false"
RSYNC_SOURCE="/home/user/Documents/"
RSYNC_DEST="user@server.example.com:/backup/Documents/"
RSYNC_OPTIONS="-avz --progress --delete --exclude='.git/'"
EOFCONFIG

    cat > "$CONFIG_DIR/example-rclone.conf" << 'EOFCONFIG'
# Example Rclone Profile
SYNC_TOOL="rclone"
VPN_REQUIRED="false"
RCLONE_SOURCE="/home/user/Documents/"
RCLONE_DEST="gdrive:backup/Documents/"
RCLONE_OPTIONS="--progress --transfers 8 --checkers 8"
POST_SYNC_HOOK="/usr/local/bin/notify-send 'Backup Complete'"
EOFCONFIG
    
    print_success "Created example configurations in $CONFIG_DIR"
}

# List available profiles
list_profiles() {
    echo -e "${GREEN}Available Sync Profiles:${NC}"
    echo
    
    if [[ -d "$CONFIG_DIR" ]]; then
        for config_file in "$CONFIG_DIR"/*.conf; do
            if [[ -f "$config_file" ]]; then
                local profile_name="$(basename "$config_file" .conf)"
                local sync_tool="$(grep '^SYNC_TOOL=' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "unknown")"
                local vpn_required="$(grep '^VPN_REQUIRED=' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "false")"
                
                echo "  📁 $profile_name"
                echo "     Tool: $sync_tool | VPN: $vpn_required"
                echo
            fi
        done
    else
        echo "  No profiles found. Run '$SCRIPT_NAME --create-config' first."
    fi
}

# Load configuration file
load_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    print_info "Loading configuration: $config_file"
    
    # Source the configuration file safely
    if ! source "$config_file"; then
        print_error "Failed to load configuration file: $config_file"
        exit 1
    fi
}

# Check if required tools are available
check_dependencies() {
    local missing_deps=()
    
    # Check sync tool
    case "$SYNC_TOOL" in
        unison)
            command -v unison >/dev/null 2>&1 || missing_deps+=("unison")
            ;;
        rsync)
            command -v rsync >/dev/null 2>&1 || missing_deps+=("rsync")
            ;;
        rclone)
            command -v rclone >/dev/null 2>&1 || missing_deps+=("rclone")
            ;;
        *)
            print_error "Unknown sync tool: $SYNC_TOOL"
            exit 1
            ;;
    esac
    
    # Check VPN tool if required
    if [[ "$VPN_REQUIRED" == "true" ]]; then
        command -v nmcli >/dev/null 2>&1 || missing_deps+=("nmcli")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# Create lock file to prevent concurrent runs
create_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid="$(cat "$LOCK_FILE" 2>/dev/null)"
        if kill -0 "$lock_pid" 2>/dev/null; then
            print_error "Another sync process is already running (PID: $lock_pid)"
            exit 1
        else
            print_warning "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
}

# Check network connectivity
check_connectivity() {
    local host="8.8.8.8"
    local timeout="$CONNECTION_TIMEOUT"
    
    print_info "Checking network connectivity..."
    
    if ! ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
        print_error "No network connectivity detected"
        return 1
    fi
    
    print_success "Network connectivity confirmed"
}

# VPN connection management
manage_vpn() {
    local action="$1"
    
    if [[ "$VPN_REQUIRED" != "true" ]]; then
        return 0
    fi
    
    if [[ -z "$VPN_CONNECTION" ]]; then
        print_error "VPN required but no connection specified"
        return 1
    fi
    
    case "$action" in
        up)
            print_info "Connecting to VPN: $VPN_CONNECTION"
            if ! nmcli con up id "$VPN_CONNECTION" 2>/dev/null; then
                print_error "Failed to connect to VPN: $VPN_CONNECTION"
                return 1
            fi
            print_success "VPN connected"
            
            # Wait a moment for connection to stabilize
            sleep 3
            ;;
        down)
            print_info "Disconnecting from VPN: $VPN_CONNECTION"
            if ! nmcli con down id "$VPN_CONNECTION" 2>/dev/null; then
                print_warning "Failed to disconnect VPN (may already be down)"
            else
                print_success "VPN disconnected"
            fi
            ;;
    esac
}

# Run pre/post sync hooks
run_hook() {
    local hook="$1"
    local phase="$2"
    
    if [[ -n "$hook" && -x "$hook" ]]; then
        print_info "Running $phase hook: $hook"
        if ! "$hook"; then
            print_warning "$phase hook failed: $hook"
        fi
    fi
}

# Unison sync function
sync_unison() {
    local options="${UNISON_OPTIONS:--sortbysize -batch -times}"
    local profile="$UNISON_PROFILE"
    
    if [[ -z "$profile" ]]; then
        print_error "Unison profile not specified"
        return 1
    fi
    
    print_info "Starting Unison sync with profile: $profile"
    
    local cmd="unison $options"
    if [[ "$DRY_RUN" == "true" ]]; then
        cmd="$cmd -testserver"
    fi
    cmd="$cmd $profile"
    
    print_info "Running: $cmd"
    
    if eval "$cmd"; then
        print_success "Unison sync completed successfully"
    else
        print_error "Unison sync failed"
        return 1
    fi
}

# Rsync function
sync_rsync() {
    local options="${RSYNC_OPTIONS:--avz --progress}"
    local source="$RSYNC_SOURCE"
    local dest="$RSYNC_DEST"
    
    if [[ -z "$source" || -z "$dest" ]]; then
        print_error "Rsync source and destination must be specified"
        return 1
    fi
    
    print_info "Starting Rsync: $source -> $dest"
    
    local cmd="rsync $options"
    if [[ "$DRY_RUN" == "true" ]]; then
        cmd="$cmd --dry-run"
    fi
    cmd="$cmd \"$source\" \"$dest\""
    
    print_info "Running: $cmd"
    
    if eval "$cmd"; then
        print_success "Rsync completed successfully"
    else
        print_error "Rsync failed"
        return 1
    fi
}

# Rclone sync function
sync_rclone() {
    local options="${RCLONE_OPTIONS:--progress}"
    local source="$RCLONE_SOURCE"
    local dest="$RCLONE_DEST"
    
    if [[ -z "$source" || -z "$dest" ]]; then
        print_error "Rclone source and destination must be specified"
        return 1
    fi
    
    print_info "Starting Rclone sync: $source -> $dest"
    
    local cmd="rclone sync $options"
    if [[ "$DRY_RUN" == "true" ]]; then
        cmd="$cmd --dry-run"
    fi
    cmd="$cmd \"$source\" \"$dest\""
    
    print_info "Running: $cmd"
    
    if eval "$cmd"; then
        print_success "Rclone sync completed successfully"
    else
        print_error "Rclone sync failed"
        return 1
    fi
}

# Main sync function with retry logic
perform_sync() {
    local attempt=1
    local max_attempts="$RETRY_COUNT"
    
    while [[ $attempt -le $max_attempts ]]; do
        print_info "Sync attempt $attempt of $max_attempts"
        
        # Run pre-sync hook
        run_hook "$PRE_SYNC_HOOK" "pre-sync"
        
        # Perform sync based on tool
        local sync_success=false
        case "$SYNC_TOOL" in
            unison)
                if sync_unison; then
                    sync_success=true
                fi
                ;;
            rsync)
                if sync_rsync; then
                    sync_success=true
                fi
                ;;
            rclone)
                if sync_rclone; then
                    sync_success=true
                fi
                ;;
        esac
        
        if [[ "$sync_success" == "true" ]]; then
            # Run post-sync hook
            run_hook "$POST_SYNC_HOOK" "post-sync"
            return 0
        fi
        
        # Retry logic
        if [[ $attempt -lt $max_attempts ]]; then
            print_warning "Sync failed, retrying in $RETRY_DELAY seconds..."
            sleep "$RETRY_DELAY"
        fi
        
        ((attempt++))
    done
    
    print_error "Sync failed after $max_attempts attempts"
    return 1
}

# Parse arguments
parse_arguments() {
    local config_file=""
    local profile=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config-file)
                config_file="$2"
                shift 2
                ;;
            --profile)
                profile="$2"
                shift 2
                ;;
            --sync-tool)
                SYNC_TOOL="$2"
                shift 2
                ;;
            --vpn)
                VPN_CONNECTION="$2"
                VPN_REQUIRED="true"
                shift 2
                ;;
            --no-vpn)
                VPN_REQUIRED="false"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --verbose|-v)
                VERBOSE="true"
                shift
                ;;
            --quiet|-q)
                QUIET="true"
                shift
                ;;
            --retry-count)
                RETRY_COUNT="$2"
                shift 2
                ;;
            --startup-delay)
                STARTUP_DELAY="$2"
                shift 2
                ;;
            --list-profiles)
                list_profiles
                exit 0
                ;;
            --create-config)
                create_config
                exit 0
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            --version)
                echo "Universal Sync Script v$VERSION"
                exit 0
                ;;
            *)
                if [[ -z "$profile" ]]; then
                    profile="$1"
                else
                    print_error "Unknown option: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Determine config file
    if [[ -n "$config_file" ]]; then
        CONFIG_FILE="$config_file"
    elif [[ -n "$profile" ]]; then
        CONFIG_FILE="$CONFIG_DIR/$profile.conf"
    else
        CONFIG_FILE="$DEFAULT_CONFIG"
    fi
    
    # Create default config if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" && "$CONFIG_FILE" == "$DEFAULT_CONFIG" ]]; then
        create_config
    fi
}

# Main function
main() {
    print_info "Universal Sync Script v$VERSION starting..."
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Load configuration
    load_config "$CONFIG_FILE"
    
    # Check dependencies
    check_dependencies
    
    # Create lock file
    create_lock
    
    # Startup delay
    if [[ "$STARTUP_DELAY" -gt 0 ]]; then
        print_info "Waiting $STARTUP_DELAY seconds before starting..."
        sleep "$STARTUP_DELAY"
    fi
    
    # Check connectivity
    check_connectivity
    
    # Setup VPN connection
    if ! manage_vpn up; then
        exit 1
    fi
    
    # Ensure VPN cleanup on exit
    trap 'manage_vpn down; rm -f "$LOCK_FILE"' EXIT
    
    # Perform synchronization
    if perform_sync; then
        print_success "Synchronization completed successfully"
        exit 0
    else
        print_error "Synchronization failed"
        exit 1
    fi
}

# Run main function
main "$@"
