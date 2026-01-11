# Ansible Playbooks

Ansible automation for managing homelab devices.

## Prerequisites

```bash
# Install Ansible
pip install ansible

# Install required collections
ansible-galaxy collection install community.docker
```

## Inventory

The inventory is defined in `inventory.yml`. It uses environment variables for device IPs:

```bash
export PI5_HOST=192.168.1.100
export PI4_HOST=192.168.1.101
export JELLYFIN_HOST=192.168.1.102
```

Or add to your `~/.bashrc` or `~/.zshrc`.

## Playbooks

### 1. setup-docker.yml

Installs Docker and Docker Compose on all devices.

```bash
# Run on all devices
ansible-playbook setup-docker.yml

# Run on specific device
ansible-playbook setup-docker.yml --limit pi5-omv

# Check what would change (dry run)
ansible-playbook setup-docker.yml --check
```

### 2. deploy-compose.yml

Deploys docker-compose stacks to devices.

```bash
# Deploy to all devices
ansible-playbook deploy-compose.yml

# Deploy to specific group
ansible-playbook deploy-compose.yml --limit media

# Deploy to single device
ansible-playbook deploy-compose.yml --limit jellyfin
```

## Usage Examples

### Initial Setup

```bash
# 1. Set environment variables
export PI5_HOST=192.168.1.100
export PI4_HOST=192.168.1.101
export JELLYFIN_HOST=192.168.1.102

# 2. Test connectivity
ansible all -m ping

# 3. Install Docker on all devices
ansible-playbook setup-docker.yml

# 4. Deploy configurations
ansible-playbook deploy-compose.yml
```

### Updating a Single Device

```bash
# Update just Jellyfin server
ansible-playbook deploy-compose.yml --limit jellyfin
```

### Running Ad-hoc Commands

```bash
# Check Docker version on all hosts
ansible all -m command -a "docker --version"

# Check disk usage
ansible all -m command -a "df -h"

# Restart a service
ansible jellyfin -m command -a "docker-compose restart jellyfin" --become

# View logs
ansible pi4-ci -m command -a "docker logs woodpecker-server" --become
```

## Inventory Groups

- **homelab**: All devices
  - **nas**: Pi 5 OMV
  - **ci_cd**: Pi 4 CI controller
  - **media**: Jellyfin server

## Variables

Device-specific variables in inventory:
- `ansible_host`: Device IP/hostname
- `device_type`: Type of device configuration
- `deploy_path`: Where to deploy on the device

## Tips

### SSH Key Setup

```bash
# Generate SSH key for Ansible
ssh-keygen -t ed25519 -f ~/.ssh/homelab_deploy

# Copy to all devices
ssh-copy-id -i ~/.ssh/homelab_deploy deploy@pi5.local
ssh-copy-id -i ~/.ssh/homelab_deploy deploy@pi4.local
ssh-copy-id -i ~/.ssh/homelab_deploy deploy@jellyfin.local
```

### Limiting Execution

```bash
# By host
--limit pi5-omv

# By group
--limit nas

# Multiple hosts
--limit "pi5-omv,pi4-ci"
```

### Verbose Output

```bash
# Basic verbosity
ansible-playbook deploy-compose.yml -v

# More verbosity
ansible-playbook deploy-compose.yml -vvv
```

## Integration with GitHub Actions

Ansible playbooks can be triggered from GitHub Actions:

```yaml
- name: Run Ansible Playbook
  run: |
    pip install ansible
    ansible-galaxy collection install community.docker
    ansible-playbook ansible/deploy-compose.yml --limit jellyfin
```

## Troubleshooting

### Connection Issues

```bash
# Test SSH connection
ansible all -m ping -vvv

# Check inventory
ansible-inventory --list
```

### Permission Issues

```bash
# Ensure deploy user is in docker group
ansible all -m command -a "groups deploy"

# Reset permissions
ansible all -m file -a "path=/opt/homelab owner=deploy group=deploy mode=0755" --become
```

### .env Configuration

The playbooks will create `.env` from `.env.example` if missing, but you'll need to configure it manually:

```bash
# SSH to device and edit .env
ssh deploy@pi5.local
cd /opt/homelab/pi5-openmediavault
nano .env
```

## Next Steps

1. Configure inventory with your device IPs
2. Setup SSH keys
3. Run `setup-docker.yml` to install Docker
4. Configure `.env` files on each device
5. Run `deploy-compose.yml` to deploy services
6. Use `ansible all -m ping` to verify everything works
