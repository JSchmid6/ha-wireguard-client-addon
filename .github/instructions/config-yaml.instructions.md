---
applyTo: "**/config.yaml"
---

# Add-on config.yaml Instructions

## Convention
- Follow the [Home Assistant Add-on Configuration Spec](https://developers.home-assistant.io/docs/add-ons/configuration).
- `slug` must match the directory name (`wireguard-client`).
- `options` defines default values, `schema` defines types.
- When adding new config options, always add them to **both** `options` and `schema`.
- Keep `init: false` (bashio handles initialization).
- Never set default values for security-sensitive fields (keys, passwords) — leave them as empty strings `""`.
- Supported schema types: `str`, `int`, `bool`, `float`, `email`, `url`, `port`, `match()`, `list()`, `password`.
- Required capabilities: `NET_ADMIN`, `SYS_MODULE` in `privileged`, and `host_network: true`.
- Supported architectures: `armhf`, `armv7`, `aarch64`, `amd64`, `i386`.
