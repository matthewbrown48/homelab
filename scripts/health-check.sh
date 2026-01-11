#!/bin/bash

# Homelab Health Check Script
# Verifies all services are running correctly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DEVICES_DIR="$REPO_ROOT/devices"

log_pass() { echo -e "${GREEN}✓${NC} $1"; }
log_fail() { echo -e "${RED}✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Check if URL is accessible
check_url() {
    local url=$1
    local name=$2
    local timeout=${3:-5}

    if curl -sf --max-time "$timeout" "$url" > /dev/null; then
        log_pass "$name is accessible"
        return 0
    else
        log_fail "$name is NOT accessible"
        return 1
    fi
}

# Check Docker container health
check_container() {
    local container=$1
    local host=${2:-localhost}

    if [ "$host" = "localhost" ]; then
        local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
    else
        local status=$(ssh "$host" "docker inspect --format='{{.State.Health.Status}}' $container 2>/dev/null || echo 'unknown'")
    fi

    case $status in
        healthy)
            log_pass "$container is healthy"
            return 0
            ;;
        unhealthy)
            log_fail "$container is unhealthy"
            return 1
            ;;
        starting)
            log_warn "$container is starting"
            return 2
            ;;
        *)
            log_warn "$container has no health check or doesn't exist"
            return 3
            ;;
    esac
}

# Check Pi 5 OMV
check_pi5() {
    local host=${PI5_HOST:-pi5.local}

    echo -e "\n${GREEN}Checking Pi 5 - Open Media Vault${NC}"
    echo "=================================="

    check_url "http://$host:9443" "Portainer" 10 || true
    check_url "http://$host:3000" "Homepage" 10 || true
    check_url "http://$host:8200" "Duplicati" 10 || true
    check_url "http://$host:61208" "Glances" 10 || true
}

# Check Pi 4 CI Controller
check_pi4() {
    local host=${PI4_HOST:-pi4.local}

    echo -e "\n${GREEN}Checking Pi 4 - CI Controller${NC}"
    echo "=================================="

    check_url "http://$host:8000" "Woodpecker CI" 10 || true
    check_url "http://$host:5000/v2/" "Docker Registry" 10 || true
    check_url "http://$host:5001" "Registry UI" 10 || true
}

# Check Jellyfin Server
check_jellyfin() {
    local host=${JELLYFIN_HOST:-jellyfin.local}

    echo -e "\n${GREEN}Checking Jellyfin Server${NC}"
    echo "=================================="

    check_url "http://$host:8096/health" "Jellyfin" 10 || true
    check_url "http://$host:5055" "Jellyseerr" 10 || true
    check_url "http://$host:8080" "Traefik Dashboard" 10 || true
}

# Check all local containers
check_local() {
    echo -e "\n${GREEN}Checking Local Containers${NC}"
    echo "=================================="

    for container in $(docker ps --format '{{.Names}}'); do
        check_container "$container" || true
    done
}

# Main function
main() {
    echo -e "${GREEN}╔════════════════════════════════════════╗"
    echo -e "║    Homelab Health Check                ║"
    echo -e "╚════════════════════════════════════════╝${NC}"

    # Check if running on specific device or remote
    if [ -f /etc/hostname ]; then
        local hostname=$(cat /etc/hostname)

        case $hostname in
            *pi5*|*omv*)
                check_local
                ;;
            *pi4*|*ci*)
                check_local
                ;;
            *jellyfin*|*media*)
                check_local
                ;;
            *)
                # Not on a known device, check all remotely
                check_pi5
                check_pi4
                check_jellyfin
                ;;
        esac
    else
        # Windows or unknown OS, check all remotely
        check_pi5
        check_pi4
        check_jellyfin
    fi

    echo -e "\n${GREEN}Health check complete!${NC}\n"
}

main "$@"
