#!/bin/bash

# Test all docker-compose configurations
# Works on: Linux, macOS, WSL on Windows

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "  Homelab Configuration Validator"
echo "======================================"
echo ""

FAILED=0
PASSED=0

# Test each device configuration
for device_dir in devices/*/; do
    if [ ! -f "$device_dir/docker-compose.yml" ]; then
        continue
    fi

    device_name=$(basename "$device_dir")
    echo -n "Testing $device_name... "

    cd "$device_dir"

    # Create .env from .env.example if it doesn't exist
    if [ ! -f .env ] && [ -f .env.example ]; then
        cp .env.example .env
    fi

    # Validate docker-compose syntax
    if docker-compose config > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        docker-compose config
        ((FAILED++))
    fi

    cd - > /dev/null
done

echo ""
echo "======================================"
echo "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "======================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

exit 0
