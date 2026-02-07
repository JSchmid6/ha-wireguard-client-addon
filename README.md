# Home Assistant WireGuard Client Add-on

Ein Custom Add-on um Home Assistant als WireGuard Client zu einem externen VPN-Server zu verbinden.

## Use Case

Ideal für Home Assistant Systeme hinter CGNAT oder ohne Port-Forwarding-Möglichkeit, die sich per Outbound-VPN mit einem externen VPS verbinden sollen.

## Features

- ✅ WireGuard als Client (outbound connection)
- ✅ Kein Port-Forwarding notwendig
- ✅ Automatischer Reconnect bei Verbindungsabbruch
- ✅ Persistent nach Reboot
- ✅ Graceful Shutdown (sauberes Herunterfahren der VPN-Verbindung)
- ✅ Optionale DNS-Konfiguration
- ✅ PresharedKey-Unterstützung für zusätzliche Sicherheit
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
  dns: "1.1.1.1, 8.8.8.8"

peer:
  public_key: "SERVER_PUBLIC_KEY"
  endpoint: "vpn.example.com:51820"
  allowed_ips: "10.0.0.0/24"
  persistent_keepalive: 25
  preshared_key: "OPTIONALER_PRESHARED_KEY"
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
| `peer.public_key` | ✅ | WireGuard Public Key des Servers |
| `peer.endpoint` | ✅ | Server-Adresse mit Port (z.B. `vpn.example.com:51820`) |
| `peer.allowed_ips` | ✅ | Erlaubte IP-Bereiche (z.B. `10.0.0.0/24` oder `0.0.0.0/0` für alles) |
| `peer.persistent_keepalive` | ✅ | Keepalive-Intervall in Sekunden (empfohlen: `25`) |
| `peer.preshared_key` | ❌ | Optionaler PresharedKey für zusätzliche Sicherheit |

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
