#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "entrypoint: must start as root to initialize the writable data directory" >&2
    exit 1
fi

: "${API_KEY:?Set API_KEY to a non-empty secret}"
PORT=${PORT:-8080}
case "$PORT" in
    ''|*[!0-9]*) echo "entrypoint: PORT must be an integer between 1 and 65535" >&2; exit 1 ;;
esac
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "entrypoint: PORT must be an integer between 1 and 65535" >&2
    exit 1
fi

state_dir=${STATE_DIR:-/data}
config_path=${CONFIG_PATH:-$state_dir/config.json}
config_dir=$(dirname "$config_path")
mkdir -p "$state_dir" "$config_dir"
tmp=$(mktemp "$config_dir/.config-XXXXXX")
trap 'rm -f "$tmp"' EXIT HUP INT TERM
# Preserve all repository settings; only inject the secret and assigned port.
jq --arg api_key "$API_KEY" --arg listen "0.0.0.0:$PORT" \
  '.listen = $listen | .server_keys = [$api_key]' \
  /app/config.template.json > "$tmp"
chmod 0600 "$tmp"
mv -f "$tmp" "$config_path"
trap - EXIT HUP INT TERM
chown zenmood:zenmood "$state_dir" "$config_dir" "$config_path"
chmod 0600 "$config_path"

exec su-exec zenmood:zenmood /usr/local/bin/opencode2api -config "$config_path"
