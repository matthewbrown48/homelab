# Jellyfin Media Server

Complete media streaming setup with Jellyfin, request management, and secure reverse proxy.

## Services

### Jellyfin (Port 8096)
- Main media server
- Stream movies, TV shows, music
- Apps for all platforms
- Access: `http://<server-ip>:8096` or `https://jellyfin.yourdomain.com`

### Jellyseerr (Port 5055)
- Media request management
- Users can request new content
- Integrates with Jellyfin
- Access: `http://<server-ip>:5055` or `https://requests.yourdomain.com`

### Traefik (Ports 80/443/8080)
- Reverse proxy with automatic SSL
- Routes traffic to services
- Dashboard: `http://<server-ip>:8080`

### Transmission (Port 9091) - Optional
- Torrent client
- Automatic download management
- Access: `http://<server-ip>:9091`

## Setup Instructions

### 1. Mount Media from Pi 5 NAS

You need to mount the media folders from your Pi 5 OMV to this server.

#### Option A: NFS Mount (Recommended)

**On Pi 5 (OMV)**:
1. In OMV web UI: Storage > Shared Folders
2. Create shared folders for: movies, tv, music
3. Go to: Services > NFS > Shares
4. Add NFS share for each folder
5. Set permissions: Allow your Jellyfin server's IP

**On Jellyfin Server**:
```bash
# Install NFS client
sudo apt install nfs-common

# Create mount points
sudo mkdir -p /mnt/media/{movies,tv,music,downloads}

# Test mount
sudo mount <pi5-ip>:/export/movies /mnt/media/movies

# Add to /etc/fstab for auto-mount on boot
echo "<pi5-ip>:/export/movies /mnt/media/movies nfs defaults 0 0" | sudo tee -a /etc/fstab
echo "<pi5-ip>:/export/tv /mnt/media/tv nfs defaults 0 0" | sudo tee -a /etc/fstab
echo "<pi5-ip>:/export/music /mnt/media/music nfs defaults 0 0" | sudo tee -a /etc/fstab
```

#### Option B: SMB/CIFS Mount

**On Jellyfin Server**:
```bash
# Install CIFS utils
sudo apt install cifs-utils

# Create credentials file
sudo nano /etc/smbcredentials
# Add:
# username=your-omv-user
# password=your-omv-password

# Secure it
sudo chmod 600 /etc/smbcredentials

# Mount
sudo mkdir -p /mnt/media/{movies,tv,music}

# Add to /etc/fstab
echo "//<pi5-ip>/movies /mnt/media/movies cifs credentials=/etc/smbcredentials,uid=1000,gid=1000 0 0" | sudo tee -a /etc/fstab

# Mount all
sudo mount -a
```

### 2. Configure Environment

```bash
cd devices/jellyfin-server
cp .env.example .env
nano .env
```

Update these values:
- `TZ`: Your timezone
- `MEDIA_*`: Paths to mounted media folders
- `DOMAIN`: Your domain (if using external access)
- `LETSENCRYPT_EMAIL`: Your email for SSL certificates
- `TRANSMISSION_PASS`: Secure password for downloads

### 3. Setup Domain (Optional - for external access)

If you want to access Jellyfin from outside your network:

1. **Get a domain** (or use a free dynamic DNS service)
2. **Point DNS to your IP**:
   - `jellyfin.yourdomain.com` → Your home IP
   - `requests.yourdomain.com` → Your home IP
3. **Port forwarding on router**:
   - Forward ports 80 and 443 to Jellyfin server
4. **Update .env**:
   - Set `DOMAIN=yourdomain.com`
   - Set `LETSENCRYPT_EMAIL=your-email@example.com`

Traefik will automatically get SSL certificates from Let's Encrypt!

### 4. Deploy Services

```bash
# From repository root
./scripts/deploy.sh jellyfin-server

# Or manually
cd devices/jellyfin-server
docker-compose up -d
```

### 5. Initial Jellyfin Setup

1. Navigate to `http://<server-ip>:8096`
2. Select language
3. Create admin account
4. Add media libraries:
   - **Movies**: `/media/movies`
   - **TV Shows**: `/media/tv`
   - **Music**: `/media/music`
5. Configure metadata providers (TMDB, TVDB)
6. Enable hardware transcoding (if supported):
   - Dashboard → Playback → Transcoding
   - Select appropriate hardware acceleration

### 6. Setup Jellyseerr

1. Navigate to `http://<server-ip>:5055`
2. Select Jellyfin
3. Enter Jellyfin URL: `http://jellyfin:8096`
4. Sign in with Jellyfin admin account
5. Sync libraries
6. Configure request settings

## Hardware Transcoding

### Intel/AMD GPU

Uncomment in docker-compose.yml:
```yaml
devices:
  - /dev/dri:/dev/dri
```

In Jellyfin: Dashboard → Playback → Transcoding
- Enable: Intel QuickSync or VAAPI

### NVIDIA GPU

Install nvidia-docker on host, then update docker-compose.yml:
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```

In Jellyfin: Dashboard → Playback → Transcoding
- Enable: NVIDIA NVENC

## External Access Security

### Secure Traefik Dashboard

Edit `config/traefik/traefik.yml`:
```yaml
api:
  dashboard: true
  insecure: false  # Disable insecure access
```

Add basic auth in `config/traefik/dynamic/middleware.yml`:
```yaml
http:
  middlewares:
    traefik-auth:
      basicAuth:
        users:
          - "admin:$apr1$..." # Generate with: htpasswd -n admin
```

### Firewall Rules

```bash
# Allow only necessary ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### VPN Alternative

Instead of exposing to internet, use Tailscale (on Pi 5):
- Access via Tailscale network
- No port forwarding needed
- More secure

## Media Organization

### Recommended Structure

```
/mnt/media/
├── movies/
│   ├── Movie Name (Year)/
│   │   └── Movie Name (Year).mkv
│   └── Another Movie (Year)/
│       └── Another Movie (Year).mp4
├── tv/
│   └── TV Show Name/
│       ├── Season 01/
│       │   ├── S01E01.mkv
│       │   └── S01E02.mkv
│       └── Season 02/
└── music/
    └── Artist/
        └── Album/
            ├── 01 - Track.mp3
            └── 02 - Track.mp3
```

### File Naming Tips

- Use clear names with year: `Movie Name (2024)`
- TV shows: `S01E01` format
- Avoid special characters
- Jellyfin will automatically fetch metadata

## Monitoring

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f jellyfin
docker-compose logs -f traefik
```

### Traefik Dashboard

Access: `http://<server-ip>:8080`
- View routes
- Check SSL certificates
- Monitor traffic

### Jellyfin Dashboard

Access: Jellyfin → Dashboard
- Active streams
- Library scans
- Transcoding activity
- User activity

## Maintenance

### Update Media Libraries

Jellyfin auto-scans, but for manual:
1. Dashboard → Scheduled Tasks
2. Run "Scan Media Libraries"

### Backup Configuration

```bash
# Backup volumes
docker run --rm \
  -v jellyfin_config:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/jellyfin-config.tar.gz /data
```

### Clean Transcoding Cache

```bash
# Stop Jellyfin
docker-compose stop jellyfin

# Clean cache
docker exec jellyfin rm -rf /cache/transcoding-temp/*

# Start Jellyfin
docker-compose start jellyfin
```

## Troubleshooting

### Can't access media files

```bash
# Check mounts
mount | grep media

# Verify permissions
ls -la /mnt/media/

# Test from container
docker exec jellyfin ls -la /media/movies/
```

### Transcoding fails

```bash
# Check Jellyfin logs
docker logs jellyfin

# Verify hardware access (if using GPU)
docker exec jellyfin ls -la /dev/dri/

# Test ffmpeg in container
docker exec jellyfin ffmpeg -version
```

### SSL certificate issues

```bash
# Check Traefik logs
docker logs traefik

# Verify Let's Encrypt reached
# Ensure ports 80/443 are accessible from internet

# Check certificate resolver
docker exec traefik cat /acme/acme.json
```

### Network issues

```bash
# Check service connectivity
docker exec jellyseerr ping jellyfin

# Verify networks
docker network ls
docker network inspect traefik-network
```

## Performance Tips

### For Raspberry Pi/ARM

- Use hardware transcoding if available
- Limit simultaneous streams (2-3 max)
- Pre-transcode high-bitrate content
- Use lower quality for remote streaming

### For x86 Server

- Enable hardware transcoding
- More concurrent streams possible
- Higher quality transcoding
- Can handle 4K content

## Adding More Services

Want to add Radarr, Sonarr, or other *arr apps?

Create new services in docker-compose.yml:
```yaml
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    networks:
      - traefik
    volumes:
      - radarr_config:/config
      - ${MEDIA_MOVIES}:/movies
      - ${DOWNLOADS_PATH}:/downloads
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.radarr.rule=Host(`radarr.${DOMAIN}`)"
```

## Next Steps

1. Add your media to Pi 5 OMV
2. Configure Jellyfin libraries
3. Setup Jellyseerr for requests
4. Invite users to access
5. Enjoy your media!
