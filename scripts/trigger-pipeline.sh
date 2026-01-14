#!/bin/bash
# Trigger Woodpecker CI pipeline via API
# Usage: ./scripts/trigger-pipeline.sh [branch]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load local config
if [ -f "$PROJECT_ROOT/.env.local" ]; then
    source "$PROJECT_ROOT/.env.local"
else
    echo "Error: .env.local not found. Create it with WOODPECKER_TOKEN"
    exit 1
fi

BRANCH="${1:-main}"

echo "Triggering pipeline for branch: $BRANCH"

# Trigger the pipeline
RESPONSE=$(curl -s -X POST "$WOODPECKER_URL/api/repos/$WOODPECKER_REPO_ID/pipelines" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $WOODPECKER_TOKEN" \
  -d "{\"branch\":\"$BRANCH\"}")

PIPELINE_NUM=$(echo "$RESPONSE" | grep -o '"number":[0-9]*' | cut -d: -f2)

if [ -n "$PIPELINE_NUM" ]; then
    echo "Pipeline #$PIPELINE_NUM triggered!"
    echo "View at: $WOODPECKER_URL/repos/$WOODPECKER_REPO_ID/pipeline/$PIPELINE_NUM"
else
    echo "Failed to trigger pipeline"
    echo "$RESPONSE"
fi
