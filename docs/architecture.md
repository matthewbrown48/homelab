# Homelab Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                        │
│                    (Source of Truth - GitOps)                   │
└────────────────────┬────────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │   GitHub Actions      │
         │   (CI/CD Pipeline)    │
         └─┬──────────┬────────┬─┘
           │          │        │
    ┌──────▼─┐   ┌───▼────┐  ┌▼─────────┐
    │  Pi 5  │   │  Pi 4  │  │ Jellyfin │
    │  (NAS) │   │  (CI)  │  │  Server  │
    └────────┘   └────────┘  └──────────┘
```

## Network Topology

### Physical Layer

```
Internet
    │
    │
Router/Firewall (192.168.1.1)
    │
    ├─── [Switch/LAN] ─── Home Network (192.168.1.0/24)
    │         │
    │         ├─── Pi 5 OMV (192.168.1.100)
    │         ├─── Pi 4 CI (192.168.1.101)
    │         ├─── Jellyfin Server (192.168.1.102)
    │         ├─── Pi Zero 1 (192.168.1.110)
    │         ├─── Pi Zero 2 (192.168.1.111)
    │         └─── Pi Zero N (192.168.1.11x)
    │
    └─── [Tailscale VPN Overlay]
              │
              ├─── pi5.tailnet.ts.net
              ├─── pi4-ci.tailnet.ts.net
              ├─── jellyfin-server.tailnet.ts.net
              └─── User devices (phone, laptop, etc.)
```

### Logical Layer

```
┌─────────────────────────────────────────────────────────────┐
│                     Tailscale Overlay Network                │
│               (100.x.x.x - Encrypted Mesh VPN)              │
└─────────────────────────────────────────────────────────────┘
         │              │                    │
┌────────▼────────┐ ┌──▼─────────────┐ ┌───▼──────────┐
│   Pi 5 (NAS)    │ │  Pi 4 (CI/CD)  │ │   Jellyfin   │
├─────────────────┤ ├────────────────┤ ├──────────────┤
│ • Portainer     │ │ • Woodpecker   │ │ • Jellyfin   │
│ • Homepage      │ │ • Registry     │ │ • Jellyseerr │
│ • Duplicati     │ │ • Postgres     │ │ • Traefik    │
│ • Glances       │ │ • 4x Agents    │ │ • Downloads  │
│ • Watchtower    │ │ • Watchtower   │ │ • Watchtower │
│ • Tailscale     │ │ • Tailscale    │ │ • Tailscale  │
└─────────────────┘ └────────────────┘ └──────────────┘
         │                  │
         │           ┌──────┴──────┐
         │           │             │
         │      ┌────▼───┐    ┌───▼────┐
         │      │Pi Zero1│    │Pi Zero2│
         │      │(Agent) │    │(Agent) │
         │      └────────┘    └────────┘
         │
    [NFS/SMB]
         │
         └──────> Media Storage
                  (Movies, TV, Music)
```

## Component Architecture

### Pi 5 - Storage & Management Hub

**Role**: Network Attached Storage + Management Interface

**Services**:
- **Open Media Vault** (Host): Base NAS OS
- **Docker Compose Stack**:
  - **Portainer**: Container management UI
  - **Homepage**: Service dashboard
  - **Duplicati**: Backup automation
  - **Glances**: System monitoring
  - **Tailscale**: VPN connectivity
  - **Watchtower**: Auto-updates

**Storage**:
- Manages all homelab data
- Serves media to Jellyfin via NFS/SMB
- Stores backups

**Network**:
- `192.168.1.100` (static)
- `pi5.tailnet.ts.net` (Tailscale)
- Exposes ports: 9443, 3000, 8200, 61208

### Pi 4 - CI/CD Controller

**Role**: Build orchestration and container registry

**Services**:
- **Woodpecker Server**: CI/CD orchestration
- **PostgreSQL**: Woodpecker database
- **Docker Registry**: Local image storage
- **Registry UI**: Web interface for registry
- **Woodpecker Agent**: Local build agent
- **Tailscale**: VPN connectivity
- **Watchtower**: Auto-updates

**Build Pipeline**:
```
GitHub Webhook
      ↓
Woodpecker Server (Pi 4)
      ↓
Distribute to agents:
  ├─► Pi 4 Agent (2 concurrent)
  ├─► Pi Zero 1 Agent (1 concurrent)
  ├─► Pi Zero 2 Agent (1 concurrent)
  └─► Pi Zero N Agent (1 concurrent)
      ↓
Push images to local registry (Pi 4)
      ↓
Deploy to target devices
```

**Network**:
- `192.168.1.101` (static)
- `pi4-ci.tailnet.ts.net` (Tailscale)
- Exposes ports: 8000, 5000, 5001, 9000

### Pi Zero Workers

**Role**: Distributed build agents

**Services**:
- **Woodpecker Agent**: Executes build jobs

**Limitations**:
- 512MB RAM → 1 concurrent job max
- ARMv6 → Limited to ARM-compatible images
- Best for: Tests, linting, simple builds

**Network**:
- `192.168.1.110-119` (static)
- Connect to Pi 4 controller via gRPC (port 9000)

### Jellyfin Server

**Role**: Media streaming and web services

**Services**:
- **Traefik**: Reverse proxy + SSL termination
- **Jellyfin**: Media server
- **Jellyseerr**: Media request management
- **Transmission**: Download client (optional)
- **Tailscale**: VPN connectivity
- **Watchtower**: Auto-updates

**Media Access**:
```
NFS mounts from Pi 5:
  /mnt/media/movies  ← 192.168.1.100:/export/movies
  /mnt/media/tv      ← 192.168.1.100:/export/tv
  /mnt/media/music   ← 192.168.1.100:/export/music

Container mounts:
  /mnt/media/movies → /media/movies (Jellyfin container)
```

**Network**:
- `192.168.1.102` (static)
- `jellyfin-server.tailnet.ts.net` (Tailscale)
- Exposes ports: 80, 443, 8096, 5055, 8080

**Routing**:
```
User Request
     ↓
Traefik (Port 80/443)
     ↓ (reads Docker labels)
Routes to:
  ├─► jellyfin.domain.com → Jellyfin:8096
  ├─► requests.domain.com → Jellyseerr:5055
  └─► download.domain.com → Transmission:9091
```

## Data Flow

### GitOps Deployment Flow

```
Developer Workstation
     │
     ├─► 1. Edit config files
     ├─► 2. git commit & push
     │
GitHub Repository (main branch)
     │
     ├─► 3. Trigger GitHub Actions
     │
GitHub Actions Runner
     │
     ├─► 4. Validate configs
     ├─► 5. Detect changes
     ├─► 6. SSH to affected devices
     │
Target Device(s)
     │
     ├─► 7. rsync new configs
     ├─► 8. docker-compose pull
     ├─► 9. docker-compose up -d
     └─► 10. Health checks
```

### CI/CD Build Flow

```
Developer: git push to project repo
     │
     ├─► GitHub webhook
     │
Woodpecker Server (Pi 4)
     │
     ├─► Parse .woodpecker.yml
     ├─► Queue build job
     │
Build Queue
     │
     ├─► Assign to available agent
     │
Woodpecker Agent (Pi 4 / Pi Zero)
     │
     ├─► Pull source code
     ├─► Run pipeline steps:
     │     ├─► Install dependencies
     │     ├─► Run tests
     │     ├─► Build Docker image
     │     └─► Push to registry (Pi 4:5000)
     │
Docker Registry (Pi 4)
     │
     └─► Image available for deployment
```

### Media Streaming Flow

```
User Device
     │
     ├─► Request: http://jellyfin.domain.com
     │
Traefik (Jellyfin Server)
     │
     ├─► SSL termination
     ├─► Route to Jellyfin container
     │
Jellyfin Container
     │
     ├─► Read media file from /media/movies
     │     (NFS mount from Pi 5)
     ├─► Transcode if needed
     ├─► Stream to client
     │
User sees video!
```

## Security Layers

### Layer 1: Network Security

- **Firewall (UFW)**: Only necessary ports open
- **Tailscale**: Zero-trust overlay network
- **Private network**: All services on local LAN

### Layer 2: Access Control

- **SSH keys**: No password authentication
- **Separate users**: `deploy` user with limited sudo
- **GitHub Secrets**: Credentials not in code

### Layer 3: Application Security

- **Traefik**: SSL/TLS encryption
- **Docker networks**: Container isolation
- **Read-only mounts**: Where possible

### Layer 4: Monitoring

- **Watchtower**: Auto security updates
- **Logs**: Centralized logging
- **Health checks**: Service monitoring

## Scalability

### Adding More Devices

1. **Create new device config** in `devices/new-device/`
2. **Add to GitHub Actions** workflow
3. **Deploy** via push to main

### Adding More Services

1. **Edit docker-compose.yml** for target device
2. **Commit and push**
3. **Auto-deployed** via GitHub Actions

### Scaling CI/CD

- Add more Pi Zeros as agents
- Increase `WOODPECKER_MAX_WORKFLOWS` on powerful devices
- Distribute builds across architecture (ARM + x86)

## Technology Stack Summary

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Orchestration** | Docker Compose | Container management |
| **CI/CD** | Woodpecker CI | Build automation |
| **VPN** | Tailscale | Secure remote access |
| **Reverse Proxy** | Traefik | SSL & routing |
| **Deployment** | GitHub Actions | GitOps automation |
| **Config Mgmt** | Ansible (optional) | Server provisioning |
| **Storage** | Open Media Vault | NAS management |
| **Media** | Jellyfin | Streaming |
| **Monitoring** | Glances, Portainer | System monitoring |
| **Backups** | Duplicati | Automated backups |

## Design Principles

1. **Infrastructure as Code**: Everything in Git
2. **Immutable Infrastructure**: Rebuild, don't repair
3. **Single Source of Truth**: Git repository
4. **Declarative Configuration**: Docker Compose YAML
5. **Automated Deployment**: Push to deploy
6. **Security First**: VPN, encryption, least privilege
7. **Modularity**: Independent services
8. **Observability**: Logging and monitoring

## Future Expansion

Potential additions:
- **Kubernetes (k3s)**: For learning/production workloads
- **Prometheus + Grafana**: Advanced monitoring
- **Vault**: Secrets management
- **Gitea**: Self-hosted Git
- **Home Assistant**: Home automation
- **Pi-hole**: DNS ad-blocking
- **VPN**: WireGuard/OpenVPN
- **More media tools**: Radarr, Sonarr, Prowlarr
