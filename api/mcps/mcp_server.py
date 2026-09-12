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
                # Launch the healthcare MCP directly from its GitHub repo using npx.
                # This avoids requiring the files to exist locally — npx will
                # fetch the repo package and run its declared binary.
                "command": "npx",
                "args": ["--yes", "github:Cicatriiz/healthcare-mcp-public"],
                "cwd": str(ROOT_DIR),
            }
        )
    ]
    return [MCPServerStdio(params) for params in mcp_server_params]
