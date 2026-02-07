---
name: wireguard-config
description: Generate or modify WireGuard VPN client configuration for the Home Assistant add-on. Use when adding new WireGuard options, changing the config schema, or updating how the wg0.conf is generated in run.sh.
---

# WireGuard Config Skill

## Overview
This skill helps with WireGuard VPN client configuration for the HA add-on. It covers the full chain from `config.yaml` schema through `run.sh` config reading to `wg0.conf` generation.

## Config Flow
1. User sets values in HA UI → stored as JSON in `/data/options.json`
2. `config.yaml` defines the schema and defaults
3. `run.sh` reads values with `bashio::config 'key.subkey'`
4. `run.sh` writes `/etc/wireguard/wg0.conf`

## Adding a New Config Option

### Step 1: config.yaml
Add default in `options` AND type in `schema`:
```yaml
options:
  interface:
    existing_field: "value"
    new_field: ""          # <-- add here
schema:
  interface:
    existing_field: str
    new_field: str          # <-- and here
```

### Step 2: run.sh
Read the value:
```bash
NEW_FIELD=$(bashio::config 'interface.new_field')
```

Optionally validate:
```bash
if [ -z "${NEW_FIELD}" ]; then
    bashio::log.error "New field is not configured!"
    exit 1
fi
```

Add to wg0.conf template (within the heredoc):
```bash
cat > /etc/wireguard/wg0.conf <<WGEOF
[Interface]
Address = ${INTERFACE_ADDRESS}
PrivateKey = ${INTERFACE_PRIVATE_KEY}
NewOption = ${NEW_FIELD}
...
WGEOF
```

### Step 3: README.md
Document the new option in the German configuration section.

## WireGuard Config Reference
- `[Interface]` section: Address, PrivateKey, DNS, MTU, PostUp, PostDown
- `[Peer]` section: PublicKey, Endpoint, AllowedIPs, PersistentKeepalive, PresharedKey

## Supported Optional Features
- `interface.dns` — DNS server(s) for the tunnel
- `interface.mtu` — Custom MTU (1280–1500)
- `peer.preshared_key` — Additional symmetric-key layer
- `nat.enabled` — Enable iptables FORWARD + MASQUERADE (bool)
- `nat.interface` — Physical interface for NAT (default: eth0)

## NAT Implementation
NAT is handled via structured config values, NOT via arbitrary shell commands.
The add-on generates safe, hardcoded iptables rules in PostUp/PostDown:
```
iptables -A FORWARD -i %i -j ACCEPT
iptables -A FORWARD -o %i -j ACCEPT
iptables -t nat -A POSTROUTING -o <nat.interface> -j MASQUERADE
```
This prevents shell injection and keeps the privileged container secure.

## Routing
Custom routing (additional subnets) is handled by `wg-quick` automatically
via the `AllowedIPs` directive. Users should list all desired subnets
comma-separated in `peer.allowed_ips` instead of using manual `ip route` commands.

## Security
- Never expose arbitrary shell command execution (PostUp/PostDown as user input)
- Never log PrivateKey or PresharedKey values
- Always `chmod 600 /etc/wireguard/wg0.conf`
- Leave security-sensitive defaults as empty strings in `config.yaml`
