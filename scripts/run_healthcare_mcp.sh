#!/usr/bin/env bash
set -euo pipefail

# Wrapper to install deps (if needed) and exec the healthcare-mcp Node server.
# Supports SKIP_INSTALL=1 to skip npm work and DRY_RUN=1 to only print actions.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MCP_DIR="$PROJECT_ROOT/api/mcps/healthcare-mcp-public"

if [ ! -d "$MCP_DIR" ]; then
  echo "ERROR: MCP directory not found: $MCP_DIR" >&2
  exit 2
fi

cd "$MCP_DIR"

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "DRY RUN: would start healthcare-mcp from $MCP_DIR"
  echo "DRY RUN: would check/install node deps unless SKIP_INSTALL=1"
  echo "DRY RUN: would exec: node server/index.js $*"
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: node not found on PATH. Please install Node.js 18+." >&2
  exit 3
fi

if [ "${SKIP_INSTALL:-0}" != "1" ]; then
  if [ ! -d node_modules ]; then
    echo "Installing Node dependencies in $MCP_DIR (npm ci)..."
    npm ci --no-audit --no-fund --prefer-offline
  else
    echo "node_modules present — skipping install (set SKIP_INSTALL=0 to force)"
  fi
else
  echo "SKIP_INSTALL=1 — skipping npm install"
fi

echo "Starting healthcare-mcp (exec node server/index.js)"
exec node server/index.js "$@"
