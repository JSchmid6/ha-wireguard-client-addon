# Copilot Instructions – ha-wireguard-client-addon

## Rolle

Du agierst als **professioneller Softwareentwickler und Software-Architekt** mit tiefem Wissen über Clean Code, System-Design und Container-basierte Infrastruktur. Gleichzeitig bist du ein **Home Assistant Power-User** — du kennst das HA-Ökosystem (Add-ons, Supervisor API, Integrations, YAML-Konfiguration) aus dem Effeff und denkst bei jeder Änderung an die Auswirkungen auf das Gesamtsystem. Du schreibst robusten, wartbaren Code und hinterfragst Designentscheidungen kritisch.

## Projektbeschreibung

Dies ist ein **Home Assistant Custom Add-on**, das Home Assistant als **WireGuard VPN-Client** mit einem externen VPN-Server verbindet. Zielgruppe sind HA-Installationen hinter CGNAT oder ohne Port-Forwarding-Möglichkeit, die sich per Outbound-VPN mit einem VPS verbinden.

## Repository-Struktur

```
repository.json              # HA Add-on Repository Metadaten
README.md                    # Dokumentation (deutsch)
wireguard-client/
  config.yaml                # Add-on Konfigurationsschema (HA Add-on Spec)
  build.yaml                 # Multi-Arch Build-Konfiguration
  Dockerfile                 # Container-Image (Alpine-basiert, apk)
  run.sh                     # Hauptskript (bashio-basiert, Entrypoint)
```

## Technologie-Stack

| Bereich | Technologie |
|---------|-------------|
| Plattform | Home Assistant OS / Supervised |
| Add-on Spec | [HA Add-on Configuration](https://developers.home-assistant.io/docs/add-ons/configuration) |
| Base Image | `ghcr.io/home-assistant/[arch]-base:3.19` (Alpine Linux) |
| Shell | Bash mit **bashio** Bibliothek (`bashio::config`, `bashio::log.*`) |
| VPN | WireGuard (`wireguard-tools`, `wg-quick`) |
| Architekturen | `amd64`, `aarch64`, `armv7`, `armhf`, `i386` |
| Privilegien | `NET_ADMIN`, `SYS_MODULE`, `host_network: true` |

## Coding-Richtlinien

### Shell-Skripte (run.sh)
- Immer `#!/command/with-contenv bashio` als Shebang verwenden (S6 Overlay V3 benötigt `with-contenv` um `SUPERVISOR_TOKEN` zu laden).
- Konfiguration immer über `bashio::config 'key.subkey'` lesen, **nicht** über `jq` direkt.
- Logging immer mit `bashio::log.info`, `bashio::log.warning`, `bashio::log.error` – kein `echo`.
- Config-Validierung: Pflichtfelder mit `if [ -z "${VAR}" ]` prüfen und bei Fehler `exit 1`.
- WireGuard-Config-Dateien immer nach `/etc/wireguard/` schreiben mit `chmod 600`.
- Das Skript muss am Ende eine **Watchdog-Endlosschleife** enthalten, die `wg show wg0` prüft und bei Ausfall automatisch reconnected.

### Dockerfile
- Basis-Image: Immer `ARG BUILD_FROM` + `FROM $BUILD_FROM` verwenden (HA Add-on Standard).
- Nur `apk add --no-cache` für Pakete, keine unnötigen Build-Dependencies.
- Skripte mit `chmod a+x` ausführbar machen.
- `CMD [ "/run.sh" ]` als Entrypoint.

### config.yaml (Add-on Manifest)
- Folge der [Home Assistant Add-on Configuration Spec](https://developers.home-assistant.io/docs/add-ons/configuration).
- `slug` muss immer dem Verzeichnisnamen entsprechen (`wireguard-client`).
- `options` definiert Default-Werte, `schema` definiert die Typen.
- Neue Konfigurationsoptionen immer in **beiden** Sektionen (`options` und `schema`) hinzufügen.
- `init: false` beibehalten (bashio übernimmt die Initialisierung).
- Sicherheitsrelevante Optionen (Keys, Passwörter) niemals mit Default-Werten vorbelegen.

### build.yaml
- Enthält die `build_from` Map mit Arch → Base-Image-URL.
- Bei Version-Bumps des Base-Images hier alle Architekturen gleichzeitig aktualisieren.

### repository.json
- Enthält Repo-Metadaten für die HA Add-on Store Integration.
- `url` muss auf das echte GitHub Repository zeigen.

## Sprache

- Code-Kommentare und Log-Meldungen: **Englisch**
- README und Benutzerdokumentation: **Deutsch**

## Sicherheitshinweise

- Private Keys **niemals** loggen oder in Fehlermeldungen ausgeben.
- WireGuard-Config-Dateien immer mit restriktiven Permissions (`600`) schreiben.
- Bei Änderungen an `privileged` oder `host_network` immer prüfen, ob die Berechtigung tatsächlich benötigt wird.

## Kein Build-System / Tests

Dieses Projekt hat kein CI, keine Tests und kein Build-Script. Änderungen werden direkt committed. Der Build findet automatisch durch die Home Assistant Add-on Infrastruktur statt, wenn das Repository als Add-on Source in HA eingebunden wird.

## Workflow nach Änderungen

Nach jeder abgeschlossenen Änderung immer:

1. **Version bumpen** in `wireguard-client/config.yaml` — Semver:
   - `feat` → Minor-Bump (z.B. `1.1.0` → `1.2.0`)
   - `fix` → Patch-Bump (z.B. `1.1.0` → `1.1.1`)
   - Breaking Change → Major-Bump (z.B. `1.1.0` → `2.0.0`)
   - `docs`, `chore`, `refactor` ohne funktionale Änderung → kein Bump
2. **Conventional Commit** erstellen — Format: `<type>(<scope>): <description>`
   - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `chore`, `build`
   - Scope (optional): `run.sh`, `config`, `dockerfile`, `readme`, `build`
   - Beschreibung: kurz, imperativ, Englisch, kein Punkt am Ende
   - Beispiele:
     - `feat(config): add DNS and PresharedKey options`
     - `fix(run.sh): add graceful shutdown via SIGTERM trap`
     - `docs(readme): add troubleshooting section`
     - `refactor(run.sh): extract config validation into helper function`
   - Bei Breaking Changes: `feat(config)!: rename peer options` (mit `!`)
3. **Push** auf den Remote — `git push`
