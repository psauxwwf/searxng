# SearXNG MCP Container

This repository builds a single Docker image that bundles:

- `SearXNG`
- `mcp-searxng`

## What This Image Does

The container starts an internal `SearXNG` instance and then runs `mcp-searxng` against it.

- No volumes are required.
- `SEARXNG_SECRET` is generated automatically at container startup.
- In `stdio` mode, the image works as a normal MCP server.
- In HTTP mode, it exposes the MCP endpoint on port `3000`.

## 1. Direct Usage With `docker run`

This is the simplest way to use the server without Docker MCP Gateway.

### Run the MCP server directly

```bash
docker run -i --rm --init ghcr.io/psauxwwf/searxng:latest
```

### OpenCode configuration example

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "MCP_SEARXNG": {
      "type": "local",
      "enabled": true,
      "command": [
        "docker",
        "run",
        "-i",
        "--rm",
        "--init",
        "ghcr.io/psauxwwf/searxng:latest",
      ],
    },
  },
}
```

---

## 2. Docker MCP Gateway Workflow

This section documents the current setup using Docker MCP Gateway with profiles.

The steps below configure Docker MCP Gateway with two MCP servers:

- `duckduckgo`
- this `searxng` server

### Quick Command Reference

Run these commands in order for a typical setup:

```bash
docker mcp feature enable profiles
docker mcp catalog pull mcp/docker-mcp-catalog
docker mcp catalog create local-servers --title "Local Servers"
curl -fsSL https://raw.githubusercontent.com/psauxwwf/searxng/refs/heads/master/searxng-mcp.catalog.yaml -o /tmp/searxng-mcp.catalog.yaml
docker mcp catalog server add local-servers --server file:///tmp/searxng-mcp.catalog.yaml
docker mcp profile create --name default
docker mcp profile server add default --server catalog://mcp/docker-mcp-catalog/duckduckgo
docker mcp profile server add default --server catalog://local-servers/searxng
docker mcp profile server ls --filter profile=default
docker mcp gateway run --profile default
```

To see the full list of available tools for the active profile at any time:

```bash
docker mcp tools ls --gateway-arg=--profile --gateway-arg=default
```

### 1. Enable profiles

```bash
docker mcp feature enable profiles
```

### 2. Pull the official Docker catalog

```bash
docker mcp catalog pull mcp/docker-mcp-catalog
```

### 3. Check available catalogs

```bash
docker mcp catalog ls
```

When using the profiles workflow, explicitly pulling the official Docker catalog avoids the case where `duckduckgo` is no longer visible after enabling profiles.

To inspect all servers available in the official Docker catalog:

```bash
docker mcp catalog show mcp/docker-mcp-catalog
```

To inspect the same catalog in JSON format:

```bash
docker mcp catalog show mcp/docker-mcp-catalog --format json
```

If you have `jq`, you can print just the server names:

```bash
docker mcp catalog show mcp/docker-mcp-catalog --format json | jq -r '.servers[].snapshot.server.name'
```

Or use the dedicated server listing command:

```bash
docker mcp catalog server ls mcp/docker-mcp-catalog
```

### 4. Create a local catalog

```bash
docker mcp catalog create local-servers --title "Local Servers"
```

If it already exists, you can reuse it.

### 5. Register this server in the local catalog

```bash
curl -fsSL https://raw.githubusercontent.com/psauxwwf/searxng/refs/heads/master/searxng-mcp.catalog.yaml -o /tmp/searxng-mcp.catalog.yaml
docker mcp catalog server add local-servers --server file:///tmp/searxng-mcp.catalog.yaml
```

`docker mcp catalog server add` expects a server reference. For a remote YAML file, download it first and then pass it as a `file://` URI.

### 6. Verify the local catalog

```bash
docker mcp catalog show local-servers
```

### 7. Create a profile

```bash
docker mcp profile create --name default
```

If the profile already exists, keep using it. You can inspect the current profile state with:

```bash
docker mcp profile server ls --filter profile=default
```

### 8. Add DuckDuckGo to the profile

```bash
docker mcp profile server add default --server catalog://mcp/docker-mcp-catalog/duckduckgo
```

### 9. Add this SearXNG server to the same profile

```bash
docker mcp profile server add default --server catalog://local-servers/searxng
```

### 10. Verify the profile contents

```bash
docker mcp profile server ls --filter profile=default
```

### 11. Run the gateway

```bash
docker mcp gateway run --profile default
```

In the profiles workflow, do not combine `--profile` with `--secrets`. For `duckduckgo` and this `searxng` server, no external secrets are required.

Leave this process running.

### 12. Verify the available tools

In another terminal:

```bash
docker mcp tools ls --gateway-arg=--profile --gateway-arg=default
```

This command shows all tools currently available through the `default` profile.

You should see tools from both servers, including:

- `search`
- `fetch_content`
- `searxng_web_search`
- `searxng_search_suggestions`
- `searxng_instance_info`
- `web_url_read`

### OpenCode configuration example

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "MCP_DOCKER": {
      "type": "local",
      "enabled": true,
      "command": ["docker", "mcp", "gateway", "run", "--profile", "default"],
    },
  },
}
```

## Notes

- The published catalog file is available at `https://raw.githubusercontent.com/psauxwwf/searxng/refs/heads/master/searxng-mcp.catalog.yaml`.
- The image is intended to run without bind mounts or persistent volumes.
- The bundled `SearXNG` config removes problematic default engines and disables the limiter for this local setup.
