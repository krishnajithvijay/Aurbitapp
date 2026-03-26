$ErrorActionPreference = "Stop"

$serverName = "mongodb"
$currentServers = codex mcp list --json | ConvertFrom-Json

if ($currentServers | Where-Object { $_ -eq $serverName }) {
  codex mcp remove $serverName
}

if (-not $env:MDB_MCP_CONNECTION_STRING) {
  Write-Warning "MDB_MCP_CONNECTION_STRING is not set. Registering without --env so the server can start cleanly. Re-run this script after setting the variable if you want auto-connect behavior."
  codex mcp add $serverName -- npx -y mongodb-mcp-server --readOnly
} else {
  codex mcp add $serverName --env MDB_MCP_CONNECTION_STRING=$env:MDB_MCP_CONNECTION_STRING -- npx -y mongodb-mcp-server --readOnly
}
codex mcp list
codex mcp get $serverName --json
