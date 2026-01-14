# Homelab Implementation Plan

**Status**: Ready to implement
**Last Updated**: 2026-01-13

---

## Overview

This document outlines the pragmatic, portfolio-ready implementation plan for the homelab GitOps infrastructure after pivoting from ClusterHAT USB gadget complexity to WiFi-based networking.

---

## What Changed

### ❌ What We Abandoned

1. **ClusterHAT USB gadget mode** (`dwc2` + `g_ether`)
   - **Why**: Brittle across kernel versions, ARMv6 Bookworm incompatibilities, no boot diagnostics
   - **Time spent troubleshooting**: ~4 hours of SD card surgery and boot failure debugging
   - **Lesson learned**: Not production-grade for portfolio work

2. **Docker on Pi Zero W v1.1**
   - **Why**: ARMv6 architecture not officially supported, Docker v29+ drops 32-bit ARM entirely
   - **Alternative**: Use native binaries for utility workloads

3. **Pi Zeros as "parallel compute cluster"**
   - **Why**: Over-ambitious framing for 512MB RAM ARMv6 devices
   - **Reframe**: "Utility workers" and "edge runners" for lightweight tasks

### ✅ What We're Implementing

1. **WiFi networking with static DHCP** - Standard, reproducible, debuggable
2. **Docker workloads on Pi 4 + Mini PC only** - Matches hardware capabilities
3. **Native binaries on Pi Zeros** - Linting, validation, monitoring (no Docker)
4. **Honest documentation** - Acknowledges constraints, explains trade-offs

---

## Architecture Summary

```
GitHub (GitOps) → GitHub Actions (SSH) → Home Network

Tier 1 (Docker Heavy):
  - Mini PC: Jellyfin, Traefik, Monitoring
  - Pi 5: OMV NAS, Portainer, Backups
  - Pi 4: Woodpecker CI server, Registry

Tier 2 (Native Binaries):
  - Pi Zero 1-4: Linting, validation, monitoring (WiFi)
```

---

## Implementation Steps

### Phase 1: Update Documentation ✅ COMPLETED

- [x] Updated [README.md](README.md) with realistic architecture
- [x] Added visual architecture diagram
- [x] Created [docs/decisions.md](docs/decisions.md) explaining why not K8s/ClusterHAT/Docker on ARMv6
- [x] Documented hardware constraints honestly
- [x] Added "Skills Demonstrated" section highlighting problem-solving and pivoting

### Phase 2: Pi 4 CI Controller Setup (Next)

**Goal**: Get Woodpecker CI server running on Pi 4

1. **SSH into Pi 4**:
   ```bash
   ssh moosecluster  # Assuming Pi 4 is MooseCluster
   ```

2. **Create Woodpecker compose file**:
   ```bash
   mkdir -p ~/ci-controller
   cd ~/ci-controller
   ```

3. **Deploy Woodpecker + PostgreSQL**:
   - Create `docker-compose.yml` for Woodpecker server
   - Create `.env` with secrets (GitHub OAuth, database creds)
   - Configure Woodpecker to use Pi 4 itself as first agent

4. **Test pipeline**:
   - Create test repo with `.woodpecker.yml`
   - Verify builds run successfully on Pi 4

**Time estimate**: 1-2 hours

### Phase 3: Pi Zero WiFi Setup (After Pi 4 works)

**Goal**: Get Pi Zeros online with SSH access

1. **Flash standard images**:
   ```bash
   # Download Raspberry Pi OS Lite Bullseye (32-bit)
   # Use Raspberry Pi Imager or dd
   ```

2. **Pre-configure WiFi**:
   ```bash
   # Mount boot partition
   # Create wpa_supplicant.conf
   # Create empty ssh file
   ```

3. **Set static DHCP on router**:
   ```
   pi-zero-1: 192.168.1.201 (MAC: find after first boot)
   pi-zero-2: 192.168.1.202
   pi-zero-3: 192.168.1.203
   pi-zero-4: 192.168.1.204
   ```

4. **Install native tools**:
   ```bash
   # SSH into each Pi Zero
   sudo apt update && sudo apt install -y \
     yamllint \
     shellcheck \
     jq \
     python3-pip \
     ansible-lint
   ```

5. **Install lightweight monitoring agents** (optional):
   ```bash
   # Node exporter for Prometheus metrics
   wget https://github.com/prometheus/node_exporter/releases/.../node_exporter-*-linux-armv6.tar.gz
   # Configure systemd service
   ```

**Time estimate**: 2-3 hours (including 4 devices)

### Phase 4: Woodpecker Pipeline Examples

**Goal**: Create example pipelines demonstrating hardware-aware job assignment

1. **Create `.woodpecker.yml` with labels**:
   ```yaml
   pipeline:
     lint-yaml:
       image: none  # Native execution
       commands:
         - yamllint .
       when:
         platform: linux/arm/v6
       agent:
         labels:
           - pi-zero
           - lint

     build-docker:
       image: docker:latest
       commands:
         - docker build -t myapp .
       when:
         platform: linux/arm64
       agent:
         labels:
           - docker
           - arm64
   ```

2. **Document labeling strategy** in repo README

**Time estimate**: 30 minutes

### Phase 5: Mini PC Setup (When hardware available)

**Goal**: Deploy Jellyfin + monitoring stack on Mini PC

1. **Install Docker + Docker Compose**
2. **Deploy services**:
   - Jellyfin
   - Traefik (reverse proxy)
   - Homepage (dashboard)
   - Prometheus + Grafana
3. **Configure Traefik SSL** (Let's Encrypt)

**Time estimate**: 2-3 hours

### Phase 6: Pi 5 OMV Setup

**Goal**: Configure Open Media Vault with supplementary Docker services

1. **Install OMV plugins** (if needed)
2. **Deploy Docker Compose stack**:
   - Portainer
   - Duplicati
   - Tailscale
3. **Configure NFS/SMB shares** for Jellyfin

**Time estimate**: 1-2 hours

### Phase 7: GitHub Actions CI/CD

**Goal**: Automate deployments from Git

1. **Create deployment workflows**:
   - `.github/workflows/deploy-pi4.yml`
   - `.github/workflows/deploy-pi5.yml`
   - `.github/workflows/deploy-minipc.yml`

2. **Configure GitHub Secrets**:
   - SSH private key
   - Device IP addresses
   - Service credentials

3. **Test deployment**: Make a change, commit, watch auto-deploy

**Time estimate**: 1-2 hours

---

## Total Time Estimate

- **Documentation**: ✅ 2 hours (completed)
- **Pi 4 setup**: 1-2 hours
- **Pi Zero setup**: 2-3 hours
- **Pipeline examples**: 30 minutes
- **Mini PC**: 2-3 hours (when available)
- **Pi 5**: 1-2 hours
- **GitHub Actions**: 1-2 hours

**Total**: ~10-15 hours (spread over multiple sessions)

---

## Success Criteria

- [ ] Woodpecker CI server running on Pi 4
- [ ] At least one successful test pipeline execution
- [ ] Pi Zeros SSH-accessible via WiFi
- [ ] Pi Zeros running native linting/validation tasks
- [ ] GitHub Actions auto-deploying on git push
- [ ] All documentation complete and honest
- [ ] Architecture decisions documented in `docs/decisions.md`

---

## Optional Future Enhancements

### Near-term (< $100)

1. **USB-Ethernet dongles** for Pi Zeros (~$20)
   - Reduces WiFi latency
   - Eliminates WiFi congestion

2. **Pi Zero 2 W upgrade** (~$60 for 4 devices)
   - Full Docker support (ARMv8 64-bit)
   - 5x performance increase
   - Enables containerized CI on edge runners

### Long-term

1. **NVMe storage for Pi 5** - Faster than SD cards
2. **UPS backup** - Protects against power outages
3. **External monitoring** - Uptime Kuma, status page

---

## Portfolio Talking Points

When discussing this project in interviews:

**"Why didn't you use Kubernetes?"**
> "This is intentionally Docker Compose + GitOps to demonstrate clarity, debuggability, and deterministic infrastructure over complexity. K8s makes sense for multi-datacenter deployments and large teams, but it's overkill for a single-site homelab with 5 devices."

**"Why Pi Zeros if they can't run Docker?"**
> "They demonstrate resource-constrained computing and strategic hardware allocation. They're excellent for linting, validation, and monitoring - workloads that don't need containers. It shows understanding of when NOT to force a technology."

**"Why not USB gadget mode with ClusterHAT?"**
> "After researching and testing, it's brittle across kernel versions and not production-grade. WiFi with static DHCP is reproducible and maintainable. I pivot when I hit hard technical blockers rather than fighting fragile solutions."

**"What did you learn from this project?"**
> "How to recognize sunk cost fallacy - we spent 4 hours troubleshooting ClusterHAT USB gadget mode before admitting it wasn't the right tool. Portfolio work should demonstrate good decisions, not stubbornness. Also learned about ARM architecture differences (ARMv6 vs ARMv7/ARMv8) and Docker compatibility constraints."

---

## Next Session Checklist

When resuming work:

1. Read [docs/decisions.md](docs/decisions.md) for context
2. Check current PI 4 status: `ssh moosecluster docker ps`
3. Start with Phase 2 (Pi 4 CI Controller Setup)
4. Use `git log` to see what was done in previous session
5. Update this document as you complete phases

---

**Questions?** See [docs/decisions.md](docs/decisions.md) for architectural rationale or [docs/troubleshooting.md](docs/troubleshooting.md) (when created) for common issues.
