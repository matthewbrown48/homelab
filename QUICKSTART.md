# Quick Start Guide

Get your homelab up and running in 30 minutes!

## Prerequisites Checklist

- [ ] Raspberry Pi 5 with Open Media Vault installed
- [ ] Raspberry Pi 4
- [ ] PC/Server for Jellyfin
- [ ] All devices connected to network
- [ ] GitHub account
- [ ] Tailscale account (free)

## 5-Minute Setup

### 1. Clone Repository

```bash
cd ~/projects
git clone https://github.com/YOUR_USERNAME/homelab.git
cd homelab
```

### 2. Set Device IPs

Set these environment variables (add to `~/.bashrc` or `~/.zshrc`):

```bash
# Replace with YOUR actual device IPs
export PI5_HOST=10.0.0.10          # Your Pi 5 IP
export PI4_HOST=10.0.0.11          # Your Pi 4 IP
export JELLYFIN_HOST=10.0.0.12     # Your Jellyfin server IP
```

> **Note**: These are example IPs. Use your actual device IPs from your network.

### 3. Setup SSH Keys

```bash
# Generate key
ssh-keygen -t ed25519 -f ~/.ssh/homelab_deploy

# Copy to devices
ssh-copy-id -i ~/.ssh/homelab_deploy pi@$PI5_HOST
ssh-copy-id -i ~/.ssh/homelab_deploy pi@$PI4_HOST
ssh-copy-id -i ~/.ssh/homelab_deploy pi@$JELLYFIN_HOST
```

### 4. Prepare Devices

Run on each device:

```bash
# From your laptop, setup Pi 5
ssh pi@$PI5_HOST "bash -s" < scripts/setup-device.sh pi5-openmediavault

# Setup Pi 4
ssh pi@$PI4_HOST "bash -s" < scripts/setup-device.sh pi4-ci-controller

# Setup Jellyfin
ssh pi@$JELLYFIN_HOST "bash -s" < scripts/setup-device.sh jellyfin-server
```

Or manually on each device:
```bash
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/homelab/main/scripts/setup-device.sh
chmod +x setup-device.sh
sudo ./setup-device.sh DEVICE_NAME
```

### 5. Get Tailscale Auth Key

1. Go to: https://login.tailscale.com/admin/settings/keys
2. Click "Generate auth key"
3. Check ☑ Reusable
4. Copy the key (starts with `tskey-auth-`)

### 6. Configure Services

**On each device**, SSH and configure:

```bash
# Pi 5
ssh deploy@$PI5_HOST
cd /opt/homelab/pi5-openmediavault
cp .env.example .env
nano .env  # Add Tailscale key, set timezone
exit

# Pi 4
ssh deploy@$PI4_HOST
cd /opt/homelab/pi4-ci-controller
cp .env.example .env
nano .env  # Add GitHub OAuth, Tailscale key, secrets
# Create registry auth:
mkdir -p config/registry
docker run --rm --entrypoint htpasswd httpd:alpine -Bbn homelab PASSWORD > config/registry/htpasswd
exit

# Jellyfin
ssh deploy@$JELLYFIN_HOST
cd /opt/homelab/jellyfin-server
cp .env.example .env
nano .env  # Add Tailscale key, domain (optional)
exit
```

### 7. Initial Deployment

From your laptop:

```bash
./scripts/deploy.sh all
```

### 8. Setup GitHub Actions

Push to GitHub:

```bash
git remote add origin https://github.com/YOUR_USERNAME/homelab.git
git push -u origin main
```

Add secrets in GitHub (Settings > Secrets):
- `SSH_PRIVATE_KEY`: Content of `~/.ssh/homelab_deploy`
- `PI5_HOST`: Your Pi 5 IP
- `PI4_HOST`: Your Pi 4 IP
- `JELLYFIN_HOST`: Your Jellyfin IP

### 9. Verify Everything Works

```bash
# Run health check
./scripts/health-check.sh

# Or manually check services:
# Pi 5:
open http://$PI5_HOST:3000  # Homepage
open https://$PI5_HOST:9443 # Portainer

# Pi 4:
open http://$PI4_HOST:8000  # Woodpecker

# Jellyfin:
open http://$JELLYFIN_HOST:8096  # Jellyfin
```

### 10. Test GitOps

Make a change and watch it deploy:

```bash
echo "# Test" >> README.md
git add README.md
git commit -m "Test GitOps deployment"
git push

# Watch: https://github.com/YOUR_USERNAME/homelab/actions
```

## You're Done! 🎉

Your homelab is now:
- ✅ Fully operational
- ✅ Accessible via Tailscale from anywhere
- ✅ Auto-deploying on git push
- ✅ Running CI/CD pipelines
- ✅ Streaming media

## Next Steps

1. **Install Tailscale on your phone/laptop**
   - Download from https://tailscale.com/download
   - Access services via `http://pi5.your-tailnet.ts.net:3000`

2. **Add Media to Jellyfin**
   - Put files on Pi 5 via OMV
   - Scan library in Jellyfin

3. **Configure Woodpecker CI**
   - Login at `http://pi4:8000`
   - Activate your repositories
   - Add `.woodpecker.yml` to your projects

4. **Setup Backups**
   - Configure Duplicati at `http://pi5:8200`
   - Set backup destination (S3, B2, etc.)

5. **Explore Services**
   - Homepage dashboard: See all services
   - Portainer: Manage containers
   - Grafana: Monitor metrics

## Common Post-Setup Tasks

### Add Pi Zero Workers

```bash
# Copy agent config
scp -r devices/pi4-ci-controller/agent-config/ pi@pi-zero-1:~/

# SSH and setup
ssh pi@pi-zero-1
cd agent-config
cp .env.example .env
nano .env  # Configure Pi 4 IP and secrets
docker-compose up -d
```

### Mount NFS Media on Jellyfin

```bash
ssh deploy@$JELLYFIN_HOST
sudo apt install nfs-common
sudo mkdir -p /mnt/media/{movies,tv,music}

# Add to /etc/fstab
echo "$PI5_HOST:/export/movies /mnt/media/movies nfs defaults 0 0" | sudo tee -a /etc/fstab
echo "$PI5_HOST:/export/tv /mnt/media/tv nfs defaults 0 0" | sudo tee -a /etc/fstab

sudo mount -a
```

### Setup GitHub OAuth for Woodpecker

1. Go to https://github.com/settings/developers
2. New OAuth App
3. Homepage: `http://YOUR_PI4_IP:8000`
4. Callback: `http://YOUR_PI4_IP:8000/authorize`
5. Add Client ID & Secret to Pi 4 `.env`

## Troubleshooting

**Service won't start?**
```bash
docker-compose logs SERVICE_NAME
```

**Can't SSH?**
```bash
ssh-copy-id -i ~/.ssh/homelab_deploy deploy@DEVICE_IP
```

**GitHub Actions failing?**
- Check secrets are set correctly
- Verify SSH key is complete (including BEGIN/END lines)

For more help: See [docs/troubleshooting.md](docs/troubleshooting.md)

## Resources

- **Full docs**: [docs/getting-started.md](docs/getting-started.md)
- **Architecture**: [docs/architecture.md](docs/architecture.md)
- **Security**: [docs/security.md](docs/security.md)
- **Device guides**: `devices/*/README.md`

## Daily Workflow

```bash
# Make a change
nano devices/jellyfin-server/docker-compose.yml

# Commit and push
git add .
git commit -m "Add new service"
git push

# GitHub Actions deploys automatically!
# Check: https://github.com/YOUR_USERNAME/homelab/actions
```

That's it! Your entire homelab is now code. 🚀

Questions? Check the docs or GitHub issues!
