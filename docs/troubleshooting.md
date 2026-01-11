# Troubleshooting Guide

Common issues and solutions for your homelab.

> **📝 Note**: This guide uses example IP addresses (e.g., `192.168.1.100`). Replace with your actual device IPs.

## General Debugging

### Check Service Status

```bash
# On any device, in the docker-compose directory
docker-compose ps

# View logs
docker-compose logs -f [service-name]

# Restart service
docker-compose restart [service-name]

# Full restart
docker-compose down && docker-compose up -d
```

### Network Connectivity

```bash
# Ping device
ping 192.168.1.100

# Check if port is open
telnet 192.168.1.100 8096
# or
nc -zv 192.168.1.100 8096

# Check Tailscale connectivity
tailscale status
tailscale ping pi5
```

### Docker Issues

```bash
# Check Docker is running
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Check disk space
df -h

# Clean up Docker
docker system prune -a

# Check Docker logs
sudo journalctl -u docker -n 100
```

## Device-Specific Issues

### Pi 5 - Open Media Vault

#### Portainer won't start

```bash
# Check if port 9443 is in use
sudo netstat -tulpn | grep 9443

# Check Docker socket permissions
ls -la /var/run/docker.sock

# Recreate container
docker-compose up -d --force-recreate portainer
```

#### Can't access OMV shared folders from containers

```bash
# Verify paths exist
ls -la /srv/dev-disk-by-uuid-*/

# Check in OMV UI: Storage > Shared Folders
# Note the "Absolute Path" column

# Update .env file with correct paths
nano .env

# Redeploy
docker-compose up -d
```

#### Duplicati backup fails

```bash
# Check logs
docker logs duplicati

# Verify source paths are readable
docker exec duplicati ls -la /source/data

# Check destination credentials
# In Duplicati UI: test connection to backup destination
```

### Pi 4 - CI Controller

#### Woodpecker won't start

```bash
# Check database is healthy
docker logs woodpecker-postgres

# Check database connection
docker exec woodpecker-postgres psql -U woodpecker -c "\l"

# Reset Woodpecker
docker-compose down
docker volume rm woodpecker_postgres  # WARNING: Deletes data!
docker-compose up -d
```

#### Agents not connecting

```bash
# On Pi 4: Check server is listening
docker logs woodpecker-server | grep gRPC

# On agent: Check it can reach server
telnet 192.168.1.101 9000

# Verify agent secret matches
# Pi 4: cat .env | grep AGENT_SECRET
# Agent: cat .env | grep AGENT_SECRET
# They must match!

# Check agent logs
docker logs woodpecker-agent
```

#### Docker Registry authentication fails

```bash
# Recreate htpasswd file
mkdir -p config/registry
docker run --rm --entrypoint htpasswd httpd:alpine \
  -Bbn homelab NEW_PASSWORD > config/registry/htpasswd

# Restart registry
docker-compose restart registry

# Test login
docker login 192.168.1.101:5000
```

#### GitHub OAuth not working

```bash
# Verify callback URL matches exactly
# GitHub OAuth app callback: http://192.168.1.101:8000/authorize
# WOODPECKER_HOST in .env: http://192.168.1.101:8000

# Check logs
docker logs woodpecker-server | grep -i oauth

# Regenerate GitHub OAuth secret
# Update .env
# Restart: docker-compose restart woodpecker-server
```

### Jellyfin Server

#### Media files not showing

```bash
# Check NFS mounts
mount | grep nfs

# Test mount manually
sudo mount -t nfs 192.168.1.100:/export/movies /mnt/media/movies

# Check from container
docker exec jellyfin ls -la /media/movies

# Trigger library scan in Jellyfin UI
# Dashboard > Scheduled Tasks > Scan Media Libraries
```

#### Traefik can't get SSL certificates

```bash
# Check Traefik logs
docker logs traefik

# Verify ports 80 and 443 are accessible from internet
# Use: https://www.yougetsignal.com/tools/open-ports/

# Check DNS points to your IP
nslookup jellyfin.yourdomain.com

# Verify ACME JSON permissions
docker exec traefik ls -la /acme/acme.json

# Clear and retry
docker-compose down
sudo rm -rf traefik_acme  # Clear Let's Encrypt data
docker-compose up -d
```

#### Transcoding fails

```bash
# Check hardware acceleration
docker exec jellyfin ls -la /dev/dri

# Check ffmpeg works
docker exec jellyfin ffmpeg -version

# Disable hardware transcoding in Jellyfin
# Dashboard > Playback > Transcoding
# Set to "None"

# Check CPU/RAM usage
docker stats jellyfin
```

## Tailscale Issues

### Device not appearing in Tailscale

```bash
# Check Tailscale container
docker logs tailscale

# Check authentication
docker exec tailscale tailscale status

# Re-authenticate
docker exec tailscale tailscale up --authkey=tskey-your-key-here

# Check it's running
docker exec tailscale tailscale status
```

### Can't reach device via Tailscale

```bash
# On the device having issues
docker exec tailscale tailscale ping <other-device>

# Check Tailscale routes
docker exec tailscale tailscale status

# Restart Tailscale
docker-compose restart tailscale

# Check firewall isn't blocking
sudo ufw status
```

## GitHub Actions Issues

### Deployment fails with SSH error

```bash
# Check SSH private key is correct in GitHub Secrets
# It should start with -----BEGIN OPENSSH PRIVATE KEY-----

# Test SSH manually
ssh -i ~/.ssh/homelab_deploy deploy@192.168.1.100

# Check known_hosts
# GitHub Actions runs: ssh-keyscan -H 192.168.1.100
```

### "Cannot detect changes" or workflow not triggering

```bash
# Check .github/workflows/deploy.yml paths match
# paths:
#   - 'devices/**'

# Ensure you're pushing to main branch
git branch  # Should show * main

# Check GitHub Actions is enabled
# Repo Settings > Actions > Allow all actions
```

### Deployment succeeds but service not updated

```bash
# SSH to device
ssh deploy@192.168.1.100

# Check if files were synced
ls -la /opt/homelab/pi5-openmediavault/

# Manually pull and restart
cd /opt/homelab/pi5-openmediavault
docker-compose pull
docker-compose up -d

# Check logs
docker-compose logs -f
```

## Script Issues

### deploy.sh fails

```bash
# Check you're in repo root
cd /path/to/homelab

# Make script executable
chmod +x scripts/deploy.sh

# Run with verbose output
bash -x scripts/deploy.sh pi5-openmediavault

# Check SSH works
ssh deploy@192.168.1.100 "echo success"
```

### setup-device.sh fails

```bash
# Must run with sudo
sudo ./setup-device.sh pi5-openmediavault

# Check internet connectivity
ping 8.8.8.8

# Manually install Docker if script fails
curl -fsSL https://get.docker.com | sh
```

## Performance Issues

### High CPU usage

```bash
# Check what's using CPU
docker stats

# Check host CPU
htop

# Limit container resources in docker-compose.yml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 512M
```

### High memory usage

```bash
# Check memory usage
free -h
docker stats

# Clear Docker cache
docker system prune -a

# Reduce concurrent jobs (Woodpecker)
# Edit .env: WOODPECKER_MAX_WORKFLOWS=1
```

### Slow network transfers

```bash
# Test network speed between devices
# Install iperf3 on both devices
iperf3 -s  # On server
iperf3 -c 192.168.1.100  # On client

# Check for network errors
ip -s link

# Check MTU settings
ip link show
```

## Data Loss / Recovery

### Restore from backup

```bash
# If using Duplicati
# Access Duplicati UI: http://pi5:8200
# Restore > Select backup > Choose files > Restore

# Manual volume restore
docker run --rm \
  -v volume_name:/data \
  -v $(pwd)/backup:/backup \
  alpine \
  sh -c "cd /data && tar xzf /backup/backup.tar.gz"
```

### Recreate from Git

```bash
# Everything is in Git!
git clone https://github.com/YOUR_USERNAME/homelab.git
cd homelab/devices/DEVICE_NAME

# Copy .env from backup or recreate from .env.example
cp .env.example .env
nano .env  # Configure

# Deploy
docker-compose up -d

# Only data volumes are lost - configs are restored!
```

### Container won't start after update

```bash
# Rollback to previous version
docker-compose down
git log --oneline  # Find previous commit
git checkout COMMIT_HASH

# Redeploy
docker-compose up -d

# Or specify image version in docker-compose.yml
image: jellyfin/jellyfin:10.8.13  # Pin version
```

## Getting Help

### Collect Debug Information

```bash
# System info
uname -a
cat /etc/os-release

# Docker info
docker --version
docker-compose --version
docker info

# Service status
docker-compose ps
docker-compose logs --tail=50

# Resource usage
free -h
df -h
docker stats --no-stream
```

### Where to Ask

1. **Check logs first**: `docker-compose logs`
2. **Device READMEs**: `devices/*/README.md`
3. **GitHub Issues**: Project-specific issues
4. **r/selfhosted**: General homelab help
5. **r/homelab**: Infrastructure discussions
6. **Discord/Forums**: Tool-specific communities

## Prevention

### Regular Maintenance

```bash
# Weekly
- Check disk space: df -h
- Review logs for errors: docker-compose logs | grep -i error
- Verify backups are running

# Monthly
- Update containers: docker-compose pull && docker-compose up -d
- Review security updates: apt update && apt list --upgradable
- Test restore from backup

# Quarterly
- Rotate secrets/passwords
- Review firewall rules
- Clean up old Docker images: docker system prune -a
```

### Monitoring

```bash
# Setup alerts
- Uptime Kuma for service monitoring
- Disk space alerts
- Failed backup notifications

# Regular checks
- Tailscale connectivity
- GitHub Actions passing
- Service health checks: ./scripts/health-check.sh
```

## Still Stuck?

1. Check the official docs for the specific tool
2. Search GitHub issues in this repo
3. Review the architecture docs: `docs/architecture.md`
4. Enable verbose logging in problematic service
5. Try recreating from scratch (GitOps makes this easy!)

Remember: With GitOps, you can always `git revert` and redeploy!
