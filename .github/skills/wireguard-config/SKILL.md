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
- `nat.interface` — Physical interface for NAT (optional, auto-detected from default route)
- `nat.allowed_targets` — String array of allowed LAN targets from VPN (`"host:port"` or `"host"`)
- `nat.port_forwards` — String array of port forwards from LAN to VPN (`"listen_port:dest_host:dest_port"`)

## NAT Implementation
NAT is handled via structured config values, NOT via arbitrary shell commands.
The add-on auto-detects the physical network interface via:
```bash
ip route show default | awk '/default/ {print $5}' | head -1
```

### Selective Access (allowed_targets)
When `allowed_targets` is configured, the add-on generates per-target iptables FORWARD rules
instead of blanket forwarding. Format: `"host:port"` (TCP+UDP) or `"host"` (all ports).
If no targets are specified, all forwarding is allowed (legacy behavior).

### Port Forwarding (port_forwards)
The add-on generates DNAT + FORWARD rules to expose VPN-side services to LAN devices.
Format: `"listen_port:dest_host:dest_port"`.
Traffic arriving on `NAT_INTERFACE:listen_port` is DNATed to `dest_host:dest_port` through wg0.
Requires an additional MASQUERADE on the wg0 interface for return traffic.

### Generated iptables Rules
```
# Conntrack (always)
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Per-target forwarding (if allowed_targets configured)
iptables -A FORWARD -i wg0 -o eth0 -d <host> -p tcp --dport <port> -j ACCEPT
iptables -A FORWARD -i wg0 -o eth0 -d <host> -p udp --dport <port> -j ACCEPT

# Port forward DNAT (if port_forwards configured)
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport <listen> -j DNAT --to-destination <dest_host>:<dest_port>
iptables -A FORWARD -i eth0 -o wg0 -d <dest_host> -p tcp --dport <dest_port> -j ACCEPT

# MASQUERADE
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE       # VPN→LAN
iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE        # LAN→VPN (port forwards only)
```
This prevents shell injection and keeps the privileged container secure.

## Routing — Split Tunnel Warning
**NEVER** put the client's local LAN subnet (e.g. `192.168.1.0/24`) into
`peer.allowed_ips` on the client side! This would route all LAN traffic
through the tunnel, breaking local connectivity.

Instead:
- Client `allowed_ips`: Only the VPN subnet (e.g. `10.0.0.0/24`)
- Server `AllowedIPs`: VPN IP + LAN subnet (e.g. `10.0.0.2/32, 192.168.1.0/24`)
- Client `nat.enabled: true` — so incoming VPN traffic gets forwarded to LAN

## Security
- Never expose arbitrary shell command execution (PostUp/PostDown as user input)
- Never log PrivateKey or PresharedKey values
- Always `chmod 600 /etc/wireguard/wg0.conf`
- Leave security-sensitive defaults as empty strings in `config.yaml`
