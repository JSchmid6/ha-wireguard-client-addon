# Home Assistant WireGuard Client Add-on

A custom add-on that connects Home Assistant as a WireGuard VPN client to an external VPN server.

## Use Case

Ideal for Home Assistant on a Raspberry Pi (or similar) that connects via outbound VPN to an external VPS. Typical scenarios:

- **No port forwarding / CGNAT** — The Pi cannot be reached from the internet, but initiates the VPN connection itself
- **Remote access to the LAN** — Access the local network from the VPS (or remotely via the VPS), e.g. HA dashboard, NAS, printers
- **Pi stays locally accessible** — Devices on the LAN can still reach the Pi directly

### Network Architecture

```
Internet ← VPS (10.0.0.1) ←──WireGuard──→ RPi/HA (10.0.0.2) → LAN (192.168.1.0/24)
                                             ↑
                                        Local devices still
                                        access directly
```

**Important:** `allowed_ips` on the client (HA) should contain **only** the VPN subnet (`10.0.0.0/24`). LAN routing is configured on the **server side** (VPS) by setting `AllowedIPs = 10.0.0.2/32, 192.168.1.0/24` for the peer. This keeps local LAN connectivity intact.

## Features

- ✅ WireGuard client (outbound connection)
- ✅ No port forwarding required
- ✅ Automatic reconnect on connection loss
- ✅ Persistent across reboots
- ✅ Graceful shutdown (clean VPN teardown)
- ✅ Optional DNS configuration
- ✅ PresharedKey support for additional security
- ✅ NAT/Masquerading with auto-detected network interface
- ✅ Selective access control — restrict VPN to specific LAN targets
- ✅ Port forwarding — expose VPN services to LAN devices
- ✅ MTU configuration
- ✅ Multi-architecture: amd64, aarch64, armv7, armhf, i386

## Installation

1. Add this repository in Home Assistant:
   - **Settings → Add-ons → Add-on Store → ⋮ (top right) → Repositories**
   - Add repository URL: `https://github.com/DEIN-USERNAME/ha-wireguard-client`

2. Install the **"WireGuard Client"** add-on from the list

3. Configure the add-on (see below) and start it

## Configuration

### Full Example

```yaml
interface:
  address: "10.0.0.2/24"
  private_key: "YOUR_PRIVATE_KEY"
  dns: "1.1.1.1"
  mtu: 1420

peer:
  public_key: "SERVER_PUBLIC_KEY"
  endpoint: "vpn.example.com:51820"
  allowed_ips: "10.0.0.0/24"
  persistent_keepalive: 25
  preshared_key: "OPTIONAL_PRESHARED_KEY"

nat:
  enabled: true
  allowed_targets:
    - "192.168.1.100:8123"
    - "192.168.1.50:5000"
  port_forwards:
    - "5000:10.0.0.1:5000"
```

### Minimal Example

```yaml
interface:
  address: "10.0.0.2/24"
  private_key: "YOUR_PRIVATE_KEY"

peer:
  public_key: "SERVER_PUBLIC_KEY"
  endpoint: "vpn.example.com:51820"
  allowed_ips: "10.0.0.0/24"
  persistent_keepalive: 25
```

### Options

| Option | Required | Description |
|--------|----------|-------------|
| `interface.address` | ✅ | VPN IP address with subnet mask (e.g. `10.0.0.2/24`) |
| `interface.private_key` | ✅ | WireGuard private key of the client |
| `interface.dns` | ❌ | DNS server(s) for the VPN tunnel (e.g. `1.1.1.1`) |
| `interface.mtu` | ❌ | MTU value (1280–1500, default: automatic) |
| `peer.public_key` | ✅ | WireGuard public key of the server |
| `peer.endpoint` | ✅ | Server address with port (e.g. `vpn.example.com:51820`) |
| `peer.allowed_ips` | ✅ | Allowed IP ranges (e.g. `10.0.0.0/24` — VPN subnet only!) |
| `peer.persistent_keepalive` | ✅ | Keepalive interval in seconds (recommended: `25`) |
| `peer.preshared_key` | ❌ | Optional PresharedKey for additional security |
| `nat.enabled` | ✅ | Enable NAT/Masquerading (`true`/`false`, default: `false`) |
| `nat.interface` | ❌ | Network interface for NAT (auto-detected if omitted) |
| `nat.allowed_targets` | ❌ | List of allowed LAN targets from VPN (e.g. `192.168.1.100:8123`). If empty, all forwarding is allowed |
| `nat.port_forwards` | ❌ | List of port forwards from LAN to VPN (format: `listen_port:dest_host:dest_port`) |

### NAT / IP Forwarding

When `nat.enabled: true` is set, the add-on automatically configures iptables rules that forward traffic between the VPN tunnel and the local network (IP forwarding + masquerading). This is required when you want to access the Pi's local network from the VPS.

```yaml
nat:
  enabled: true
  # interface: "eth0"    # Optional — auto-detected from default route
```

The network interface is auto-detected via the default route. Manual configuration is only needed in special cases (e.g. multiple NICs).

### Selective Access Control

By default, NAT allows the VPN peer to reach **any** device on the local network. Use `allowed_targets` to restrict access to specific hosts and ports:

```yaml
nat:
  enabled: true
  allowed_targets:
    - "192.168.1.100:8123"   # Home Assistant web UI only
    - "192.168.1.50:5000"    # NAS on port 5000
    - "192.168.1.1"          # Router — all ports
```

Format: `"host:port"` for a specific port (TCP + UDP), or `"host"` for all ports on that host.

If `allowed_targets` is empty or omitted, all forwarding is allowed (legacy behavior).

### Port Forwarding (LAN → VPN)

Use `port_forwards` to make services running on the VPN side (e.g. on the VPS) accessible from LAN devices through the Pi:

```yaml
nat:
  enabled: true
  port_forwards:
    - "5000:10.0.0.1:5000"   # Frigate web UI on VPS
    - "8080:10.0.0.1:8080"   # Another VPS service
```

Format: `"listen_port:dest_host:dest_port"`

- `listen_port` — Port on the Pi's LAN interface that LAN devices connect to
- `dest_host:dest_port` — Destination on the VPN side (typically the VPS IP)

**Example:** With `"5000:10.0.0.1:5000"`, a LAN device can access `http://192.168.1.X:5000` (the Pi's LAN IP) and the traffic is forwarded through the VPN tunnel to `10.0.0.1:5000` on the VPS.

### Combining Both Features

```yaml
nat:
  enabled: true
  allowed_targets:
    - "192.168.1.100:8123"
  port_forwards:
    - "5000:10.0.0.1:5000"
```

This allows the VPS to reach only HA on `192.168.1.100:8123`, while LAN devices can access Frigate on the VPS via `Pi-IP:5000`.

### Server Configuration (VPS)

For the VPS to access the Pi's LAN through the tunnel, the WireGuard server config on the **VPS** must have the correct peer entry:

```ini
# /etc/wireguard/wg0.conf on the VPS
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = SERVER_PRIVATE_KEY

[Peer]
PublicKey = CLIENT_PUBLIC_KEY
AllowedIPs = 10.0.0.2/32, 192.168.1.0/24
```

> **Important:** The LAN subnet (`192.168.1.0/24`) is only added to `AllowedIPs` on the **server side** — **not** on the client! Otherwise the Pi loses local network connectivity.

## Generating WireGuard Keys

If you don't have keys yet:

```bash
# Generate private key
wg genkey > privatekey

# Derive public key from private key
cat privatekey | wg pubkey > publickey

# Optional: Generate PresharedKey
wg genpsk > presharedkey
```

## Troubleshooting

### Add-on won't start
- Check that `private_key` and `public_key` are set correctly
- Check that the `endpoint` is reachable (DNS resolution, port open)
- Check the add-on logs: **Settings → Add-ons → WireGuard Client → Log**

### Connection drops regularly
- Make sure `persistent_keepalive` is set (recommended: `25`)
- Check that the server has the client configured as a peer

### No internet access through VPN
- Set `allowed_ips` to `0.0.0.0/0` to route all traffic through VPN
- Configure `dns` with a DNS server inside the VPN or a public DNS
