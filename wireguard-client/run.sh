#!/usr/bin/env bashio

# ==============================================================================
# Home Assistant WireGuard Client Add-on
# Connects Home Assistant as WireGuard VPN client to an external server
# ==============================================================================

readonly WG_INTERFACE="wg0"
readonly WG_CONFIG="/etc/wireguard/${WG_INTERFACE}.conf"
readonly WATCHDOG_INTERVAL=30
readonly RECONNECT_DELAY=5

# ------------------------------------------------------------------------------
# Cleanup handler — gracefully tear down WireGuard on SIGTERM/SIGINT
# ------------------------------------------------------------------------------
cleanup() {
    bashio::log.info "Shutting down WireGuard interface..."
    wg-quick down "${WG_INTERFACE}" 2>/dev/null || true
    bashio::log.info "WireGuard stopped. Goodbye."
    exit 0
}
trap cleanup SIGTERM SIGINT

# ------------------------------------------------------------------------------
# Validate that a config value is not empty
# Arguments: $1 = config key, $2 = human-readable label
# ------------------------------------------------------------------------------
require_config() {
    local key="${1}"
    local label="${2}"
    local value

    value=$(bashio::config "${key}")
    if [ -z "${value}" ]; then
        bashio::log.error "${label} is not configured!"
        bashio::log.error "Please check your add-on configuration."
        exit 1
    fi
    echo "${value}"
}

# ==============================================================================
# Read and validate configuration
# ==============================================================================
bashio::log.info "Starting WireGuard Client..."

INTERFACE_ADDRESS=$(require_config 'interface.address' "Interface address")
INTERFACE_PRIVATE_KEY=$(require_config 'interface.private_key' "Interface private key")
PEER_PUBLIC_KEY=$(require_config 'peer.public_key' "Peer public key")
PEER_ENDPOINT=$(require_config 'peer.endpoint' "Peer endpoint")
PEER_ALLOWED_IPS=$(require_config 'peer.allowed_ips' "Peer allowed IPs")
PEER_KEEPALIVE=$(bashio::config 'peer.persistent_keepalive')

# Optional configuration
INTERFACE_DNS=""
if bashio::config.has_value 'interface.dns'; then
    INTERFACE_DNS=$(bashio::config 'interface.dns')
fi

PEER_PRESHARED_KEY=""
if bashio::config.has_value 'peer.preshared_key'; then
    PEER_PRESHARED_KEY=$(bashio::config 'peer.preshared_key')
fi

# ==============================================================================
# Generate WireGuard configuration
# ==============================================================================
mkdir -p /etc/wireguard

{
    echo "[Interface]"
    echo "Address = ${INTERFACE_ADDRESS}"
    echo "PrivateKey = ${INTERFACE_PRIVATE_KEY}"
    if [ -n "${INTERFACE_DNS}" ]; then
        echo "DNS = ${INTERFACE_DNS}"
    fi
    echo ""
    echo "[Peer]"
    echo "PublicKey = ${PEER_PUBLIC_KEY}"
    echo "Endpoint = ${PEER_ENDPOINT}"
    echo "AllowedIPs = ${PEER_ALLOWED_IPS}"
    echo "PersistentKeepalive = ${PEER_KEEPALIVE}"
    if [ -n "${PEER_PRESHARED_KEY}" ]; then
        echo "PresharedKey = ${PEER_PRESHARED_KEY}"
    fi
} > "${WG_CONFIG}"

chmod 600 "${WG_CONFIG}"

bashio::log.info "WireGuard configuration generated"
bashio::log.info "Endpoint: ${PEER_ENDPOINT}"
bashio::log.info "Address: ${INTERFACE_ADDRESS}"
bashio::log.info "Allowed IPs: ${PEER_ALLOWED_IPS}"
if [ -n "${INTERFACE_DNS}" ]; then
    bashio::log.info "DNS: ${INTERFACE_DNS}"
fi

# ==============================================================================
# Start WireGuard
# ==============================================================================
bashio::log.info "Bringing up WireGuard interface..."
if ! wg-quick up "${WG_INTERFACE}"; then
    bashio::log.error "Failed to start WireGuard!"
    exit 1
fi

bashio::log.info "WireGuard interface is up!"
wg show "${WG_INTERFACE}"

# ==============================================================================
# Watchdog — monitor connection and auto-reconnect
# ==============================================================================
bashio::log.info "Entering watchdog loop (interval: ${WATCHDOG_INTERVAL}s)..."

while true; do
    sleep "${WATCHDOG_INTERVAL}"

    if ! wg show "${WG_INTERFACE}" > /dev/null 2>&1; then
        bashio::log.warning "WireGuard interface down, attempting reconnect..."
        wg-quick down "${WG_INTERFACE}" 2>/dev/null || true
        sleep "${RECONNECT_DELAY}"

        if wg-quick up "${WG_INTERFACE}"; then
            bashio::log.info "WireGuard reconnected successfully"
            wg show "${WG_INTERFACE}"
        else
            bashio::log.error "WireGuard reconnect failed, will retry in ${WATCHDOG_INTERVAL}s"
        fi
    fi
done
