#!/bin/bash

# Homelab Deployment Script
# Deploys docker-compose stacks to devices via SSH

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DEVICES_DIR="$REPO_ROOT/devices"

# Function to print colored output
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 <device-name> [options]

Deploy docker-compose stack to a device.

Arguments:
    device-name     Name of the device to deploy to:
                    - pi5-openmediavault
                    - pi4-ci-controller
                    - jellyfin-server
                    - all (deploy to all devices)

Options:
    -h, --help      Show this help message
    -l, --local     Deploy locally (no SSH)
    -t, --test      Test mode (validate configs only)
    -v, --verbose   Verbose output

Examples:
    $0 pi5-openmediavault               # Deploy to Pi 5
    $0 all                               # Deploy to all devices
    $0 jellyfin-server --local          # Deploy locally
    $0 pi4-ci-controller --test         # Test config only

EOF
}

# Function to validate device name
validate_device() {
    local device=$1
    local device_path="$DEVICES_DIR/$device"

    if [ ! -d "$device_path" ]; then
        log_error "Device '$device' not found in $DEVICES_DIR"
        return 1
    fi

    if [ ! -f "$device_path/docker-compose.yml" ]; then
        log_error "No docker-compose.yml found for device '$device'"
        return 1
    fi

    return 0
}

# Function to validate docker-compose configuration
validate_config() {
    local device=$1
    local device_path="$DEVICES_DIR/$device"

    log_info "Validating docker-compose configuration for $device..."

    cd "$device_path"

    if [ ! -f .env ]; then
        log_warn "No .env file found. Using .env.example if available."
        if [ -f .env.example ]; then
            cp .env.example .env
            log_warn "Created .env from .env.example. Please review and update!"
        fi
    fi

    docker-compose config > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_info "✓ Configuration valid"
        return 0
    else
        log_error "✗ Configuration invalid"
        docker-compose config
        return 1
    fi
}

# Function to deploy locally
deploy_local() {
    local device=$1
    local device_path="$DEVICES_DIR/$device"

    log_info "Deploying $device locally..."

    cd "$device_path"

    # Pull latest images
    log_info "Pulling latest images..."
    docker-compose pull

    # Deploy stack
    log_info "Starting services..."
    docker-compose up -d

    # Show status
    log_info "Service status:"
    docker-compose ps

    log_info "✓ Deployment complete for $device"
}

# Function to deploy via SSH
deploy_remote() {
    local device=$1
    local host=$2
    local user=${3:-deploy}
    local deploy_path=${4:-/opt/homelab}

    log_info "Deploying $device to $host..."

    # Create remote directory
    ssh "$user@$host" "mkdir -p $deploy_path/$device"

    # Sync files
    log_info "Syncing files to $host..."
    rsync -avz --delete \
        --exclude='.env' \
        "$DEVICES_DIR/$device/" \
        "$user@$host:$deploy_path/$device/"

    # Check if .env exists remotely
    if ! ssh "$user@$host" "[ -f $deploy_path/$device/.env ]"; then
        log_warn "No .env file on remote host. Copying .env.example..."
        ssh "$user@$host" "cp $deploy_path/$device/.env.example $deploy_path/$device/.env"
        log_warn "Please SSH to $host and configure $deploy_path/$device/.env"
    fi

    # Deploy on remote
    log_info "Deploying on remote host..."
    ssh "$user@$host" << EOF
        set -e
        cd $deploy_path/$device
        docker-compose pull
        docker-compose up -d
        docker-compose ps
EOF

    log_info "✓ Deployment complete for $device on $host"
}

# Function to get host for device
get_device_host() {
    local device=$1

    case $device in
        pi5-openmediavault)
            echo "${PI5_HOST:-pi5.local}"
            ;;
        pi4-ci-controller)
            echo "${PI4_HOST:-pi4.local}"
            ;;
        jellyfin-server)
            echo "${JELLYFIN_HOST:-jellyfin.local}"
            ;;
        *)
            log_error "Unknown device: $device"
            return 1
            ;;
    esac
}

# Function to run health checks
health_check() {
    local device=$1
    local device_path="$DEVICES_DIR/$device"

    log_info "Running health checks for $device..."

    cd "$device_path"

    # Wait a bit for services to start
    sleep 5

    # Check container health
    local unhealthy=$(docker-compose ps | grep -i "unhealthy" || true)

    if [ -z "$unhealthy" ]; then
        log_info "✓ All services healthy"
        return 0
    else
        log_warn "Some services unhealthy:"
        echo "$unhealthy"
        return 1
    fi
}

# Main deployment function
deploy_device() {
    local device=$1
    local mode=${2:-remote}

    validate_device "$device" || return 1
    validate_config "$device" || return 1

    if [ "$mode" = "local" ]; then
        deploy_local "$device"
        health_check "$device"
    elif [ "$mode" = "test" ]; then
        log_info "✓ Test passed for $device"
    else
        local host=$(get_device_host "$device")
        deploy_remote "$device" "$host"
    fi
}

# Parse arguments
DEVICE=""
MODE="remote"
VERBOSE=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -l|--local)
            MODE="local"
            shift
            ;;
        -t|--test)
            MODE="test"
            shift
            ;;
        -v|--verbose)
            VERBOSE=1
            set -x
            shift
            ;;
        *)
            DEVICE=$1
            shift
            ;;
    esac
done

# Check if device specified
if [ -z "$DEVICE" ]; then
    log_error "No device specified"
    usage
    exit 1
fi

# Deploy to all devices or single device
if [ "$DEVICE" = "all" ]; then
    log_info "Deploying to all devices..."

    for device_dir in "$DEVICES_DIR"/*; do
        if [ -d "$device_dir" ] && [ "$(basename "$device_dir")" != "shared" ]; then
            device_name=$(basename "$device_dir")
            log_info "=== Deploying $device_name ==="
            deploy_device "$device_name" "$MODE" || log_error "Failed to deploy $device_name"
            echo
        fi
    done

    log_info "✓ All deployments complete"
else
    deploy_device "$DEVICE" "$MODE"
fi
