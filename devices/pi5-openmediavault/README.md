# Pi 5 - Open Media Vault Configuration

This configuration adds supplementary Docker services to your existing Open Media Vault installation without disrupting OMV's core functionality.

## Services

### Portainer (Port 9443)
- Web UI for managing Docker containers
- Access: `https://<pi5-ip>:9443`
- Manage all homelab containers from one place

### Homepage Dashboard (Port 3000)
- Central dashboard for all homelab services
- Access: `http://<pi5-ip>:3000`
- Shows status of all services across devices

### Duplicati (Port 8200)
- Automated backup solution
- Access: `http://<pi5-ip>:8200`
- Backs up configurations and data to cloud storage

### Tailscale
- Secure remote access VPN
- Runs in host network mode
- Access your homelab from anywhere securely

### Watchtower
- Automatic container updates
- Runs daily at 4 AM (configurable)
- Keeps all containers up-to-date with latest security patches

### Glances
- System resource monitoring
- Access: `http://<pi5-ip>:61208`
- Real-time CPU, memory, disk, network stats

## Setup Instructions

### 1. Find Your OMV Shared Folder Paths

In OMV web interface:
1. Go to **Storage > Shared Folders**
2. Note the absolute paths for your shared folders
3. They usually look like: `/srv/dev-disk-by-uuid-xxxxxx/folder-name`

### 2. Configure Environment

```bash
cd devices/pi5-openmediavault
cp .env.example .env
nano .env
```

Update these values:
- `TZ`: Your timezone
- `OMV_DATA_PATH`: Path to your data shared folder
- `OMV_MEDIA_PATH`: Path to your media shared folder
- `OMV_BACKUPS_PATH`: Path to backups shared folder
- `TAILSCALE_AUTHKEY`: Get from https://login.tailscale.com/admin/settings/keys

### 3. Deploy Services

```bash
# From the repository root
./scripts/deploy.sh pi5-openmediavault

# Or manually on the Pi 5
cd /path/to/homelab/devices/pi5-openmediavault
docker-compose up -d
```

### 4. Initial Configuration

#### Portainer
1. Navigate to `https://<pi5-ip>:9443`
2. Create admin account (first time only)
3. Select "Docker" environment
4. Connect to local Docker socket

#### Duplicati
1. Navigate to `http://<pi5-ip>:8200`
2. Set admin password
3. Configure backup destinations (S3, B2, Google Drive, etc.)
4. Create backup jobs for:
   - Docker configs: `/source/etc`
   - Important data: `/source/data`

#### Homepage
1. Edit `config/homepage/services.yaml` to add your service URLs
2. Restart homepage: `docker-compose restart homepage`

#### Tailscale
1. Check logs: `docker logs tailscale`
2. If needed, authenticate: `docker exec tailscale tailscale up`
3. Access devices via Tailscale name: `homelab-pi5.tailnet-name.ts.net`

## Integration with Existing OMV

### Docker in OMV
- OMV may have a Docker plugin installed - that's fine
- These services run independently using docker-compose
- They coexist peacefully with OMV's Docker management

### Shared Folders Access
- Services access OMV shared folders via bind mounts
- Paths are read-only where appropriate
- No modification to OMV's storage management

### Ports
Make sure these ports don't conflict with existing OMV services:
- 9443 (Portainer)
- 3000 (Homepage)
- 8200 (Duplicati)
- 61208 (Glances)

If conflicts exist, change ports in `.env` file.

## Maintenance

### View Logs
```bash
docker-compose logs -f [service-name]
```

### Update Services
```bash
# Watchtower handles this automatically, but manual update:
docker-compose pull
docker-compose up -d
```

### Backup Configuration
```bash
# Backup docker-compose configs
./scripts/backup.sh pi5-openmediavault

# Duplicati handles data backups automatically
```

### Stop All Services
```bash
docker-compose down
```

### Remove Everything (including volumes)
```bash
docker-compose down -v
```

## Troubleshooting

### Service won't start
```bash
# Check logs
docker-compose logs [service-name]

# Check if port is already in use
sudo netstat -tulpn | grep [port-number]
```

### Permission issues
```bash
# Ensure proper ownership
sudo chown -R 1000:1000 ./config
```

### OMV paths not accessible
```bash
# Verify paths exist
ls -la /srv/dev-disk-by-uuid-*/

# Check in OMV: Storage > Shared Folders > Absolute Path column
```

## Notes

- **OMV Updates**: OMV system updates won't affect these containers
- **Docker Conflicts**: If OMV has Docker plugin, consider disabling it and managing all containers via compose
- **Resource Usage**: Pi 5 has plenty of RAM (8GB), but monitor CPU usage
- **Networking**: All services use bridge network for isolation
- **Auto-start**: Containers restart automatically after reboot
