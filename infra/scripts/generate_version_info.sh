#!/usr/bin/env bash

set -euxo pipefail

# Default location
LOCATION=${1:-""}

# If no location provided and not in CI, error out
if [ -z "$LOCATION" ] && [ -z "${CI:-}" ]; then
    echo "Error: Location parameter is required when not running in CI" >&2
    echo "Usage: $0 <location>" >&2
    exit 1
fi

# Set default location for CI
if [ -z "$LOCATION" ]; then
    LOCATION="ci"
fi

# Get git information
BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT=$(git rev-parse --short HEAD)

# Check if working directory is dirty
IS_DIRTY=$(git status --porcelain)
if [ -n "$IS_DIRTY" ]; then
    # Fail if running in CI with dirty working directory
    if [ "$LOCATION" = "ci" ]; then
        echo "Error: Working directory is dirty in CI environment" >&2
        echo "Git status:" >&2
        git status >&2
        exit 1
    fi
    
    # Create temporary stash to get hash of current state including changes
    TEMP_COMMIT=$(git stash create)
    if [ -n "$TEMP_COMMIT" ]; then
        DIRTY_COMMIT=$(git rev-parse --short "$TEMP_COMMIT")
    fi
fi

# Convert boolean test to JSON boolean
IS_DIRTY_JSON=$([ -n "$IS_DIRTY" ] && echo "true" || echo "false")

COMMIT_SUFFIX=$([ -n "$IS_DIRTY" ] && echo "$DIRTY_COMMIT.dirty" || echo "$COMMIT")

# Create version info JSON
VERSION_INFO=$(cat << EOF
{
  "version": {
    "branch": "${BRANCH}",
    "commit": "${COMMIT}",
    "dirtyCommit": "${DIRTY_COMMIT:-null}",
    "isDirty": ${IS_DIRTY_JSON},
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "tags": {
      "location_latest": "$LOCATION.latest",
      "branch_latest": "$LOCATION.$BRANCH.latest",
      "commit": "$LOCATION.$BRANCH.$COMMIT_SUFFIX"
    }
  }
}
EOF
)

# Update config.json with version info
if [ -f "infra/variables/config.json" ]; then
    # Use jq to merge the version info into the existing config
    jq -s '.[0] * .[1]' infra/variables/config.json <(echo "$VERSION_INFO") > infra/variables/config.json.tmp
    mv infra/variables/config.json.tmp infra/variables/config.json
else
    # If config.json doesn't exist, create it with just the version info
    mkdir -p infra/variables
    echo "$VERSION_INFO" > infra/variables/config.json
fi



