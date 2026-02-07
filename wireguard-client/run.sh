#!/command/with-contenv bashio

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

# Optional interface configuration
INTERFACE_DNS=""
if bashio::config.has_value 'interface.dns'; then
    INTERFACE_DNS=$(bashio::config 'interface.dns')
fi

INTERFACE_MTU=""
if bashio::config.has_value 'interface.mtu'; then
    INTERFACE_MTU=$(bashio::config 'interface.mtu')
fi

PEER_PRESHARED_KEY=""
if bashio::config.has_value 'peer.preshared_key'; then
    PEER_PRESHARED_KEY=$(bashio::config 'peer.preshared_key')
fi

# NAT configuration
NAT_ENABLED=$(bashio::config 'nat.enabled')
NAT_INTERFACE=""
if [ "${NAT_ENABLED}" = "true" ]; then
    if bashio::config.has_value 'nat.interface'; then
        NAT_INTERFACE=$(bashio::config 'nat.interface')
    else
        # Auto-detect default network interface from routing table
        NAT_INTERFACE=$(ip route show default | awk '/default/ {print $5}' | head -1)
        if [ -z "${NAT_INTERFACE}" ]; then
            bashio::log.error "NAT enabled but could not auto-detect network interface!"
            bashio::log.error "Please set nat.interface manually."
            exit 1
        fi
        bashio::log.info "Auto-detected NAT interface: ${NAT_INTERFACE}"
    fi
fi

# Allowed targets — selective forwarding rules (host:port or host)
ALLOWED_TARGETS=()
if bashio::config.has_value 'nat.allowed_targets'; then
    local_idx=0
    while bashio::config.exists "nat.allowed_targets[${local_idx}]"; do
        target=$(bashio::config "nat.allowed_targets[${local_idx}]")
        ALLOWED_TARGETS+=("${target}")
        local_idx=$((local_idx + 1))
    done
    bashio::log.info "Configured ${#ALLOWED_TARGETS[@]} allowed target(s)"
fi

# Port forwards — DNAT from LAN through Pi to VPS (listen_port:dest_host:dest_port)
PORT_FORWARDS=()
if bashio::config.has_value 'nat.port_forwards'; then
    local_idx=0
    while bashio::config.exists "nat.port_forwards[${local_idx}]"; do
        fwd=$(bashio::config "nat.port_forwards[${local_idx}]")
        PORT_FORWARDS+=("${fwd}")
        local_idx=$((local_idx + 1))
    done
    bashio::log.info "Configured ${#PORT_FORWARDS[@]} port forward(s)"
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

    if [ -n "${INTERFACE_MTU}" ]; then
        echo "MTU = ${INTERFACE_MTU}"
    fi

    # NAT/Masquerading — controlled via structured config, no arbitrary commands
    if [ "${NAT_ENABLED}" = "true" ]; then
        # Build PostUp rules
        postup=""
        postdown=""

        # Conntrack: allow established/related traffic in both directions
        postup+="iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; "
        postdown+="iptables -D FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; "

        if [ ${#ALLOWED_TARGETS[@]} -gt 0 ]; then
            # Selective forwarding: only allow specific targets from VPN to LAN
            for target in "${ALLOWED_TARGETS[@]}"; do
                if [[ "${target}" == *":"* ]]; then
                    t_host="${target%%:*}"
                    t_port="${target##*:}"
                    postup+="iptables -A FORWARD -i %i -o ${NAT_INTERFACE} -d ${t_host} -p tcp --dport ${t_port} -j ACCEPT; "
                    postup+="iptables -A FORWARD -i %i -o ${NAT_INTERFACE} -d ${t_host} -p udp --dport ${t_port} -j ACCEPT; "
                    postdown+="iptables -D FORWARD -i %i -o ${NAT_INTERFACE} -d ${t_host} -p tcp --dport ${t_port} -j ACCEPT; "
                    postdown+="iptables -D FORWARD -i %i -o ${NAT_INTERFACE} -d ${t_host} -p udp --dport ${t_port} -j ACCEPT; "
                else
                    # Host only — allow all ports to this host
                    postup+="iptables -A FORWARD -i %i -o ${NAT_INTERFACE} -d ${target} -j ACCEPT; "
                    postdown+="iptables -D FORWARD -i %i -o ${NAT_INTERFACE} -d ${target} -j ACCEPT; "
                fi
            done
        else
            # No targets specified — allow all forwarding (legacy behavior)
            postup+="iptables -A FORWARD -i %i -o ${NAT_INTERFACE} -j ACCEPT; "
            postup+="iptables -A FORWARD -o %i -i ${NAT_INTERFACE} -j ACCEPT; "
            postdown+="iptables -D FORWARD -i %i -o ${NAT_INTERFACE} -j ACCEPT; "
            postdown+="iptables -D FORWARD -o %i -i ${NAT_INTERFACE} -j ACCEPT; "
        fi

        # Port forwards: DNAT from LAN interface to VPN destinations
        for fwd in "${PORT_FORWARDS[@]}"; do
            listen_port="${fwd%%:*}"
            remainder="${fwd#*:}"
            dest_host="${remainder%%:*}"
            dest_port="${remainder##*:}"
            # DNAT incoming traffic on NAT_INTERFACE to VPN destination
            postup+="iptables -t nat -A PREROUTING -i ${NAT_INTERFACE} -p tcp --dport ${listen_port} -j DNAT --to-destination ${dest_host}:${dest_port}; "
            postup+="iptables -A FORWARD -i ${NAT_INTERFACE} -o %i -d ${dest_host} -p tcp --dport ${dest_port} -j ACCEPT; "
            postdown+="iptables -t nat -D PREROUTING -i ${NAT_INTERFACE} -p tcp --dport ${listen_port} -j DNAT --to-destination ${dest_host}:${dest_port}; "
            postdown+="iptables -D FORWARD -i ${NAT_INTERFACE} -o %i -d ${dest_host} -p tcp --dport ${dest_port} -j ACCEPT; "
        done

        # MASQUERADE for VPN→LAN traffic
        postup+="iptables -t nat -A POSTROUTING -o ${NAT_INTERFACE} -j MASQUERADE; "
        postdown+="iptables -t nat -D POSTROUTING -o ${NAT_INTERFACE} -j MASQUERADE; "

        # MASQUERADE for LAN→VPN traffic (port forwards)
        if [ ${#PORT_FORWARDS[@]} -gt 0 ]; then
            postup+="iptables -t nat -A POSTROUTING -o %i -j MASQUERADE"
            postdown+="iptables -t nat -D POSTROUTING -o %i -j MASQUERADE"
        fi

        # Remove trailing "; " if present
        postup="${postup%%; }"
        postdown="${postdown%%; }"

        echo "PostUp = ${postup}"
        echo "PostDown = ${postdown}"
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
if [ -n "${INTERFACE_MTU}" ]; then
    bashio::log.info "MTU: ${INTERFACE_MTU}"
fi
if [ "${NAT_ENABLED}" = "true" ]; then
    bashio::log.info "NAT/Masquerading: enabled (interface: ${NAT_INTERFACE})"
    if [ ${#ALLOWED_TARGETS[@]} -gt 0 ]; then
        bashio::log.info "Allowed targets: ${ALLOWED_TARGETS[*]}"
    else
        bashio::log.info "Allowed targets: all (no restrictions)"
    fi
    for fwd in "${PORT_FORWARDS[@]}"; do
        listen_port="${fwd%%:*}"
        remainder="${fwd#*:}"
        dest_host="${remainder%%:*}"
        dest_port="${remainder##*:}"
        bashio::log.info "Port forward: LAN:${listen_port} → ${dest_host}:${dest_port}"
    done
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
