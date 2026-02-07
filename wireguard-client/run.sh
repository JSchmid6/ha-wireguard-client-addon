#!/usr/bin/env bashio

CONFIG_PATH=/data/options.json

# Read configuration
INTERFACE_ADDRESS=$(bashio::config 'interface.address')
INTERFACE_PRIVATE_KEY=$(bashio::config 'interface.private_key')
PEER_PUBLIC_KEY=$(bashio::config 'peer.public_key')
PEER_ENDPOINT=$(bashio::config 'peer.endpoint')
PEER_ALLOWED_IPS=$(bashio::config 'peer.allowed_ips')
PEER_KEEPALIVE=$(bashio::config 'peer.persistent_keepalive')

bashio::log.info "Starting WireGuard Client..."

# Create WireGuard config
mkdir -p /etc/wireguard
cat > /etc/wireguard/wg0.conf <<WGEOF
[Interface]
Address = ${INTERFACE_ADDRESS}
PrivateKey = ${INTERFACE_PRIVATE_KEY}

[Peer]
PublicKey = ${PEER_PUBLIC_KEY}
Endpoint = ${PEER_ENDPOINT}
AllowedIPs = ${PEER_ALLOWED_IPS}
PersistentKeepalive = ${PEER_KEEPALIVE}
WGEOF

chmod 600 /etc/wireguard/wg0.conf

bashio::log.info "WireGuard config created"
bashio::log.info "Endpoint: ${PEER_ENDPOINT}"
bashio::log.info "Address: ${INTERFACE_ADDRESS}"

# Start WireGuard
bashio::log.info "Bringing up WireGuard interface..."
wg-quick up wg0

# Check status
if wg show wg0 > /dev/null 2>&1; then
    bashio::log.info "WireGuard interface is up!"
    wg show wg0
else
    bashio::log.error "Failed to start WireGuard!"
    exit 1
fi

# Keep container running and monitor connection
while true; do
    if ! wg show wg0 > /dev/null 2>&1; then
        bashio::log.warning "WireGuard interface down, restarting..."
        wg-quick down wg0 2>/dev/null || true
        sleep 5
        wg-quick up wg0
    fi
    sleep 30
done
