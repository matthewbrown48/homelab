# Homelab Security Guide

Comprehensive security guide for accessing your homelab from anywhere safely.

> **📝 Note**: Replace all example IPs (e.g., `192.168.1.100`) and domains with your actual values.

## Security Layers

```
┌─────────────────────────────────────────┐
│  1. VPN Layer (Tailscale/WireGuard)    │  ← First line of defense
├─────────────────────────────────────────┤
│  2. Firewall (UFW + Fail2Ban)          │  ← Block bad actors
├─────────────────────────────────────────┤
│  3. Reverse Proxy (Traefik + SSL)      │  ← Encrypted traffic
├─────────────────────────────────────────┤
│  4. Authentication (Authelia + 2FA)    │  ← User verification
├─────────────────────────────────────────┤
│  5. Network Isolation (Docker)         │  ← Container separation
├─────────────────────────────────────────┤
│  6. Secrets Management                 │  ← No hardcoded passwords
└─────────────────────────────────────────┘
```

## Remote Access Options

### Option 1: Tailscale VPN (Recommended)

**Why it's the best for homelab**:
- ✅ Zero configuration NAT traversal
- ✅ No port forwarding needed
- ✅ Encrypted mesh network
- ✅ Works from anywhere
- ✅ Free for personal use (up to 100 devices)
- ✅ Already configured on Pi 5!

**Setup**:

1. **Install on all devices**:
```bash
# Already in Pi 5 docker-compose.yml!
# For Pi 4 and Jellyfin, add to their docker-compose.yml:

tailscale:
  image: tailscale/tailscale:latest
  container_name: tailscale
  restart: unless-stopped
  network_mode: host
  privileged: true
  volumes:
    - tailscale_data:/var/lib/tailscale
    - /dev/net/tun:/dev/net/tun
  environment:
    - TS_AUTHKEY=${TAILSCALE_AUTHKEY}
    - TS_HOSTNAME=<device-name>
  cap_add:
    - NET_ADMIN
    - SYS_MODULE
```

2. **Get auth key**: https://login.tailscale.com/admin/settings/keys

3. **Access services**:
```
# Instead of:
http://192.168.1.100:8096

# Use:
http://pi5.your-tailnet.ts.net:8096
http://jellyfin.your-tailnet.ts.net:8096
```

4. **Install Tailscale on your devices**:
- Phone: App store
- Laptop: https://tailscale.com/download
- Tablet: App store

**Access from anywhere**: Just connect to Tailscale, access homelab!

### Option 2: Cloudflare Tunnel

**Pros**:
- No ports exposed
- DDoS protection
- Cloudflare CDN
- Free tier

**Setup**:
```yaml
# Add to jellyfin-server/docker-compose.yml

cloudflared:
  image: cloudflare/cloudflared:latest
  container_name: cloudflared
  restart: unless-stopped
  command: tunnel --no-autoupdate run
  environment:
    - TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}
  networks:
    - homelab
```

Get token from: https://one.dash.cloudflare.com/

### Option 3: WireGuard VPN (Self-hosted)

**Pros**:
- Full control
- Very fast
- Industry-standard encryption

**Cons**:
- One port to expose (51820/udp)
- Manual client config

**Already included** in `devices/shared/security/docker-compose.yml`!

## Security Hardening

### 1. Enable 2FA with Authelia

**Add to jellyfin-server** for protected external access:

```yaml
# In docker-compose.yml, add to Traefik labels:
labels:
  - "traefik.http.routers.jellyfin.middlewares=authelia@docker"
```

**Configure Authelia**:
```bash
mkdir -p devices/shared/security/config/authelia
```

Create `configuration.yml`:
```yaml
server:
  host: 0.0.0.0
  port: 9091

log:
  level: info

authentication_backend:
  file:
    path: /config/users_database.yml

access_control:
  default_policy: deny
  rules:
    - domain: jellyfin.yourdomain.com
      policy: two_factor

session:
  name: authelia_session
  domain: yourdomain.com
  expiration: 3600
  inactivity: 300

storage:
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notification.txt
```

### 2. Fail2Ban Protection

Blocks IPs after failed login attempts. Already in `shared/security/`!

**Deploy on Jellyfin server**:
```bash
cd devices/shared/security
docker-compose up -d fail2ban
```

### 3. CrowdSec - Collaborative Security

Community-driven threat intelligence.

**Already configured** in `shared/security/docker-compose.yml`.

### 4. Firewall Rules (UFW)

**On each device**:
```bash
# Default deny
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (from Tailscale network only if using VPN)
sudo ufw allow 22/tcp

# If using WireGuard
sudo ufw allow 51820/udp

# If exposing Traefik to internet (only if NOT using VPN)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable
sudo ufw enable
```

### 5. SSH Hardening

**On all devices** (`/etc/ssh/sshd_config`):
```bash
# Disable password auth
PasswordAuthentication no

# Disable root login
PermitRootLogin no

# Only allow specific user
AllowUsers deploy

# Change default port (optional)
Port 2222

# Restart SSH
sudo systemctl restart sshd
```

### 6. Docker Security

**Already implemented**:
```yaml
security_opt:
  - no-new-privileges:true

# Read-only where possible
volumes:
  - ./config:/config:ro

# User namespaces
user: "1000:1000"
```

### 7. Secrets Management

**Never commit**:
- `.env` files
- API keys
- Passwords
- Certificates

**Use**:
- GitHub Secrets (for CI/CD)
- `.env` files (gitignored)
- Docker secrets (production)

**Rotate secrets regularly**:
```bash
# Generate strong passwords
openssl rand -base64 32

# Update .env files
# Redeploy services
```

## Monitoring & Alerts

### 1. Setup Uptime Monitoring

Add to Pi 5:
```yaml
uptime-kuma:
  image: louislam/uptime-kuma:1
  container_name: uptime-kuma
  volumes:
    - uptime_data:/app/data
  ports:
    - "3001:3001"
  restart: unless-stopped
```

Access: `http://pi5:3001`

Configure alerts:
- Email notifications
- Discord/Slack webhooks
- Monitor all services

### 2. Log Monitoring

**Centralized logging**:
```yaml
loki:
  image: grafana/loki:latest
  ports:
    - "3100:3100"
  volumes:
    - loki_data:/loki

promtail:
  image: grafana/promtail:latest
  volumes:
    - /var/log:/var/log:ro
    - ./promtail-config.yml:/etc/promtail/config.yml
```

### 3. Intrusion Detection

**CrowdSec** already monitors for:
- Brute force attempts
- Scanning activity
- Known attack patterns

View dashboard:
```bash
docker exec crowdsec cscli metrics
```

## Recommended Setup for Remote Access

### Scenario 1: Maximum Security (Recommended)

**Stack**:
1. Tailscale on all devices
2. Fail2Ban on exposed devices
3. SSH key auth only
4. UFW firewall blocking everything except Tailscale
5. No ports forwarded on router

**Access**:
- Connect to Tailscale from phone/laptop
- Access services directly: `http://device.tailnet.ts.net:port`

**Pros**:
- ✅ Most secure
- ✅ Simple to use
- ✅ No router config
- ✅ Free

**Cons**:
- ❌ Need Tailscale installed on accessing device

### Scenario 2: Public Access with Security

**Stack**:
1. Traefik with Let's Encrypt SSL
2. Authelia 2FA
3. Fail2Ban + CrowdSec
4. Cloudflare DNS proxy (optional)
5. Rate limiting

**Access**:
- `https://jellyfin.yourdomain.com`
- Login with 2FA

**Pros**:
- ✅ Access from any browser
- ✅ Share with family easily
- ✅ Professional setup

**Cons**:
- ❌ More complex
- ❌ Attack surface exposed
- ❌ Need domain name

### Scenario 3: Hybrid (Best of Both)

**Stack**:
1. Tailscale for admin access
2. Public access for Jellyfin only
3. Everything else Tailscale-only

**Configuration**:
```yaml
# Jellyfin: Public with 2FA
jellyfin:
  labels:
    - "traefik.http.routers.jellyfin.middlewares=authelia@docker"

# Portainer, Woodpecker, etc: Tailscale-only (no Traefik labels)
```

**Access**:
- Jellyfin: `https://jellyfin.yourdomain.com` (public)
- Admin tools: Via Tailscale only

## Security Checklist

### Initial Setup
- [ ] Change all default passwords
- [ ] Generate strong secrets (`openssl rand -base64 32`)
- [ ] Setup SSH keys, disable password auth
- [ ] Configure firewall (UFW)
- [ ] Setup Tailscale or WireGuard
- [ ] Enable automatic updates

### Ongoing
- [ ] Review access logs weekly
- [ ] Update containers monthly (Watchtower handles this)
- [ ] Rotate secrets quarterly
- [ ] Review firewall rules
- [ ] Check for security advisories
- [ ] Backup configurations

### Advanced
- [ ] Setup Authelia 2FA
- [ ] Configure Fail2Ban
- [ ] Enable CrowdSec
- [ ] Setup intrusion detection
- [ ] Configure log aggregation
- [ ] Setup monitoring alerts

## Emergency Response

### Compromised Device

1. **Isolate**:
```bash
# Disconnect from network
sudo ufw deny out

# Or shut down
sudo shutdown now
```

2. **Investigate**:
```bash
# Check logs
docker-compose logs
journalctl -xe

# Check connections
sudo netstat -tupln
```

3. **Recover**:
```bash
# Pull fresh configs from git
git pull
./scripts/deploy.sh <device>

# Rotate all secrets
# Rebuild if necessary
```

### Suspicious Activity

1. **Check CrowdSec**:
```bash
docker exec crowdsec cscli decisions list
```

2. **Block IP**:
```bash
sudo ufw deny from <ip-address>
```

3. **Review logs**:
```bash
docker-compose logs | grep <ip-address>
```

## Best Practices

1. **Principle of Least Privilege**: Only expose what's necessary
2. **Defense in Depth**: Multiple security layers
3. **Zero Trust**: Verify everything, trust nothing
4. **Regular Updates**: Keep everything patched
5. **Monitoring**: Know what's happening
6. **Backups**: Regular, tested backups
7. **Documentation**: Keep security docs updated

## Resources

- [Tailscale Docs](https://tailscale.com/kb/)
- [Traefik Security](https://doc.traefik.io/traefik/middlewares/overview/)
- [Authelia Docs](https://www.authelia.com/docs/)
- [Docker Security](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)

## Questions?

- Is it exposed to internet? → Use Tailscale
- Need to share with non-tech users? → Use Cloudflare Tunnel + 2FA
- Want maximum control? → WireGuard + Authelia
- Paranoid about security? → All of the above!

**Remember**: Perfect security doesn't exist, but layered security makes you a hard target!
