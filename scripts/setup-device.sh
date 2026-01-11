#!/bin/bash

# Homelab Device Setup Script
# Prepares a device for GitOps deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

usage() {
    cat << EOF
Usage: $0 <device-name> [options]

Prepare a device for homelab deployment.

This script will:
  1. Update system packages
  2. Install Docker and Docker Compose
  3. Create deployment user
  4. Configure SSH access
  5. Set up directory structure
  6. Configure firewall

Arguments:
    device-name     Name of device (pi5-openmediavault, pi4-ci-controller, jellyfin-server)

Options:
    -h, --help      Show this help
    -s, --skip-update   Skip system update
    -u, --user      Deployment user (default: deploy)

Example:
    $0 pi5-openmediavault
    $0 pi4-ci-controller --user homelab

EOF
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root or with sudo"
        exit 1
    fi
}

# Update system
update_system() {
    log_step "Updating system packages..."

    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get upgrade -y
        apt-get install -y curl git rsync htop vim
    elif command -v yum &> /dev/null; then
        yum update -y
        yum install -y curl git rsync htop vim
    else
        log_error "Unsupported package manager"
        return 1
    fi

    log_info "✓ System updated"
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker already installed"
        docker --version
        return 0
    fi

    log_step "Installing Docker..."

    # Install using Docker's convenience script
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    log_info "✓ Docker installed"
    docker --version
}

# Install Docker Compose
install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        log_info "Docker Compose already installed"
        docker-compose --version
        return 0
    fi

    log_step "Installing Docker Compose..."

    # Install Docker Compose plugin
    apt-get install -y docker-compose-plugin

    # Create docker-compose alias if needed
    if ! command -v docker-compose &> /dev/null; then
        echo 'alias docker-compose="docker compose"' >> /etc/bash.bashrc
    fi

    log_info "✓ Docker Compose installed"
}

# Create deployment user
create_deploy_user() {
    local username=$1

    if id "$username" &>/dev/null; then
        log_info "User $username already exists"
        return 0
    fi

    log_step "Creating deployment user: $username..."

    # Create user
    useradd -m -s /bin/bash "$username"

    # Add to docker group
    usermod -aG docker "$username"

    # Add to sudoers with NOPASSWD for docker commands
    echo "$username ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/docker-compose, /usr/local/bin/docker-compose" > "/etc/sudoers.d/$username"
    chmod 0440 "/etc/sudoers.d/$username"

    log_info "✓ User $username created"
}

# Setup SSH
setup_ssh() {
    local username=$1

    log_step "Setting up SSH for $username..."

    local ssh_dir="/home/$username/.ssh"

    # Create .ssh directory
    mkdir -p "$ssh_dir"

    # Create authorized_keys if it doesn't exist
    touch "$ssh_dir/authorized_keys"
    chmod 700 "$ssh_dir"
    chmod 600 "$ssh_dir/authorized_keys"
    chown -R "$username:$username" "$ssh_dir"

    log_info "✓ SSH configured"
    log_warn "Add your public key to: $ssh_dir/authorized_keys"
}

# Create directory structure
create_directories() {
    local username=$1

    log_step "Creating directory structure..."

    local base_dir="/opt/homelab"

    mkdir -p "$base_dir"
    chown -R "$username:$username" "$base_dir"

    log_info "✓ Directories created at $base_dir"
}

# Configure firewall (if UFW is available)
configure_firewall() {
    local device=$1

    if ! command -v ufw &> /dev/null; then
        log_warn "UFW not installed, skipping firewall configuration"
        return 0
    fi

    log_step "Configuring firewall..."

    # Always allow SSH
    ufw allow 22/tcp

    # Device-specific ports
    case $device in
        pi5-openmediavault)
            ufw allow 9443/tcp  # Portainer
            ufw allow 3000/tcp  # Homepage
            ufw allow 8200/tcp  # Duplicati
            ;;
        pi4-ci-controller)
            ufw allow 8000/tcp  # Woodpecker
            ufw allow 5000/tcp  # Registry
            ufw allow 5001/tcp  # Registry UI
            ufw allow 9000/tcp  # Woodpecker gRPC
            ;;
        jellyfin-server)
            ufw allow 80/tcp    # HTTP
            ufw allow 443/tcp   # HTTPS
            ufw allow 8096/tcp  # Jellyfin
            ufw allow 5055/tcp  # Jellyseerr
            ;;
    esac

    # Enable UFW
    ufw --force enable

    log_info "✓ Firewall configured"
}

# Set static IP reminder
static_ip_reminder() {
    log_warn "IMPORTANT: Set a static IP for this device!"
    log_warn "Either:"
    log_warn "  1. Configure DHCP reservation on your router"
    log_warn "  2. Set static IP in /etc/network/interfaces (Debian)"
    log_warn "  3. Use netplan (Ubuntu)"
}

# Display summary
show_summary() {
    local device=$1
    local username=$2

    cat << EOF

${GREEN}╔════════════════════════════════════════════════════════════╗
║              Device Setup Complete!                        ║
╚════════════════════════════════════════════════════════════╝${NC}

Device: ${BLUE}$device${NC}
Deploy User: ${BLUE}$username${NC}
Deploy Path: ${BLUE}/opt/homelab${NC}

${YELLOW}Next Steps:${NC}

1. Add your public SSH key:
   ${BLUE}ssh-copy-id $username@<this-device-ip>${NC}

   Or manually:
   ${BLUE}cat ~/.ssh/id_rsa.pub | ssh $username@<device-ip> "cat >> ~/.ssh/authorized_keys"${NC}

2. Set a static IP address for this device

3. Update your environment variables:
   ${BLUE}export PI5_HOST=<ip-address>${NC}  (add to ~/.bashrc)

4. Clone homelab repo on your workstation:
   ${BLUE}git clone https://github.com/YOUR_USERNAME/homelab.git${NC}

5. Deploy from your workstation:
   ${BLUE}./scripts/deploy.sh $device${NC}

${GREEN}Happy homelabbing!${NC}

EOF
}

# Main setup function
main() {
    local device=""
    local skip_update=0
    local username="deploy"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -s|--skip-update)
                skip_update=1
                shift
                ;;
            -u|--user)
                username=$2
                shift 2
                ;;
            *)
                device=$1
                shift
                ;;
        esac
    done

    if [ -z "$device" ]; then
        log_error "No device name specified"
        usage
        exit 1
    fi

    # Check root
    check_root

    # Show what we're doing
    log_info "Setting up device: $device"
    log_info "Deployment user: $username"
    echo

    # Run setup steps
    if [ $skip_update -eq 0 ]; then
        update_system
    fi

    install_docker
    install_docker_compose
    create_deploy_user "$username"
    setup_ssh "$username"
    create_directories "$username"
    configure_firewall "$device"

    # Show summary
    show_summary "$device" "$username"

    # Reminder
    static_ip_reminder
}

# Run main
main "$@"
