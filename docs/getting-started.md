# Getting Started with Your GitOps Homelab

Step-by-step guide to set up your entire homelab infrastructure.

> **📝 Note on Example Values**: This guide uses example IP addresses like `192.168.1.100`. Replace these with your actual device IPs. Domain names like `yourdomain.com` should be replaced with your actual domain if you have one.

## Overview

You'll be setting up:
- **Pi 5**: NAS with OMV + supplementary services
- **Pi 4 + Pi Zeros**: Distributed CI/CD cluster with Woodpecker CI
- **Jellyfin Server**: Media streaming with Traefik reverse proxy
- **Tailscale**: Secure remote access to everything

## Prerequisites

### Hardware
- [ ] Raspberry Pi 5 (with OMV already installed)
- [ ] Raspberry Pi 4
- [ ] Pi Zero(s) (as many as you want for CI workers)
- [ ] PC/Server for Jellyfin
- [ ] Network connectivity for all devices
- [ ] Storage for media (connected to Pi 5 via OMV)

### Accounts
- [ ] GitHub account
- [ ] Tailscale account (free): https://tailscale.com
- [ ] Domain name (optional, for external access)

### Your Workstation
- [ ] Git installed
- [ ] SSH client
- [ ] Text editor (VSCode recommended)

## Phase 1: Repository Setup

### 1. Fork/Clone Repository

```bash
# Clone this repo to your workstation
git clone https://github.com/YOUR_USERNAME/homelab.git
cd homelab

# Or if you're starting fresh, this IS your repo!
# Just initialize it:
git add .
git commit -m "Initial homelab configuration"
```

### 2. Create GitHub Repository

1. Go to https://github.com/new
2. Name it `homelab`
3. Make it **private** (contains your infrastructure!)
4. Don't initialize with README (we have one)
5. Push your code:

```bash
git remote add origin https://github.com/YOUR_USERNAME/homelab.git
git branch -M main
git push -u origin main
```

## Phase 2: Device Preparation

### Set Static IPs

**Critical**: All devices need static IPs or reserved DHCP leases.

**Option A - DHCP Reservation (Recommended)**:
1. Log into your router
2. Find each device's MAC address
3. Reserve IP addresses for each:
   - Pi 5: `192.168.1.100` (example)
   - Pi 4: `192.168.1.101`
   - Jellyfin: `192.168.1.102`
   - Pi Zeros: `192.168.1.110-119`

**Option B - Static IP on device**:
```bash
# On each device, edit netplan (Ubuntu) or /etc/network/interfaces (Debian)
sudo nano /etc/netplan/01-netcfg.yaml
```

### Device Inventory

Create a file locally with your device information:

```
# My Homelab Devices

Pi 5 (OMV):
  IP: 192.168.1.100
  Hostname: pi5.local
  User: deploy

Pi 4 (CI):
  IP: 192.168.1.101
  Hostname: pi4.local
  User: deploy

Jellyfin Server:
  IP: 192.168.1.102
  Hostname: jellyfin.local
  User: deploy

Pi Zeros:
  Worker 1: 192.168.1.110
  Worker 2: 192.168.1.111
  Worker 3: 192.168.1.112
```

## Phase 3: Initial Device Setup

### Run Setup Script on Each Device

**On each device (Pi 5, Pi 4, Jellyfin server):**

1. **SSH into device**:
```bash
ssh pi@192.168.1.100  # or whatever user exists
```

2. **Download and run setup script**:
```bash
# Get the script
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/homelab/main/scripts/setup-device.sh

# Make executable
chmod +x setup-device.sh

# Run it (requires sudo)
sudo ./setup-device.sh pi5-openmediavault  # Use appropriate device name
```

This script will:
- Update system packages
- Install Docker and Docker Compose
- Create `deploy` user
- Set up SSH directory
- Configure firewall
- Create deployment directories

3. **Add your SSH key**:

From your workstation:
```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -f ~/.ssh/homelab_deploy

# Copy to each device
ssh-copy-id -i ~/.ssh/homelab_deploy deploy@192.168.1.100
ssh-copy-id -i ~/.ssh/homelab_deploy deploy@192.168.1.101
ssh-copy-id -i ~/.ssh/homelab_deploy deploy@192.168.1.102
```

## Phase 4: Tailscale Setup

### 1. Create Tailscale Account

1. Go to https://tailscale.com
2. Sign up (free for personal use)
3. Verify email

### 2. Generate Auth Keys

1. Go to https://login.tailscale.com/admin/settings/keys
2. Click "Generate auth key..."
3. Settings:
   - ☑ Reusable
   - ☑ Ephemeral (optional)
   - Expiration: 90 days
4. Click "Generate key"
5. **Save this key** - you'll need it for each device!

### 3. Install Tailscale on Your Devices

**Option A - Docker (Recommended, already in configs)**:
- The docker-compose files already include Tailscale!
- You'll add the auth key to `.env` files later

**Option B - Native Installation**:
```bash
# On each device
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### 4. Install on Your Personal Devices

- **Phone**: Install Tailscale app from store
- **Laptop**: Download from https://tailscale.com/download
- **Tablet**: Install from app store

Now all your devices can access your homelab securely!

## Phase 5: Configure Services

### Pi 5 - Open Media Vault

1. **Find OMV shared folder paths**:
```bash
# SSH to Pi 5
ssh deploy@192.168.1.100

# List shared folders
ls -la /srv/dev-disk-by-uuid-*/

# Note the paths, you'll need them
```

2. **Configure environment**:
```bash
cd /opt/homelab/pi5-openmediavault
cp .env.example .env
nano .env

# Update:
# - TZ (your timezone)
# - OMV_*_PATH (shared folder paths from step 1)
# - TAILSCALE_AUTHKEY (from Tailscale)
```

3. **Deploy**:
```bash
docker-compose up -d
```

4. **Verify**:
```bash
docker-compose ps  # All should be "Up"

# Access services:
# Portainer: https://<pi5-ip>:9443
# Homepage: http://<pi5-ip>:3000
```

### Pi 4 - Woodpecker CI

1. **Create GitHub OAuth App**:
   - Go to https://github.com/settings/developers
   - "New OAuth App"
   - Name: `Homelab Woodpecker CI`
   - Homepage: `http://192.168.1.101:8000`
   - Callback: `http://192.168.1.101:8000/authorize`
   - Save Client ID and Secret

2. **Generate secrets**:
```bash
# Agent secret
openssl rand -hex 32

# Registry password
openssl rand -base64 32
```

3. **Create registry auth**:
```bash
ssh deploy@192.168.1.101
cd /opt/homelab/pi4-ci-controller
mkdir -p config/registry

# Create htpasswd file
docker run --rm --entrypoint htpasswd httpd:alpine \
  -Bbn homelab YOUR_REGISTRY_PASSWORD > config/registry/htpasswd
```

4. **Configure environment**:
```bash
cd /opt/homelab/pi4-ci-controller
cp .env.example .env
nano .env

# Update all variables:
# - GitHub OAuth credentials
# - Agent secret
# - Database password
# - Tailscale auth key
```

5. **Deploy**:
```bash
docker-compose up -d
```

6. **Access Woodpecker**:
```bash
# Open: http://192.168.1.101:8000
# Login with GitHub
# Activate your repositories
```

### Jellyfin Server

1. **Mount media from Pi 5**:

**Using NFS (Recommended)**:
```bash
# On Pi 5: Configure NFS exports in OMV web UI
# Services > NFS > Shares

# On Jellyfin server:
sudo apt install nfs-common
sudo mkdir -p /mnt/media/{movies,tv,music}

# Test mount
sudo mount 192.168.1.100:/export/movies /mnt/media/movies

# Add to /etc/fstab for auto-mount
echo "192.168.1.100:/export/movies /mnt/media/movies nfs defaults 0 0" | sudo tee -a /etc/fstab
echo "192.168.1.100:/export/tv /mnt/media/tv nfs defaults 0 0" | sudo tee -a /etc/fstab
echo "192.168.1.100:/export/music /mnt/media/music nfs defaults 0 0" | sudo tee -a /etc/fstab

# Mount all
sudo mount -a
```

2. **Configure environment**:
```bash
cd /opt/homelab/jellyfin-server
cp .env.example .env
nano .env

# Update:
# - MEDIA_* paths to your NFS mounts
# - DOMAIN (if using external access)
# - LETSENCRYPT_EMAIL
# - Tailscale auth key
```

3. **Deploy**:
```bash
docker-compose up -d
```

4. **Setup Jellyfin**:
```bash
# Access: http://192.168.1.102:8096
# Follow setup wizard
# Add libraries pointing to /media/movies, /media/tv, etc.
```

## Phase 6: GitHub Actions Setup

### 1. Add GitHub Secrets

In your GitHub repository:
1. Go to Settings > Secrets and variables > Actions
2. Click "New repository secret"
3. Add these secrets:

```
SSH_PRIVATE_KEY = [contents of ~/.ssh/homelab_deploy]
PI5_HOST = 192.168.1.100
PI4_HOST = 192.168.1.101
JELLYFIN_HOST = 192.168.1.102
```

To get SSH private key contents:
```bash
cat ~/.ssh/homelab_deploy
# Copy everything including -----BEGIN and -----END lines
```

### 2. Create Environments

1. Go to Settings > Environments
2. Create three environments:
   - `pi5-production`
   - `pi4-production`
   - `jellyfin-production`
3. Optionally add protection rules (require approvals for deployments)

### 3. Test GitHub Actions

```bash
# Make a small change
echo "# Test" >> README.md
git add README.md
git commit -m "Test GitHub Actions"
git push

# Watch workflow run at:
# https://github.com/YOUR_USERNAME/homelab/actions
```

## Phase 7: Pi Zero Workers (Optional)

For each Pi Zero CI worker:

1. **Setup Docker**:
```bash
ssh pi@pi-zero-1
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker pi
```

2. **Deploy agent**:
```bash
# Copy agent config from repo
scp -r devices/pi4-ci-controller/agent-config/ pi@pi-zero-1:~/

ssh pi@pi-zero-1
cd agent-config
cp .env.example .env
nano .env

# Set:
# - PI4_CONTROLLER_IP
# - WOODPECKER_AGENT_SECRET (same as Pi 4)
# - WOODPECKER_HOSTNAME (unique: pi-zero-1, pi-zero-2, etc.)

docker-compose up -d
```

3. **Verify in Woodpecker UI**:
   - Go to Admin > Agents
   - Should see your new agent listed

Repeat for additional Pi Zeros!

## Phase 8: Verification

### Check All Services

```bash
# Run health check script
./scripts/health-check.sh
```

Or manually:
- [ ] Pi 5 Portainer: `https://192.168.1.100:9443`
- [ ] Pi 5 Homepage: `http://192.168.1.100:3000`
- [ ] Pi 4 Woodpecker: `http://192.168.1.101:8000`
- [ ] Pi 4 Registry UI: `http://192.168.1.101:5001`
- [ ] Jellyfin: `http://192.168.1.102:8096`
- [ ] Traefik Dashboard: `http://192.168.1.102:8080`

### Test Tailscale Access

On your phone/laptop with Tailscale:
- [ ] Connect to Tailscale
- [ ] Access: `http://pi5.your-tailnet.ts.net:3000`
- [ ] Access: `http://jellyfin-server.your-tailnet.ts.net:8096`

### Test GitOps Deployment

```bash
# Make a change to any device config
cd devices/pi5-openmediavault
# Edit docker-compose.yml (add a comment or change)

git add .
git commit -m "Test deployment"
git push

# Watch GitHub Actions deploy it automatically!
```

## What You Have Now

🎉 **Congratulations!** You now have:

- ✅ GitOps-managed infrastructure (everything in code)
- ✅ Automatic deployments via GitHub Actions
- ✅ Secure remote access via Tailscale
- ✅ CI/CD pipeline with Woodpecker
- ✅ Media server with Jellyfin
- ✅ NAS with Open Media Vault
- ✅ Container management via Portainer
- ✅ Automatic updates with Watchtower
- ✅ Monitoring dashboards
- ✅ Version control for all configs

## Next Steps

1. **Add Media**: Put media files on Pi 5 OMV
2. **Configure Jellyseerr**: Set up media requests
3. **Create Woodpecker Pipelines**: Add `.woodpecker.yml` to your projects
4. **Setup Monitoring**: Configure Grafana dashboards
5. **Backups**: Configure Duplicati backup schedules
6. **Explore**: Add more services as needed!

## Daily Workflow

### Making Changes

```bash
# 1. Create branch
git checkout -b feature/add-service

# 2. Edit configs
nano devices/jellyfin-server/docker-compose.yml

# 3. Test locally (optional)
cd devices/jellyfin-server
docker-compose config  # Validate

# 4. Commit and push
git add .
git commit -m "Add new service"
git push origin feature/add-service

# 5. Create PR on GitHub
# 6. Review, merge to main
# 7. GitHub Actions deploys automatically!
```

### Accessing Services

**Local network**:
- `http://192.168.1.100:port`

**From anywhere (Tailscale)**:
- `http://device-name.your-tailnet.ts.net:port`

## Troubleshooting

See [docs/troubleshooting.md](./troubleshooting.md) for common issues.

## Questions?

- Check [README.md](../README.md)
- Review [security.md](./security.md)
- Look at device-specific READMEs in `devices/*/README.md`

Happy homelabbing! 🚀
