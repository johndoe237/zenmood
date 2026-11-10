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
jq --arg api_key "$API_KEY" --arg listen "0.0.0.0:$PORT" \
  '.listen = $listen | .server_keys = [$api_key]' \
  /app/config.template.json > "$tmp"
chmod 0600 "$tmp"
mv -f "$tmp" "$config_path"
trap - EXIT HUP INT TERM
chown zenmood:zenmood "$state_dir" "$config_dir" "$config_path"
chmod 0600 "$config_path"

echo "warp config: $(jq -c .warp "$config_path")"

if [ "${WARP_NETWORK_DIAGNOSTICS:-1}" = "1" ]; then
    echo "========== WARP / NETWORK DIAGNOSTICS =========="

    echo "[IPv4 egress check]"
    if command -v curl >/dev/null 2>&1; then
        curl -4 -fsS --connect-timeout 5 --max-time 8 \
            https://www.cloudflare.com/cdn-cgi/trace || echo "IPv4 check failed (non-fatal)"

        echo "[IPv6 egress check]"
        curl -6 -g -fsS --connect-timeout 5 --max-time 8 \
            'https://[2606:4700:4700::1111]/cdn-cgi/trace' || \
            echo "IPv6 check failed (non-fatal)"
    fi

    echo "[UDP test: petit paquet]"
    dig +notcp +time=3 +tries=1 @1.1.1.1 cloudflare.com A 2>&1 \
        | grep -E "status|timed out|no servers" || echo "UDP small: no answer"

    echo "[UDP test: gros paquet]"
    dig +notcp +bufsize=4096 +time=3 +tries=1 @1.1.1.1 cloudflare.com DNSKEY 2>&1 \
        | grep -E "status|timed out|no servers|MSG SIZE" || echo "UDP large: no answer"

    echo "[MTU test: ping IPv4 avec DF]"
    for size in 1200 1252 1272 1300 1400; do
        if ping -4 -M do -c 1 -W 3 -s "$size" 1.1.1.1 >/dev/null 2>&1; then
            echo "payload $size (paquet $((size + 28))): OK"
        else
            echo "payload $size (paquet $((size + 28))): ECHEC"
        fi
    done

    echo "[UDP test: gros paquet DNS (DNSKEY racine)]"
    dig +notcp +bufsize=4096 +dnssec +time=3 +tries=1 @1.1.1.1 . DNSKEY 2>&1 \
        | grep -E "status|timed out|MSG SIZE" || echo "UDP DNSKEY: no answer"

    echo "[IPv6 addresses]"
    ip -6 addr show 2>&1 || true
    echo "[IPv6 routes]"
    ip -6 route show 2>&1 || true
    echo "[Network interfaces]"
    ip addr show 2>&1 || true
    echo "[DNS configuration]"
    cat /etc/resolv.conf 2>&1 || true

    echo "========== END NETWORK DIAGNOSTICS =========="
fi

exec su-exec zenmood:zenmood /usr/local/bin/opencode2api -config "$config_path"
