# Local Testing Guide for Windows

How to test your homelab infrastructure locally on Windows before deploying.

## Prerequisites

- **Docker Desktop for Windows** installed and running
- **PowerShell 5.1+** or **WSL2** (Windows Subsystem for Linux)

## Quick Test

### Option 1: Validate All Configs (Quick)

**PowerShell**:
```powershell
cd C:\Users\Matthew\projects\homelab
.\scripts\test-configs.ps1
```

**WSL/Git Bash**:
```bash
cd /mnt/c/Users/Matthew/projects/homelab
bash scripts/test-configs.sh
```

This validates all `docker-compose.yml` files without starting anything.

### Option 2: Test Individual Services

**Test Jellyfin**:
```powershell
.\scripts\local-test.ps1 -Service jellyfin
```

**Test Portainer**:
```powershell
.\scripts\local-test.ps1 -Service portainer
```

**Test Woodpecker CI**:
```powershell
.\scripts\local-test.ps1 -Service woodpecker
```

Available services:
- `jellyfin` - Media server
- `jellyseerr` - Media requests
- `portainer` - Container management
- `homepage` - Dashboard
- `woodpecker` - CI/CD server
- `registry` - Docker registry

### Option 3: Test Everything Together

Start all test services at once:

```powershell
# From repo root
docker-compose -f docker-compose.test.yml up -d

# Access services:
# - Jellyfin: http://localhost:8096
# - Portainer: https://localhost:9443
# - Woodpecker: http://localhost:8000
# - Registry UI: http://localhost:5001

# View logs
docker-compose -f docker-compose.test.yml logs -f

# Stop all
docker-compose -f docker-compose.test.yml down

# Clean up (removes volumes)
docker-compose -f docker-compose.test.yml down -v
```

## Testing Workflow

### 1. Before Committing Code

```powershell
# Validate all configs
.\scripts\test-configs.ps1

# If all pass, safe to commit
git add .
git commit -m "Update configurations"
```

### 2. Testing New Services

```powershell
# Test Jellyfin locally
.\scripts\local-test.ps1 -Service jellyfin

# Once working, commit changes
```

### 3. Testing Full Stack

```powershell
# Start test environment
docker-compose -f docker-compose.test.yml up -d

# Test each service
# - Navigate to URLs
# - Check logs: docker-compose -f docker-compose.test.yml logs

# Clean up
docker-compose -f docker-compose.test.yml down -v
```

## Common Issues

### Docker Not Running

**Error**: `Cannot connect to Docker daemon`

**Solution**: Start Docker Desktop
1. Open Docker Desktop
2. Wait for "Docker Desktop is running" message
3. Try again

### Port Conflicts

**Error**: `Port is already allocated`

**Solution**:
```powershell
# Find what's using the port
netstat -ano | findstr ":8096"

# Stop the conflicting service or change ports in docker-compose.test.yml
```

### Volume Permission Issues

**Error**: `Permission denied`

**Solution**: Docker Desktop handles this automatically on Windows. If issues persist:
1. Open Docker Desktop
2. Settings → Resources → File Sharing
3. Ensure your project directory is shared

## Testing on WSL2 (Recommended)

If you have WSL2 installed, you can use the Linux scripts:

```bash
# In WSL terminal
cd /mnt/c/Users/Matthew/projects/homelab

# Run Linux test script
bash scripts/test-configs.sh

# Test individual services
cd devices/jellyfin-server
cp .env.example .env
docker-compose up -d jellyfin
docker-compose logs -f jellyfin
```

## CI/CD Testing

The repository includes GitHub Actions tests that run automatically on PRs:

- **`.github/workflows/test.yml`**: Validates all configs
- Runs on every pull request
- Must pass before merging

### Test Locally Before Pushing

```powershell
# Install act (optional): https://github.com/nektos/act
# This runs GitHub Actions locally

# List workflows
act -l

# Run tests workflow
act pull_request
```

## What Gets Tested

### Config Validation ✅
- YAML syntax
- Docker Compose schema
- Environment variable references
- Volume mounts
- Network configurations

### What Doesn't Get Tested ❌
- Device-specific hardware (ARM, GPIO, etc.)
- Multi-device networking
- Tailscale VPN mesh
- NFS/SMB mounts
- Production secrets

## Test Data Setup

### For Jellyfin Testing

```powershell
# Create test media
mkdir -p test-data/media/{movies,tv,music}

# Add sample files (or leave empty to test UI)
echo "Test movie" > test-data/media/movies/test.mp4

# Update .env in jellyfin-server/
# MEDIA_MOVIES=./test-data/media/movies
```

### For CI/CD Testing

```powershell
# Woodpecker doesn't need real repos for UI testing
# Just start it and explore the interface
.\scripts\local-test.ps1 -Service woodpecker
```

## Cleanup

```powershell
# Stop all test containers
docker ps -a --filter "name=test" --format "{{.Names}}" | ForEach-Object { docker stop $_ }

# Remove all test containers
docker ps -a --filter "name=test" --format "{{.Names}}" | ForEach-Object { docker rm $_ }

# Remove test volumes
docker volume ls --filter "name=test" --format "{{.Name}}" | ForEach-Object { docker volume rm $_ }

# Or use docker-compose
docker-compose -f docker-compose.test.yml down -v
```

## Next Steps

After local testing:
1. ✅ All configs validated
2. ✅ Services start without errors
3. ✅ Can access UIs locally
4. → **Safe to commit and push to GitHub**
5. → **Safe to deploy to real devices**

## Tips

- **Test one service at a time** initially
- **Use test volumes** to avoid polluting real data
- **Check logs frequently**: `docker-compose logs -f`
- **WSL2 is faster** than Docker Desktop's Windows containers
- **Clean up regularly** to save disk space

## Help

- **Docker Desktop Issues**: Restart Docker Desktop
- **Port Conflicts**: Check `netstat -ano | findstr ":PORT"`
- **Config Errors**: Run `.\scripts\test-configs.ps1` for details
- **Still stuck**: Check main [troubleshooting guide](docs/troubleshooting.md)
