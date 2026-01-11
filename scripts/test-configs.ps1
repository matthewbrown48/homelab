# Test all docker-compose configurations
# PowerShell version for Windows

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Homelab Configuration Validator" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

$passed = 0
$failed = 0

# Get all device directories
$devices = Get-ChildItem -Path "devices" -Directory

foreach ($device in $devices) {
    $composePath = Join-Path $device.FullName "docker-compose.yml"

    if (-not (Test-Path $composePath)) {
        continue
    }

    Write-Host "Testing $($device.Name)... " -NoNewline

    Push-Location $device.FullName

    # Create .env from .env.example if needed
    if (-not (Test-Path ".env") -and (Test-Path ".env.example")) {
        Copy-Item ".env.example" ".env"
    }

    # Validate docker-compose
    $output = docker-compose config 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ PASS" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "✗ FAIL" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        $failed++
    }

    Pop-Location
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Results: " -NoNewline
Write-Host "$passed passed" -ForegroundColor Green -NoNewline
Write-Host ", " -NoNewline
Write-Host "$failed failed" -ForegroundColor Red
Write-Host "======================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
}

exit 0
