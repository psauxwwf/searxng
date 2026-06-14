#!/usr/bin/env sh
set -eu

cleanup() {
	if [ "${mcp_pid:-}" != "" ]; then
		kill "$mcp_pid" 2>/dev/null || true
	fi
	if [ "${searxng_pid:-}" != "" ]; then
		kill "$searxng_pid" 2>/dev/null || true
	fi
}

trap 'cleanup; wait "${mcp_pid:-}" 2>/dev/null || true; wait "${searxng_pid:-}" 2>/dev/null || true; exit 143' INT TERM

mkdir -p /etc/searxng /var/cache/searxng

secret="${SEARXNG_SECRET:-}"
if [ -z "$secret" ]; then
	secret="$(python -c 'import secrets; print(secrets.token_urlsafe(48))')"
fi
sed -e "s|__SEARXNG_SECRET__|$secret|g" \
	/usr/local/share/searxng/settings.yml.template >/etc/searxng/settings.yml
cp /usr/local/share/searxng/limiter.toml /etc/searxng/limiter.toml

export SEARXNG_URL="${SEARXNG_URL:-http://127.0.0.1:8080}"

/usr/local/searxng/entrypoint.sh >/dev/stderr 2>&1 &
searxng_pid=$!

python - <<'PY'
import sys
import time
import urllib.request

deadline = time.time() + 60
url = 'http://127.0.0.1:8080/'
headers = {'X-Real-IP': '127.0.0.1'}

while time.time() < deadline:
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=5) as response:
            response.read(1)
        sys.exit(0)
    except Exception:
        time.sleep(1)

print('SearXNG did not become ready in time', file=sys.stderr)
sys.exit(1)
PY

if [ -z "${MCP_HTTP_PORT:-}" ]; then
	if command -v su-exec >/dev/null 2>&1; then
		exec su-exec searxng node /usr/local/lib/node_modules/mcp-searxng/dist/cli.js
	fi
	exec node /usr/local/lib/node_modules/mcp-searxng/dist/cli.js
fi

if command -v su-exec >/dev/null 2>&1; then
	su-exec searxng node /usr/local/lib/node_modules/mcp-searxng/dist/cli.js &
else
	node /usr/local/lib/node_modules/mcp-searxng/dist/cli.js &
fi
mcp_pid=$!

status=0
while :; do
	if ! kill -0 "$searxng_pid" 2>/dev/null; then
		wait "$searxng_pid" || status=$?
		break
	fi
	if ! kill -0 "$mcp_pid" 2>/dev/null; then
		wait "$mcp_pid" || status=$?
		break
	fi
	sleep 1
done

cleanup
wait "$mcp_pid" 2>/dev/null || true
wait "$searxng_pid" 2>/dev/null || true
exit "$status"
