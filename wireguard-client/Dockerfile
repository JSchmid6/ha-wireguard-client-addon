ARG BUILD_FROM
FROM $BUILD_FROM

# Install WireGuard
RUN apk add --no-cache \
    wireguard-tools \
    iptables \
    ip6tables \
    bash

# Copy run script
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
