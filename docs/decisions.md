# Architecture Decision Records

This document explains key technical decisions made in this homelab, including what was tried, what didn't work, and why certain approaches were chosen.

---

## ADR-001: Docker Compose over Kubernetes

**Status**: Accepted

**Context**:
Modern DevOps culture often defaults to Kubernetes for container orchestration. However, this homelab manages 4-5 devices in a single physical location with modest workloads.

**Decision**:
Use Docker Compose for all container orchestration.

**Rationale**:
- **Clarity**: YAML configs are human-readable without needing deep K8s knowledge
- **Debuggability**: Direct service logs, no hidden pod/deployment abstractions
- **Determinism**: Explicit service definitions, predictable behavior
- **Maintenance overhead**: No etcd, kube-apiserver, scheduler, controller-manager
- **Resource efficiency**: No cluster control plane overhead on limited hardware
- **Portfolio value**: Demonstrates understanding of when complex tools are overkill

**When Kubernetes makes sense**:
- Multi-datacenter deployments
- Auto-scaling requirements (HPA, VPA, cluster autoscaler)
- Team collaboration on shared infrastructure
- >20 microservices requiring service mesh
- Built-in RBAC/multi-tenancy requirements

**Consequences**:
- ✅ Faster deployment cycles
- ✅ Lower learning curve for contributors
- ✅ Reduced memory/CPU footprint
- ❌ No built-in auto-scaling
- ❌ Manual rolling updates (acceptable for homelab)

---

## ADR-002: WiFi Networking for Pi Zero Nodes

**Status**: Accepted (after abandoning USB gadget mode)

**Context**:
Initial plan used ClusterHAT v2.5 with USB gadget mode (`dwc2` + `g_ether`) for Pi Zero networking. After extensive troubleshooting:
- Pi Zero W v1.1 has no diagnostic LEDs (only ClusterHAT PWR LED)
- ARMv6 Bullseye → Bookworm migration broke USB gadget compatibility
- Required extensive SD card surgery (`cmdline.txt`, `config.txt`, kernel overlays)
- Kernel module incompatibilities across OS versions
- Boot failures were impossible to diagnose without serial console

**Decision**:
Use standard WiFi networking with static DHCP reservations.

**Alternatives Considered**:

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| USB gadget (ClusterHAT) | Clean wiring, power + data over USB | Brittle across kernel versions, no boot diagnostics | ❌ Rejected |
| WiFi + static DHCP | Standard setup, reproducible, works immediately | Slightly higher latency | ✅ **Chosen** |
| USB-Ethernet dongles | Faster than WiFi, no kernel hacks | $5/device, extra cables | 💡 Future option |

**Rationale**:
- **Reproducibility**: Standard Raspberry Pi OS images work immediately
- **Maintainability**: No custom image surgery or kernel module dependencies
- **Debuggability**: Can SSH from any device on network
- **Portfolio honesty**: "Avoided brittle USB gadget networking" is an experienced answer

**Implementation**:
```yaml
# Router DHCP reservations
pi-zero-1: 192.168.1.201 (MAC: xx:xx:xx:xx:xx:01)
pi-zero-2: 192.168.1.202 (MAC: xx:xx:xx:xx:xx:02)
pi-zero-3: 192.168.1.203 (MAC: xx:xx:xx:xx:xx:03)
pi-zero-4: 192.168.1.204 (MAC: xx:xx:xx:xx:xx:04)
```

**Consequences**:
- ✅ Immediate functionality with standard images
- ✅ No OS-version-dependent kernel modules
- ✅ Easy to troubleshoot network issues
- ❌ Slightly higher network latency (~5-10ms vs USB)
- ❌ WiFi congestion potential (mitigated with 5GHz band)

---

## ADR-003: Pi Zero W v1.1 Limited to Non-Docker Workloads

**Status**: Accepted

**Context**:
Pi Zero W v1.1 uses BCM2835 SoC with ARMv6 architecture. Research revealed:
- Docker officially requires ARMv7+ (Pi Zero W v1.1 is ARMv6)
- Docker v28 is the last major version supporting 32-bit ARM
- Docker v29+ will drop 32-bit ARM entirely
- Woodpecker CI requires Docker to execute pipeline steps
- Most CI container images don't provide ARMv6 builds
- Attempting ARMv7 images on ARMv6 causes `exit code 139` (illegal instruction)

**Decision**:
Use Pi Zero W v1.1 for **native binary workloads only**, not Docker-based CI.

**Viable Use Cases**:
- ✅ **Linting**: YAML, JSON, HTML/CSS/JS validation (native tools)
- ✅ **Shell script testing**: Bash syntax checks, shellcheck
- ✅ **Infrastructure validation**: Ansible syntax, Terraform plan checks
- ✅ **Static analysis**: Link checking, SEO audits, config validation
- ✅ **Monitoring agents**: Node exporters, custom metrics collectors

**Non-Viable Use Cases**:
- ❌ Docker container builds
- ❌ Woodpecker CI agents (requires Docker)
- ❌ Multi-stage builds
- ❌ Running most pre-built CI images

**Alternatives Considered**:

| Option | Cost | Docker Support | Performance | Verdict |
|--------|------|----------------|-------------|---------|
| Keep Pi Zero W v1.1, force Docker | $0 | ❌ Broken | N/A | ❌ Rejected |
| Upgrade to Pi Zero 2 W | ~$15/ea | ✅ Full (ARMv8 64-bit) | 5x faster | 💡 **Recommended upgrade** |
| Use only Pi 4 for CI | $0 | ✅ Full | Fast | ✅ Acceptable interim |

**Woodpecker Runner Labels**:
```yaml
# Pi Zero runners explicitly labeled to prevent Docker job assignment
labels:
  - pi-zero
  - lint
  - validate
  - native-only
  - no-docker
```

**Portfolio Value**:
Acknowledging hardware limitations honestly is more professional than forcing incompatible technology. This demonstrates:
- Understanding of CPU architecture constraints
- Ability to research and validate technical feasibility
- Willingness to pivot when faced with hard blockers

**Consequences**:
- ✅ Pi Zeros remain useful for lightweight tasks
- ✅ No Docker compatibility hacks or workarounds
- ✅ Clear upgrade path (Pi Zero 2 W) if Docker needed
- ❌ Cannot run containerized CI pipelines on Pi Zeros
- ❌ Reduces parallelism for Docker-based builds

---

## ADR-004: Watchtower Disabled by Default

**Status**: Accepted

**Context**:
Watchtower automatically updates Docker containers to latest versions. This conflicts with GitOps philosophy where infrastructure changes should be version-controlled.

**Decision**:
Disable Watchtower by default. Provide optional override for users who prefer auto-updates.

**Rationale**:
- **GitOps purity**: All changes should flow through git commits
- **Predictability**: Manual updates prevent surprise breakages
- **Rollback capability**: Git history provides rollback path
- **Portfolio value**: Shows understanding of IaC principles

**Implementation**:
```yaml
# docker-compose.yml
watchtower:
  image: containrrr/watchtower
  # Disabled by default - enable via .env override
  profiles:
    - optional
```

**Consequences**:
- ✅ Infrastructure changes are auditable via git
- ✅ No surprise container updates during production workloads
- ❌ Manual intervention required for security updates (acceptable trade-off)

---

## ADR-005: Mini PC as Tier-1 Heavy Workload Node

**Status**: Accepted

**Context**:
Initial architecture had Jellyfin on a standalone device. Research and expert feedback suggested consolidating heavy workloads.

**Decision**:
Treat Mini PC as **Tier-1 node** running:
- Jellyfin (media streaming with HW transcoding)
- Traefik (reverse proxy)
- Homepage (dashboard)
- Prometheus + Grafana (monitoring)
- Optional Docker registry mirror

**Rationale**:
- **Hardware transcoding**: Mini PC likely has GPU support
- **Storage bandwidth**: Better I/O than Raspberry Pi SD cards
- **Reduces Pi load**: Pis handle orchestration, not heavy compute
- **Consolidation**: Fewer devices to manage

**Consequences**:
- ✅ Better media streaming performance
- ✅ Centralized monitoring and reverse proxy
- ✅ Reduces load on Pi 4 (keeps it boring and stable)
- ❌ Single point of failure (mitigated with good backups)

---

## Future Decisions

### Potential ADR-006: Pi Zero 2 W Upgrade

If Docker-based CI on Pi Zeros becomes necessary:
- **Cost**: ~$60 for 4x Pi Zero 2 W
- **Benefit**: Full Docker support, 5x performance increase
- **Timeline**: Consider after validating current architecture

### Potential ADR-007: USB-Ethernet Dongles for Speed

If WiFi latency becomes problematic:
- **Cost**: ~$20 for 4x dongles
- **Benefit**: Lower latency, no WiFi congestion
- **Drawback**: Extra cables, power considerations

---

## References

- [Docker ARM support timeline](https://docs.docker.com/engine/install/)
- [Raspberry Pi processor documentation](https://www.raspberrypi.com/documentation/computers/processors.html)
- [Woodpecker CI architecture](https://woodpecker-ci.org/docs/administration/architecture)
- [GitOps principles](https://www.gitops.tech/)

---

**Last Updated**: 2026-01-13
