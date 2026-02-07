---
name: ha-addon-manifest
description: Work with the Home Assistant Add-on manifest (config.yaml, build.yaml, repository.json). Use when changing add-on metadata, version bumps, adding new architectures, or modifying capabilities and permissions.
---

# Home Assistant Add-on Manifest Skill

## Overview
This skill covers the HA Add-on manifest files that define the add-on's metadata, build configuration, and repository registration.

## Files

### config.yaml
The main add-on manifest. Key fields:
- `name`: Display name in HA UI
- `version`: Semver version string (bump manually for releases)
- `slug`: Must match directory name (`wireguard-client`)
- `description`: Short English description
- `arch`: List of supported architectures
- `init`: Set to `false` (bashio handles init)
- `privileged`: Linux capabilities (`NET_ADMIN`, `SYS_MODULE`)
- `host_network`: Must be `true` for WireGuard
- `options`: Default configuration values
- `schema`: Type definitions for options

### build.yaml
Maps architectures to base images:
```yaml
build_from:
  aarch64: ghcr.io/home-assistant/aarch64-base:3.19
  amd64: ghcr.io/home-assistant/amd64-base:3.19
  armhf: ghcr.io/home-assistant/armhf-base:3.19
  armv7: ghcr.io/home-assistant/armv7-base:3.19
  i386: ghcr.io/home-assistant/i386-base:3.19
```

### repository.json
```json
{
  "name": "...",
  "url": "https://github.com/...",
  "maintainer": "..."
}
```

## Version Bump Checklist
1. Update `version` in `config.yaml`
2. Update CHANGELOG / README if applicable
3. Commit and push — HA builds automatically from the repo

## Schema Types
Available types for `schema` in `config.yaml`:
- `str` — string
- `int` — integer
- `bool` — boolean
- `float` — floating point
- `email` — email address
- `url` — URL
- `port` — port number (1-65535)
- `password` — password (hidden in UI)
- `match(regex)` — string matching regex
- `list(type)` — list of given type

## Reference
- [HA Add-on Configuration Docs](https://developers.home-assistant.io/docs/add-ons/configuration)
- [HA Add-on Repository Docs](https://developers.home-assistant.io/docs/add-ons/repository)
