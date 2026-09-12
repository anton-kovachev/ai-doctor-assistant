#!/usr/bin/env bash
set -euo pipefail

# Wrapper to ensure node deps are installed for the healthcare MCP server,
# then exec the server with any forwarded args.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MCP_DIR="$ROOT_DIR/mcps/healthcare-mcp-public"

cd "$MCP_DIR" || { echo "MCP directory not found: $MCP_DIR" >&2; exit 1; }

echo "[mcp_start] cwd=$PWD"

if [ ! -d node_modules ]; then
  echo "[mcp_start] node_modules not found — installing dependencies..."
  if command -v npm >/dev/null 2>&1; then
    if [ -f package-lock.json ]; then
      npm ci
    else
      npm install
    fi
  else
    echo "[mcp_start] npm not found. Please install Node.js and npm." >&2
    exit 1
  fi
else
  echo "[mcp_start] node_modules present — skipping install"
fi

echo "[mcp_start] starting node server..."
exec node server/index.js "$@"
