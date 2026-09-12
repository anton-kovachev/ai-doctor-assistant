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
                "command": "node",
                "args": ["mcps/healthcare-mcp-public/server/index.js"],
                "cwd": str(ROOT_DIR),
            }
        )
    ]
    return [MCPServerStdio(params) for params in mcp_server_params]
