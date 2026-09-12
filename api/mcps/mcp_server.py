from agents.mcp import (
    MCPServerStdioParams,
    MCPServerStdio,
    MCPServerStreamableHttp,
    MCPServerStreamableHttpParams,
)
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent


def get_healthcare_mcp_servers() -> list[MCPServerStdio]:
    # Implement the logic to return a list of MCPServerStdio instances
    mcp_server_params = [
        MCPServerStdioParams(
            {
                # Use a small wrapper script that installs deps if missing,
                # then launches the Node server. This keeps startup idempotent
                # and avoids failures when node_modules is absent.
                "command": str(ROOT_DIR / "scripts" / "mcp_start.sh"),
                "args": [],
                "cwd": str(ROOT_DIR),
            }
        )
    ]
    return [MCPServerStdio(params) for params in mcp_server_params]
