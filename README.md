# Home Assistant WireGuard Client Add-on

Ein Custom Add-on um Home Assistant als WireGuard Client zu einem externen VPN-Server zu verbinden.

## Use Case

Ideal für Home Assistant auf einem Raspberry Pi (oder ähnlichem), der sich per Outbound-VPN mit einem externen VPS verbindet. Typische Szenarien:

- **Kein Port-Forwarding / CGNAT** — Der Pi kann von außen nicht erreicht werden, baut aber selbst die VPN-Verbindung auf
- **Remote-Zugriff auf das LAN** — Vom VPS (oder von unterwegs über den VPS) auf das lokale Netzwerk zugreifen (z.B. HA-Dashboard, NAS, Drucker)
- **Der Pi bleibt lokal erreichbar** — Geräte im LAN können den Pi weiterhin direkt erreichen

### Netzwerk-Architektur

```
Internet ← VPS (10.0.0.1) ←──WireGuard──→ RPi/HA (10.0.0.2) → LAN (192.168.1.0/24)
                                             ↑
                                        Lokale Geräte greifen
                                        weiterhin direkt zu
```

**Wichtig:** `allowed_ips` auf dem Client (HA) sollte **nur** das VPN-Subnetz enthalten (`10.0.0.0/24`). Das Routing zum LAN konfigurierst du auf der **Server-Seite** (VPS), indem du dort `AllowedIPs = 10.0.0.2/32, 192.168.1.0/24` für den Peer setzt. So bleibt der lokale LAN-Zugriff auf den Pi bestehen.

## Features

- ✅ WireGuard als Client (outbound connection)
- ✅ Kein Port-Forwarding notwendig
- ✅ Automatischer Reconnect bei Verbindungsabbruch
- ✅ Persistent nach Reboot
- ✅ Graceful Shutdown (sauberes Herunterfahren der VPN-Verbindung)
- ✅ Optionale DNS-Konfiguration
- ✅ PresharedKey-Unterstützung für zusätzliche Sicherheit
- ✅ NAT/Masquerading mit Auto-Erkennung des Netzwerk-Interfaces
- ✅ MTU-Konfiguration
- ✅ Multi-Architektur: amd64, aarch64, armv7, armhf, i386

## Installation

1. Füge dieses Repository in Home Assistant hinzu:
   - **Settings → Add-ons → Add-on Store → ⋮ (oben rechts) → Repositories**
   - Repository-URL hinzufügen: `https://github.com/DEIN-USERNAME/ha-wireguard-client`

2. Installiere das **"WireGuard Client"** Add-on aus der Liste

3. Konfiguriere das Add-on (siehe unten) und starte es

## Konfiguration

### Vollständiges Beispiel

```yaml
interface:
  address: "10.0.0.2/24"
  private_key: "DEIN_PRIVATE_KEY"
  dns: "1.1.1.1"
  mtu: 1420

peer:
  public_key: "SERVER_PUBLIC_KEY"
  endpoint: "vpn.example.com:51820"
  allowed_ips: "10.0.0.0/24"
  persistent_keepalive: 25
  preshared_key: "OPTIONALER_PRESHARED_KEY"

nat:
  enabled: true
```

### Minimales Beispiel

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

### Optionen

| Option | Pflicht | Beschreibung |
|--------|---------|-------------|
| `interface.address` | ✅ | VPN-IP-Adresse mit Subnetzmaske (z.B. `10.0.0.2/24`) |
| `interface.private_key` | ✅ | WireGuard Private Key des Clients |
| `interface.dns` | ❌ | DNS-Server im VPN-Tunnel (z.B. `1.1.1.1, 8.8.8.8`) |
| `interface.mtu` | ❌ | MTU-Wert (1280–1500, Standard: automatisch) |
| `peer.public_key` | ✅ | WireGuard Public Key des Servers |
| `peer.endpoint` | ✅ | Server-Adresse mit Port (z.B. `vpn.example.com:51820`) |
| `peer.allowed_ips` | ✅ | Erlaubte IP-Bereiche (z.B. `10.0.0.0/24` — nur VPN-Subnetz!) |
| `peer.persistent_keepalive` | ✅ | Keepalive-Intervall in Sekunden (empfohlen: `25`) |
| `peer.preshared_key` | ❌ | Optionaler PresharedKey für zusätzliche Sicherheit |
| `nat.enabled` | ✅ | NAT/Masquerading aktivieren (`true`/`false`, Standard: `false`) |
| `nat.interface` | ❌ | Netzwerk-Interface für NAT (wird automatisch erkannt) |

### NAT / IP-Forwarding

Wenn `nat.enabled: true` gesetzt ist, richtet das Add-on automatisch iptables-Regeln ein, die Traffic zwischen dem VPN-Tunnel und dem lokalen Netzwerk weiterleiten (IP-Forwarding + Masquerading). Das ist nötig, wenn du vom VPS auf das lokale Netzwerk des Pi zugreifen willst.

```yaml
nat:
  enabled: true
  # interface: "eth0"    # Optional — wird automatisch erkannt
```

Das Netzwerk-Interface wird automatisch über die Default-Route erkannt. Nur in Ausnahmefällen (z.B. mehrere NICs) muss es manuell gesetzt werden.

### Server-Konfiguration (VPS)

Damit der VPS über den Tunnel auf das LAN des Pi zugreifen kann, muss auf dem **VPS** die WireGuard-Server-Config den richtigen Peer haben:

```ini
# /etc/wireguard/wg0.conf auf dem VPS
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = SERVER_PRIVATE_KEY

[Peer]
PublicKey = CLIENT_PUBLIC_KEY        # Public Key vom Raspberry Pi
AllowedIPs = 10.0.0.2/32, 192.168.1.0/24   # VPN-IP + LAN des Pi
```

> **Wichtig:** Das LAN-Subnetz (`192.168.1.0/24`) wird nur in `AllowedIPs` auf der **Server-Seite** eingetragen — **nicht** auf dem Client! Sonst verliert der Pi die lokale Netzwerkverbindung.

## WireGuard Keys erzeugen

Falls noch keine Keys vorhanden sind:

```bash
# Private Key erzeugen
wg genkey > privatekey

# Public Key aus Private Key ableiten
cat privatekey | wg pubkey > publickey

# Optional: PresharedKey erzeugen
wg genpsk > presharedkey
```

## Troubleshooting

### Add-on startet nicht
- Prüfe, ob `private_key` und `public_key` korrekt gesetzt sind
- Prüfe, ob der `endpoint` erreichbar ist (DNS-Auflösung, Port offen)
- Schau in die Add-on-Logs: **Settings → Add-ons → WireGuard Client → Log**

### Verbindung bricht regelmäßig ab
- Stelle sicher, dass `persistent_keepalive` gesetzt ist (empfohlen: `25`)
- Prüfe, ob der Server den Client als Peer konfiguriert hat

### Kein Internetzugang über VPN
- Setze `allowed_ips` auf `0.0.0.0/0` um allen Traffic über VPN zu routen
- Konfiguriere `dns` mit einem DNS-Server im VPN oder einem öffentlichen DNS
