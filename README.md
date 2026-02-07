# Home Assistant WireGuard Client Add-on

Ein Custom Add-on um Home Assistant als WireGuard Client zu einem externen VPN-Server zu verbinden.

## Installation

1. Füge dieses Repository in Home Assistant hinzu:
   - Settings → Add-ons → Add-on Store → ⋮ (oben rechts) → Repositories
   - Füge hinzu: `https://github.com/DEIN-USERNAME/ha-wireguard-client`

2. Installiere das "WireGuard Client" Add-on aus der Liste

3. Konfiguriere das Add-on mit deinen WireGuard-Einstellungen

## Konfiguration

```yaml
interface:
  address: "10.0.0.2/24"
  private_key: "DEIN_PRIVATE_KEY"
  
peer:
  public_key: "SERVER_PUBLIC_KEY"
  endpoint: "vpn.example.com:51820"
  allowed_ips: "10.0.0.0/24"
  persistent_keepalive: 25
```

## Features

- ✅ WireGuard als Client (outbound connection)
- ✅ Kein Port-Forwarding notwendig
- ✅ Auto-Reconnect
- ✅ Persistent nach Reboot

## Use Case

Ideal für Home Assistant Systeme hinter CGNAT oder ohne Port-Forwarding-Möglichkeit,
die sich mit einem externen VPS verbinden sollen.
