# Pi 4 - Woodpecker CI Controller

This setup creates a distributed CI/CD system using Woodpecker CI with the Pi 4 as the controller and Pi Zeros as build agents.

## Architecture

```
GitHub Repository
      ↓ (webhook)
Woodpecker Server (Pi 4)
      ↓ (distributes jobs)
   ┌──┴──┬──────┬──────┐
   │     │      │      │
Agent1 Agent2 Agent3 Agent4
(Pi4) (Zero1) (Zero2) (Zero3)
      ↓ (builds containers)
Docker Registry (Pi 4)
```

## Services

### Woodpecker Server (Port 8000)
- Main CI/CD server
- Web UI for pipeline management
- Integrates with GitHub via OAuth
- Access: `http://<pi4-ip>:8000`

### PostgreSQL
- Database for Woodpecker
- Stores build history, secrets, settings
- Internal only, no external access

### Woodpecker Agent (Pi 4)
- Runs on the controller itself
- Handles 2 concurrent builds
- More powerful than Pi Zero agents

### Docker Registry (Port 5000)
- Local container image storage
- Built images stored here
- Access: `http://<pi4-ip>:5000`

### Registry UI (Port 5001)
- Web interface for browsing registry
- Manage and delete images
- Access: `http://<pi4-ip>:5001`

## Setup Instructions

### 1. Create GitHub OAuth App

1. Go to: https://github.com/settings/developers
2. Click "New OAuth App"
3. Fill in:
   - **Application name**: Homelab Woodpecker CI
   - **Homepage URL**: `http://<pi4-ip>:8000`
   - **Authorization callback URL**: `http://<pi4-ip>:8000/authorize`
4. Click "Register application"
5. Note the **Client ID** and generate a **Client Secret**

### 2. Generate Agent Secret

```bash
openssl rand -hex 32
```

Save this secret - you'll need it for all agents!

### 3. Generate Registry Password

```bash
# Create htpasswd file for registry authentication
mkdir -p config/registry
docker run --rm --entrypoint htpasswd httpd:alpine \
  -Bbn homelab your-secure-password > config/registry/htpasswd
```

### 4. Configure Environment

```bash
cd devices/pi4-ci-controller
cp .env.example .env
nano .env
```

Update these critical values:
- `WOODPECKER_HOST`: Your Pi 4 IP (e.g., `http://192.168.1.100:8000`)
- `WOODPECKER_GITHUB_CLIENT`: From GitHub OAuth app
- `WOODPECKER_GITHUB_SECRET`: From GitHub OAuth app
- `WOODPECKER_ADMIN`: Your GitHub username
- `WOODPECKER_AGENT_SECRET`: Generated secret from step 2
- `POSTGRES_PASSWORD`: Secure database password
- `REGISTRY_PASSWORD`: From step 3

### 5. Deploy on Pi 4

```bash
# From repository root
./scripts/deploy.sh pi4-ci-controller

# Or manually
cd devices/pi4-ci-controller
docker-compose up -d
```

### 6. Access Woodpecker UI

1. Navigate to `http://<pi4-ip>:8000`
2. Click "Login with GitHub"
3. Authorize the application
4. You're in! Activate repositories you want to build

### 7. Setup Pi Zero Agents

For each Pi Zero worker:

```bash
# 1. Copy agent config to Pi Zero
scp -r agent-config/ pi@pi-zero-1:~/woodpecker-agent/

# 2. SSH into Pi Zero
ssh pi@pi-zero-1

# 3. Configure environment
cd ~/woodpecker-agent
cp .env.example .env
nano .env

# Update:
# - PI4_CONTROLLER_IP: Your Pi 4's IP
# - WOODPECKER_AGENT_SECRET: Same as Pi 4
# - WOODPECKER_HOSTNAME: Unique name (pi-zero-1, pi-zero-2, etc.)

# 4. Start agent
docker-compose up -d

# 5. Verify connection
docker logs woodpecker-agent
```

Repeat for each Pi Zero, changing the hostname each time.

### 8. Verify Agents Connected

In Woodpecker UI:
1. Go to Admin → Agents
2. You should see all agents listed:
   - pi4-controller (2 capacity)
   - pi-zero-1 (1 capacity)
   - pi-zero-2 (1 capacity)
   - etc.

## Creating CI Pipelines

### Basic .woodpecker.yml Example

Create this in your repository root:

```yaml
# .woodpecker.yml
pipeline:
  build:
    image: node:18-alpine
    commands:
      - npm install
      - npm test
      - npm run build

  docker:
    image: plugins/docker
    settings:
      registry: <pi4-ip>:5000
      repo: <pi4-ip>:5000/myapp
      tags: latest
      username: homelab
      password:
        from_secret: registry_password
    when:
      branch: main

  deploy:
    image: appleboy/drone-ssh
    settings:
      host: <target-device-ip>
      username: deploy
      key:
        from_secret: deploy_ssh_key
      script:
        - cd /opt/myapp
        - docker-compose pull
        - docker-compose up -d
    when:
      branch: main
```

### Multi-Architecture Builds

For ARM and x86 images:

```yaml
pipeline:
  build-arm:
    image: plugins/docker
    settings:
      registry: <pi4-ip>:5000
      repo: <pi4-ip>:5000/myapp
      tags: latest-arm64
      platform: linux/arm64

  build-amd64:
    image: plugins/docker
    settings:
      registry: <pi4-ip>:5000
      repo: <pi4-ip>:5000/myapp
      tags: latest-amd64
      platform: linux/amd64
```

## Managing Secrets

### Add Secrets in Woodpecker UI

1. Go to your repository in Woodpecker
2. Settings → Secrets
3. Add secrets like:
   - `registry_password`
   - `deploy_ssh_key`
   - API keys, tokens, etc.

### Use Secrets in Pipeline

```yaml
pipeline:
  deploy:
    image: alpine
    commands:
      - echo $REGISTRY_PASSWORD | docker login registry:5000 -u homelab --password-stdin
    secrets: [registry_password]
```

## Docker Registry Usage

### Push Images

```bash
# Tag image
docker tag myapp:latest <pi4-ip>:5000/myapp:latest

# Login
docker login <pi4-ip>:5000

# Push
docker push <pi4-ip>:5000/myapp:latest
```

### Pull Images

```bash
# From any device in homelab
docker pull <pi4-ip>:5000/myapp:latest
```

### Browse Registry

Access `http://<pi4-ip>:5001` to see all images in the registry.

## Resource Optimization

### Pi Zero Limitations
- **RAM**: 512MB total
- **CPU**: Single core, ARMv6
- **Strategy**: Light builds only, one at a time
- **Best for**: Tests, linting, simple builds

### Pi 4 Capabilities
- **RAM**: 4-8GB
- **CPU**: Quad-core, ARMv8
- **Strategy**: 2 concurrent builds
- **Best for**: Docker builds, complex pipelines

### Load Distribution

Woodpecker automatically distributes based on:
- Agent availability
- Resource capacity
- Platform requirements (arm64 vs amd64)

## Monitoring

### Check Agent Status

```bash
# On Pi 4
docker logs woodpecker-agent-pi4

# On Pi Zero
docker logs woodpecker-agent
```

### View Build Logs

All build logs visible in Woodpecker UI: `http://<pi4-ip>:8000`

### Database Backup

```bash
# Backup PostgreSQL
docker exec woodpecker-postgres pg_dump -U woodpecker woodpecker > backup.sql

# Restore
cat backup.sql | docker exec -i woodpecker-postgres psql -U woodpecker woodpecker
```

## Troubleshooting

### Agent won't connect

```bash
# Check logs
docker logs woodpecker-agent

# Verify secret matches
# Compare WOODPECKER_AGENT_SECRET on agent vs server

# Check network connectivity
ping <pi4-controller-ip>
telnet <pi4-controller-ip> 9000
```

### Registry authentication fails

```bash
# Recreate htpasswd
docker run --rm --entrypoint htpasswd httpd:alpine \
  -Bbn homelab new-password > config/registry/htpasswd

# Restart registry
docker-compose restart registry
```

### Build fails on Pi Zero

- Check available RAM: `free -h`
- Reduce concurrent builds to 1
- Use smaller base images (alpine)
- Split complex builds across multiple steps

### GitHub OAuth issues

- Verify callback URL matches exactly
- Check GitHub OAuth app settings
- Ensure `WOODPECKER_HOST` is accessible

## Upgrading

```bash
# Watchtower handles auto-updates, but for manual:
docker-compose pull
docker-compose up -d
```

## Integration with GitHub Actions

You can trigger homelab deployments from GitHub:

**.github/workflows/deploy.yml**:
```yaml
name: Deploy to Homelab

on:
  push:
    branches: [main]

jobs:
  trigger-homelab:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Woodpecker Build
        run: |
          curl -X POST http://${{ secrets.PI4_HOST }}:8000/api/repos/${{ github.repository }}/builds
```

## Next Steps

1. Activate your repositories in Woodpecker UI
2. Add `.woodpecker.yml` to your projects
3. Configure secrets in Woodpecker
4. Push code and watch builds run!
5. Monitor agent distribution across Pi 4 + Zeros
