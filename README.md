# Homelab GitOps Infrastructure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitOps](https://img.shields.io/badge/GitOps-Enabled-blue)](https://www.gitops.tech/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docs.docker.com/compose/)

A complete GitOps-based homelab management system using Docker Compose, GitHub, and automated deployment pipelines. All infrastructure is defined as code and version-controlled.

> **🎯 Portfolio Project**: This is a production-ready homelab infrastructure template demonstrating DevOps/GitOps best practices, infrastructure-as-code, and automated deployment pipelines.

## 🔒 Security Notice

**This is a PUBLIC template repository.** Before deploying:

- ✅ **Never commit secrets** - All `.env` files are gitignored
- ✅ **Change default passwords** - Copy `.env.example` to `.env` and configure with your own values
- ✅ **Use GitHub Secrets** - Store SSH keys and sensitive data in GitHub Secrets (not in code)
- ✅ **Rotate credentials** - Regularly update passwords, API keys, and auth tokens
- ✅ **Review configurations** - Replace example IPs and domains with your own

All example values in this repo are placeholders. See [docs/security.md](docs/security.md) for detailed security setup.

## ⭐ Using This Template

**For your own homelab:**
1. Fork or use as template
2. Clone to your machine
3. Follow [QUICKSTART.md](QUICKSTART.md) (30 minutes)
4. Customize for your devices

**For portfolio/resume:**
- Star the repo ⭐
- Fork to show on your profile
- Customize and showcase your implementation

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                            │
│                    (GitOps Source of Truth)                          │
└────────────┬────────────────────────────────────────────────────────┘
             │ GitHub Actions (SSH Deploy)
             ▼
┌────────────────────────────────────────────────────────────────────┐
│                      Home Network (WiFi + Ethernet)                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │   Mini PC    │  │    Pi 5      │  │    Pi 4      │             │
│  │  (Tier-1)    │  │    (NAS)     │  │ (CI Control) │             │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤             │
│  │ Jellyfin     │  │ OMV          │  │ Woodpecker   │             │
│  │ Traefik      │  │ Portainer    │  │ PostgreSQL   │             │
│  │ Homepage     │  │ Duplicati    │  │ Registry     │             │
│  │ Prometheus   │  │ Tailscale    │  │ Docker CI    │             │
│  │ Grafana      │  │ NFS/SMB      │  │              │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │ Pi Zero #1   │  │ Pi Zero #2   │  │ Pi Zero #3   │             │
│  │ (WiFi)       │  │ (WiFi)       │  │ (WiFi)       │  + Zero #4  │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤             │
│  │ Linting      │  │ Shell Tests  │  │ Monitoring   │             │
│  │ Validation   │  │ IaC Checks   │  │ Metrics      │             │
│  │ (No Docker)  │  │ (No Docker)  │  │ (No Docker)  │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
└────────────────────────────────────────────────────────────────────┘

Legend:
🐳 Docker-based workloads: Mini PC, Pi 5, Pi 4
📝 Native binary workloads: Pi Zeros (ARMv6 limitation)
```

**Key Architecture Principles**:
- **Mini PC**: Heavy workloads (media, monitoring, reverse proxy)
- **Pi 5**: NAS + utilities (storage, backups, VPN)
- **Pi 4**: CI control plane only (stable, boring, Docker-based builds)
- **Pi Zeros**: Lightweight utility tasks (linting, validation, monitoring - no Docker)

All configurations are declarative and deployed automatically via GitHub Actions.

> **Architecture Philosophy**: This setup intentionally uses Docker Compose + GitOps over Kubernetes to demonstrate clarity, debuggability, and deterministic infrastructure. Resource-constrained devices (Pi Zeros) are used strategically for edge tasks, not general compute.

## Quick Start

### Prerequisites

- All devices running Debian/Ubuntu-based Linux
- Docker and Docker Compose installed on each device
- SSH access configured for all devices
- GitHub repository with this code

### Initial Setup

1. **Clone this repository**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/homelab.git
   cd homelab
   ```

2. **Configure environment variables**:
   ```bash
   # For each device, copy and edit .env.example
   cp devices/pi5-openmediavault/.env.example devices/pi5-openmediavault/.env
   cp devices/pi4-ci-controller/.env.example devices/pi4-ci-controller/.env
   cp devices/jellyfin-server/.env.example devices/jellyfin-server/.env
   ```

3. **Set up deployment SSH keys**:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/homelab_deploy -C "homelab-deploy"
   # Add public key to each device's ~/.ssh/authorized_keys
   ```

4. **Configure GitHub Secrets**:
   - Go to: Settings > Secrets and variables > Actions > New repository secret
   - Add these secrets:
     - `SSH_PRIVATE_KEY`: Contents of `~/.ssh/homelab_deploy` (private key)
     - `PI5_HOST`: Your Pi 5 IP address (e.g., 192.168.1.100)
     - `PI4_HOST`: Your Pi 4 IP address (e.g., 192.168.1.101)
     - `JELLYFIN_HOST`: Your Jellyfin server IP (e.g., 192.168.1.102)

5. **Run device setup scripts**:
   ```bash
   # On each device
   ./scripts/setup-device.sh <device-name>
   ```

## Repository Structure

```
homelab/
├── .github/workflows/       # GitHub Actions CI/CD pipelines
├── devices/                 # Device-specific configurations
│   ├── pi5-openmediavault/  # Pi 5 NAS services
│   ├── pi4-ci-controller/   # Woodpecker CI server + registry
│   ├── jellyfin-server/     # Media server stack
│   └── shared/              # Shared configs (Traefik, monitoring)
├── scripts/                 # Deployment and maintenance scripts
├── ansible/                 # Ansible playbooks (optional)
└── docs/                    # Documentation
```

## Devices

### Mini PC - Tier-1 Node

- **Role**: Heavy workload tier-1 node
- **Services** (Docker Compose):
  - Jellyfin - Media streaming with hardware transcoding
  - Jellyseerr - Media request management
  - Traefik - Reverse proxy with automatic SSL
  - Homepage - Central dashboard
  - Prometheus + Grafana - Monitoring stack
  - Docker Registry mirror (optional)

**Why this matters**: Mini PC handles all CPU/GPU-intensive tasks, leaving Raspberry Pis for orchestration and utility work.

---

### Pi 5 - Open Media Vault NAS

- **Base OS**: Open Media Vault
- **Services** (Docker Compose):
  - Portainer - Container management UI
  - Duplicati - Backup automation to external storage
  - Tailscale - Secure remote access VPN
  - NFS/SMB shares for media storage

**Note**: Watchtower is disabled by default to maintain GitOps purity (optional override available).

---

### Pi 4 - CI Control Plane

- **OS**: Raspberry Pi OS Bookworm (Debian 12, 64-bit)
- **Role**: CI/CD control plane only - no user workloads
- **Services** (Docker Compose):
  - Woodpecker CI Server - CI/CD orchestration
  - PostgreSQL - Woodpecker database
  - Docker Registry - Local image caching

**Scope**: Handles Docker-based CI builds. Intentionally kept stable and boring.

---

### Pi Zero W v1.1 - Utility Nodes

- **OS**: Raspberry Pi OS Lite Bullseye (32-bit, ARMv6)
- **Networking**: WiFi with static DHCP reservations (no USB gadget complexity)
- **Use Cases** (non-Docker workloads):
  - **Linting**: YAML, JSON, HTML/CSS/JS validation
  - **Shell script testing**: Bash/sh syntax and logic tests
  - **Infrastructure validation**: Ansible syntax, Terraform plan checks
  - **Static site validation**: Link checking, SEO audits
  - **Monitoring agents**: Lightweight metrics collection

**Important Limitations**:
- ❌ **Cannot run Docker reliably** (ARMv6 architecture not supported by Docker v29+)
- ❌ **Not suitable for Woodpecker CI agents** (requires Docker for pipeline steps)
- ✅ **Excellent for lightweight, native binary workloads**

**Labeling Strategy**: Pi Zero runners use explicit labels (`pi-zero`, `lint`, `validate`) to prevent Docker job assignment.

> 💡 **Optional Upgrade**: Pi Zero 2 W (~$15 each) supports Docker (ARMv8 64-bit), enabling containerized CI workloads while maintaining the same form factor.

## GitOps Workflow

### Making Changes

1. **Create a branch**:
   ```bash
   git checkout -b feature/add-service
   ```

2. **Edit device configurations**:
   - Modify `docker-compose.yml` files
   - Update environment variables
   - Add new services as needed

3. **Commit and push**:
   ```bash
   git add .
   git commit -m "Add new service to Pi 5"
   git push origin feature/add-service
   ```

4. **Create Pull Request**:
   - GitHub Actions will validate configurations
   - Review changes
   - Merge to main

5. **Automatic Deployment**:
   - On merge to main, GitHub Actions deploys to affected devices
   - Services are updated automatically
   - Health checks verify successful deployment

### Manual Deployment

For testing or emergency changes:

```bash
# Deploy to specific device
./scripts/deploy.sh pi5-openmediavault

# Deploy to all devices
./scripts/deploy.sh all
```

## Technologies Used

- **Orchestration**: Docker Compose (not Kubernetes - intentional choice for clarity)
- **CI/CD Server**: Woodpecker CI (Pi 4 controller, native workloads on Pi Zeros)
- **Deployment**: GitHub Actions + SSH (push-based GitOps)
- **Configuration**: Ansible (optional device bootstrap)
- **Reverse Proxy**: Traefik (automatic SSL via Let's Encrypt)
- **Monitoring**: Prometheus + Grafana (Mini PC)
- **Secret Management**: GitHub Secrets + .env files (gitignored)
- **Networking**: WiFi with static DHCP (no USB gadget complexity)

## Security

- SSH key-based authentication only
- Secrets stored in GitHub Secrets (CI/CD) and `.env` files (never committed)
- Docker networks isolate services
- Traefik handles SSL termination
- Tailscale for secure remote access
- Regular security updates via Watchtower

## Architecture Decisions

### Why Docker Compose instead of Kubernetes?

**Intentional choice for this homelab:**
- ✅ **Clarity**: YAML configs are human-readable and debuggable
- ✅ **Determinism**: Explicit service definitions, no hidden abstractions
- ✅ **Simplicity**: No overhead for cluster orchestration
- ✅ **Portfolio value**: Shows understanding of when NOT to use complex tools

**When to use K8s**: Multi-datacenter deployments, auto-scaling requirements, team collaboration on shared clusters. Not needed for single-site homelabs.

---

### Why WiFi networking for Pi Zeros?

**Avoids USB gadget brittleness:**
- ❌ ClusterHAT USB gadget mode requires kernel module surgery across OS versions
- ❌ Bookworm/Trixie regressions break ARMv6 compatibility
- ❌ No diagnostic LEDs on Pi Zero W v1.1 for boot troubleshooting
- ✅ WiFi + static DHCP = reproducible, standard setup
- ✅ Can add USB-Ethernet dongles later for speed without kernel hacks

---

### Why limit Pi Zero W v1.1 to non-Docker workloads?

**Technical reality:**
- ARMv6 architecture (BCM2835) not officially supported by Docker
- Docker v29+ will drop 32-bit ARM support entirely
- Most CI container images don't provide ARMv6 builds
- Attempting Docker on ARMv6 causes exit code 139 errors (instruction set mismatch)

**Portfolio honesty**: Acknowledging hardware constraints is more professional than forcing incompatible technology.

---

## Documentation

- 📖 [Quick Start Guide](QUICKSTART.md) - Get running in 30 minutes
- 🏗️ [Architecture Overview](docs/architecture.md) - System design and data flows
- 🏛️ [Architecture Decisions](docs/decisions.md) - Why not K8s, ClusterHAT, Docker on ARMv6
- 🚀 [Getting Started](docs/getting-started.md) - Detailed setup walkthrough
- 🔒 [Security Guide](docs/security.md) - Tailscale setup and best practices
- 🔧 [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions
- 📁 Device-specific READMEs in `devices/*/README.md`

## Maintenance

### Backup

```bash
# Backup all configurations
./scripts/backup.sh

# Configurations are in git - just push!
# Data backups handled by Duplicati on Pi 5
```

### Updates

```bash
# Update all containers to latest versions
./scripts/update.sh

# Or let Watchtower handle it automatically
```

### Health Checks

```bash
# Check all services
./scripts/health-check.sh
```

## Skills Demonstrated

This project showcases:

- **Infrastructure as Code**: Complete homelab defined in version control with GitOps workflows
- **Pragmatic Architecture**: Choosing Docker Compose over Kubernetes for appropriate scale
- **Containerization**: Multi-device Docker orchestration with resource constraints
- **CI/CD**: Woodpecker CI with hardware-aware job labeling
- **Networking**: WiFi mesh, static DHCP, Tailscale VPN, Traefik reverse proxy with SSL
- **Security**: SSH key auth, secrets management (GitHub Secrets + .env), firewall rules
- **Hardware Constraints**: Working within ARMv6 limitations, upgrade path planning
- **Documentation**: Comprehensive guides with honest architectural trade-offs
- **Linux Administration**: Multi-device management, NFS/SMB, system monitoring
- **DevOps Tools**: Docker, Git, Ansible, Bash scripting, YAML, GitHub Actions
- **Problem Solving**: Recognizing when to pivot (abandoning ClusterHAT USB gadget complexity)

## Contributing

This is a template/portfolio project. Feel free to:
- ⭐ Star this repo if you find it useful
- 🍴 Fork for your own homelab
- 🐛 Submit issues for bugs
- 💡 Suggest improvements via discussions
- 📖 Use as reference for your own GitOps setup

## License

MIT License - see [LICENSE](LICENSE) for details

## Acknowledgments

- [Woodpecker CI](https://woodpecker-ci.org/) - Lightweight CI/CD
- [Traefik](https://traefik.io/) - Reverse proxy
- [Jellyfin](https://jellyfin.org/) - Media server
- [Open Media Vault](https://www.openmediavault.org/) - NAS solution
