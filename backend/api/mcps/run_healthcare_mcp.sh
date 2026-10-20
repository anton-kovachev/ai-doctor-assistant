#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '%s\n' "$*" >&2
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="$SCRIPT_DIR/healthcare-mcp-public"

log "Starting healthcare MCP server..."
log "Node version: $(node --version 2>&1 || echo 'Node not found')"
log "Script dir: $SCRIPT_DIR"
log "Working dir: $(pwd)"

if [ ! -d "$MCP_DIR" ]; then
  log "ERROR: MCP directory not found: $MCP_DIR"
  exit 2
fi

cd "$MCP_DIR"

if [ "${DRY_RUN:-0}" = "1" ]; then
  log "DRY RUN: would start healthcare-mcp from $MCP_DIR"
  log "DRY RUN: would check/install Node dependencies unless SKIP_INSTALL=1"
  log "DRY RUN: would exec: node server/index.js $*"
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  log "ERROR: node not found on PATH. Please install Node.js 18+."
  exit 3
fi

if [ "${SKIP_INSTALL:-0}" != "1" ]; then
  if [ ! -d node_modules ]; then
    log "Installing Node dependencies in $MCP_DIR (npm ci)..."
    npm ci --no-audit --no-fund --prefer-offline >&2
  else
    log "node_modules present — skipping install"
  fi
else
  log "SKIP_INSTALL=1 — skipping npm install"
fi

log "Starting healthcare-mcp"
exec node server/index.js "$@"