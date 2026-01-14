#!/bin/bash
# Check Woodpecker CI pipeline status
# Usage: ./scripts/check-pipeline.sh [pipeline-number]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load local config
if [ -f "$PROJECT_ROOT/.env.local" ]; then
    source "$PROJECT_ROOT/.env.local"
else
    echo "Error: .env.local not found. Create it with WOODPECKER_TOKEN"
    exit 1
fi

PIPELINE_NUM="${1:-latest}"

if [ "$PIPELINE_NUM" = "latest" ]; then
    # Get latest pipeline
    RESPONSE=$(curl -s "$WOODPECKER_URL/api/repos/$WOODPECKER_REPO_ID/pipelines?page=1&per_page=1" \
      -H "Authorization: Bearer $WOODPECKER_TOKEN")
    PIPELINE_NUM=$(echo "$RESPONSE" | grep -o '"number":[0-9]*' | head -1 | cut -d: -f2)
fi

echo "Checking pipeline #$PIPELINE_NUM..."

RESPONSE=$(curl -s "$WOODPECKER_URL/api/repos/$WOODPECKER_REPO_ID/pipelines/$PIPELINE_NUM" \
  -H "Authorization: Bearer $WOODPECKER_TOKEN")

STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
EVENT=$(echo "$RESPONSE" | grep -o '"event":"[^"]*"' | head -1 | cut -d'"' -f4)
ERRORS=$(echo "$RESPONSE" | grep -o '"errors":\[[^]]*\]')

echo "Status: $STATUS"
echo "Event: $EVENT"

if [ -n "$ERRORS" ] && [ "$ERRORS" != '"errors":[]' ]; then
    echo "Errors: $ERRORS"
fi

echo ""
echo "View at: $WOODPECKER_URL/repos/$WOODPECKER_REPO_ID/pipeline/$PIPELINE_NUM"
