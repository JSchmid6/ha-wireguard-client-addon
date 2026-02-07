---
name: bashio-scripting
description: Write or modify bashio-based shell scripts for the Home Assistant add-on. Use when editing run.sh, adding new features to the entrypoint script, or debugging the add-on's runtime behavior.
---

# Bashio Scripting Skill

## Overview
The add-on's entrypoint `run.sh` uses **bashio**, the standard shell library for Home Assistant add-ons. It provides helpers for reading HA add-on configuration, logging, and interacting with the HA Supervisor API.

## Key bashio Functions

### Configuration
```bash
# Read a config value (returns the value from /data/options.json)
VALUE=$(bashio::config 'section.key')

# Check if a config key exists
if bashio::config.has_value 'section.key'; then ...

# Check if a config key is true (boolean)
if bashio::config.true 'section.flag'; then ...
```

### Logging
```bash
bashio::log.info "Informational message"
bashio::log.notice "Notable event"
bashio::log.warning "Warning message"
bashio::log.error "Error message"
bashio::log.fatal "Fatal error"
bashio::log.debug "Debug message"
```

### Supervisor API
```bash
# Get HA info
bashio::info.hostname
bashio::info.arch

# Service calls
bashio::services 'mqtt' 'host'
```

## Script Structure Pattern
```bash
#!/command/with-contenv bashio

# 1. Read configuration
VAR=$(bashio::config 'key')

# 2. Validate configuration
if [ -z "${VAR}" ]; then
    bashio::log.error "Key is not configured!"
    exit 1
fi

# 3. Setup (write config files, prepare environment)
# ...

# 4. Start the service
# ...

# 5. Watchdog loop
while true; do
    # Check service health
    sleep 30
done
```

## Important Rules
- **Never** use `echo` for output — always use `bashio::log.*`
- **Never** use `jq` to read `/data/options.json` — always use `bashio::config`
- **Never** log secret values (private keys, passwords)
- The script must stay running (watchdog loop) — if it exits, the add-on stops
- Use `set +e` if you need to handle command failures without exiting

## Reference
- [bashio GitHub](https://github.com/hassio-addons/bashio)
- [bashio function reference](https://github.com/hassio-addons/bashio/tree/main/lib)
