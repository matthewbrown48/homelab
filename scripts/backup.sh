#!/bin/bash

# Homelab Backup Script
# Backs up configurations and Docker volumes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

usage() {
    cat << EOF
Usage: $0 [device-name]

Backup homelab configurations and Docker volumes.

Arguments:
    device-name     Optional: Specific device to backup
                    If not specified, backs up all devices

Options:
    -h, --help      Show this help
    -d, --dir       Backup directory (default: ./backups)

Examples:
    $0                          # Backup all
    $0 pi5-openmediavault       # Backup specific device
    $0 --dir /mnt/backups all   # Backup all to specific location

EOF
}

# Backup git repository (configs)
backup_configs() {
    log_info "Backing up git repository..."

    mkdir -p "$BACKUP_DIR"

    local backup_file="$BACKUP_DIR/homelab-config-$TIMESTAMP.tar.gz"

    tar -czf "$backup_file" \
        --exclude='.git' \
        --exclude='backups' \
        --exclude='*.log' \
        .

    log_info "✓ Config backup: $backup_file"
}

# Backup Docker volumes for a device
backup_volumes() {
    local device=$1

    log_info "Backing up Docker volumes for $device..."

    mkdir -p "$BACKUP_DIR/$device"

    # Get all volumes used by this device
    cd "devices/$device"

    local volumes=$(docker-compose config --volumes 2>/dev/null || echo "")

    if [ -z "$volumes" ]; then
        log_info "No volumes to backup for $device"
        return 0
    fi

    for volume in $volumes; do
        local backup_file="$BACKUP_DIR/$device/${volume}-$TIMESTAMP.tar.gz"

        log_info "Backing up volume: $volume"

        docker run --rm \
            -v "$volume:/data" \
            -v "$(pwd)/$BACKUP_DIR/$device:/backup" \
            alpine \
            tar czf "/backup/$(basename $backup_file)" -C /data .

        log_info "✓ Volume backup: $backup_file"
    done

    cd ../..
}

# Main backup function
main() {
    local device=""
    local backup_dir="./backups"

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--dir)
                backup_dir=$2
                shift 2
                ;;
            *)
                device=$1
                shift
                ;;
        esac
    done

    BACKUP_DIR=$backup_dir

    log_info "Starting backup..."
    log_info "Backup directory: $BACKUP_DIR"

    # Always backup configs
    backup_configs

    # Backup volumes
    if [ -z "$device" ] || [ "$device" = "all" ]; then
        # Backup all devices
        for device_dir in devices/*; do
            if [ -d "$device_dir" ] && [ "$(basename "$device_dir")" != "shared" ]; then
                backup_volumes "$(basename "$device_dir")"
            fi
        done
    else
        # Backup specific device
        backup_volumes "$device"
    fi

    log_info "✓ Backup complete!"
    log_info "Backups saved to: $BACKUP_DIR"
}

main "$@"
