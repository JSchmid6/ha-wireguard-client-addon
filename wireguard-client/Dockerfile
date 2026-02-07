ARG BUILD_FROM
FROM $BUILD_FROM

# Install WireGuard and networking tools
RUN apk add --no-cache \
    wireguard-tools \
    iptables \
    ip6tables

# Copy entrypoint script
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
