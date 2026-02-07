---
applyTo: "**/*.sh"
---

# Shell Script Instructions

## Convention
- Shebang: `#!/command/with-contenv bashio` (required for S6 Overlay V3 to load `SUPERVISOR_TOKEN`)
- Read config values via `bashio::config 'key.subkey'` — never use `jq` directly on `/data/options.json`.
- Log via `bashio::log.info`, `bashio::log.warning`, `bashio::log.error` — never use `echo`.
- Validate required config fields with `if [ -z "${VAR}" ]; then bashio::log.error "..."; exit 1; fi`.
- Write WireGuard configs to `/etc/wireguard/` with `chmod 600`.
- The script must end with a watchdog loop that checks `wg show wg0` and auto-reconnects on failure.
- Never log private keys or secrets.
- Comments and log messages in English.

## Watchdog Pattern
```bash
while true; do
    if ! wg show wg0 > /dev/null 2>&1; then
        bashio::log.warning "WireGuard interface down, restarting..."
        wg-quick down wg0 2>/dev/null || true
        sleep 5
        wg-quick up wg0
    fi
    sleep 30
done
```
