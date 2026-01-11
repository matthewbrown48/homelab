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

This repository manages multiple devices in a homelab environment:

- **Pi 5**: Open Media Vault NAS with supplementary services
- **Pi 4 + Pi Zero Cluster**: CI/CD pipeline using Woodpecker CI
- **Jellyfin Server**: Media streaming with reverse proxy

All configurations are declarative and deployed automatically via GitHub Actions.

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

### Pi 5 - Open Media Vault

- **Base OS**: Open Media Vault (existing installation)
- **Services** (Docker Compose):
  - Portainer - Container management UI
  - Homepage - Dashboard
  - Duplicati - Backup automation
  - Tailscale - Secure remote access

### Pi 4 + Pi Zero Cluster

- **Pi 4 Controller**:
  - Woodpecker CI Server
  - Docker Registry (local image storage)
  - PostgreSQL (Woodpecker database)

- **Pi Zero Workers** (multiple):
  - Woodpecker CI Agents
  - Execute build jobs in parallel

### Jellyfin Server

- **Services**:
  - Jellyfin - Media server
  - Jellyseerr - Media request management
  - Traefik - Reverse proxy with SSL
  - (Optional) Download clients

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

- **Orchestration**: Docker Compose
- **CI/CD Server**: Woodpecker CI (Pi 4 + Pi Zeros)
- **Deployment**: GitHub Actions + SSH (push-based)
- **Configuration**: Ansible (optional, for device setup)
- **Reverse Proxy**: Traefik (automatic SSL via Let's Encrypt)
- **Monitoring**: Prometheus + Grafana
- **Secret Management**: GitHub Secrets + .env files

## Security

- SSH key-based authentication only
- Secrets stored in GitHub Secrets (CI/CD) and `.env` files (never committed)
- Docker networks isolate services
- Traefik handles SSL termination
- Tailscale for secure remote access
- Regular security updates via Watchtower

## Documentation

- 📖 [Quick Start Guide](QUICKSTART.md) - Get running in 30 minutes
- 🏗️ [Architecture Overview](docs/architecture.md) - System design and data flows
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

- **Infrastructure as Code**: Complete homelab defined in version control
- **GitOps**: Automated deployment pipelines with GitHub Actions
- **Containerization**: Docker Compose orchestration across multiple devices
- **CI/CD**: Distributed build system with Woodpecker CI
- **Networking**: VPN setup (Tailscale), reverse proxy (Traefik), SSL automation
- **Security**: SSH key auth, secrets management, firewall configuration
- **Documentation**: Comprehensive guides and architecture documentation
- **Linux Administration**: Multi-device management, NFS/SMB, system monitoring
- **DevOps Tools**: Docker, Git, Ansible, Bash scripting, YAML

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
