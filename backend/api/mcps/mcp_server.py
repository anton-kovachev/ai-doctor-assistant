from agents.mcp import (
    MCPServerStdioParams,
    MCPServerStdio,
    MCPServerStreamableHttp,
    MCPServerStreamableHttpParams,
)
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]


def get_healthcare_mcp_servers() -> list[MCPServerStdio]:
    # Use a local wrapper script that ensures dependencies are installed
    # and then execs the healthcare-mcp Node server.
    wrapper = Path(__file__).resolve().parent / "run_healthcare_mcp.sh"

    mcp_server_params = [
        MCPServerStdioParams(
            {
                "command": "bash",
                "args": ["-lc", str(wrapper)],
                "cwd": str(PROJECT_ROOT),
            }
        )
    ]
    return [MCPServerStdio(params) for params in mcp_server_params]
