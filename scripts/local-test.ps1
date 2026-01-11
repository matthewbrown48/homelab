# Local Testing Script for Windows
# Tests individual services locally with Docker Desktop

param(
    [Parameter(Mandatory=$false)]
    [string]$Service = "jellyfin"
)

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Local Service Tester" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Map services to their device directories
$serviceMap = @{
    "jellyfin" = "devices/jellyfin-server"
    "jellyseerr" = "devices/jellyfin-server"
    "traefik" = "devices/jellyfin-server"
    "portainer" = "devices/pi5-openmediavault"
    "homepage" = "devices/pi5-openmediavault"
    "woodpecker" = "devices/pi4-ci-controller"
    "registry" = "devices/pi4-ci-controller"
}

if (-not $serviceMap.ContainsKey($Service)) {
    Write-Host "Unknown service: $Service" -ForegroundColor Red
    Write-Host "Available services:" -ForegroundColor Yellow
    $serviceMap.Keys | ForEach-Object { Write-Host "  - $_" }
    exit 1
}

$devicePath = $serviceMap[$Service]

Write-Host "Testing $Service from $devicePath" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
$dockerRunning = docker ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker is not running!" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
    exit 1
}

Push-Location $devicePath

# Setup .env file
if (-not (Test-Path ".env")) {
    Write-Host "Creating .env from .env.example..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host "⚠ Please edit .env with test values before continuing!" -ForegroundColor Yellow
    Write-Host "Press Enter when ready..." -ForegroundColor Yellow
    Read-Host
}

# Create test media directories if testing Jellyfin
if ($Service -eq "jellyfin") {
    Write-Host "Creating test media directories..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path "test-media/movies" | Out-Null
    New-Item -ItemType Directory -Force -Path "test-media/tv" | Out-Null
    New-Item -ItemType Directory -Force -Path "test-media/music" | Out-Null

    Write-Host "⚠ Update .env to point to test-media folders:" -ForegroundColor Yellow
    Write-Host "  MEDIA_MOVIES=./test-media/movies" -ForegroundColor Gray
    Write-Host "  MEDIA_TV=./test-media/tv" -ForegroundColor Gray
    Write-Host "  MEDIA_MUSIC=./test-media/music" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Starting $Service..." -ForegroundColor Cyan

# Start the service
docker-compose up -d $Service

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ Service started successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Access points:" -ForegroundColor Cyan

    switch ($Service) {
        "jellyfin" {
            Write-Host "  http://localhost:8096" -ForegroundColor Green
        }
        "jellyseerr" {
            Write-Host "  http://localhost:5055" -ForegroundColor Green
        }
        "portainer" {
            Write-Host "  https://localhost:9443" -ForegroundColor Green
        }
        "homepage" {
            Write-Host "  http://localhost:3000" -ForegroundColor Green
        }
        "woodpecker" {
            Write-Host "  http://localhost:8000" -ForegroundColor Green
        }
        "registry" {
            Write-Host "  http://localhost:5000" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Cyan
    Write-Host "  View logs:  docker-compose logs -f $Service" -ForegroundColor Gray
    Write-Host "  Stop:       docker-compose stop $Service" -ForegroundColor Gray
    Write-Host "  Restart:    docker-compose restart $Service" -ForegroundColor Gray
    Write-Host "  Clean up:   docker-compose down -v" -ForegroundColor Gray

} else {
    Write-Host ""
    Write-Host "✗ Failed to start service" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check logs with: docker-compose logs $Service" -ForegroundColor Yellow
}

Pop-Location
