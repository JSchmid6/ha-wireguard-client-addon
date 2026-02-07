---
applyTo: "**/Dockerfile"
---

# Dockerfile Instructions

## Convention
- Always use `ARG BUILD_FROM` + `FROM $BUILD_FROM` (HA Add-on standard, never hardcode the base image).
- Install packages only with `apk add --no-cache` — no unnecessary build deps.
- Make scripts executable with `chmod a+x`.
- Use `CMD [ "/run.sh" ]` as entrypoint.
- The base image is Alpine Linux (`ghcr.io/home-assistant/[arch]-base:3.19`), mapped via `build.yaml`.
- Do not add unnecessary layers. Combine related `RUN` commands where appropriate.

## Template
```dockerfile
ARG BUILD_FROM
FROM $BUILD_FROM

RUN apk add --no-cache \
    wireguard-tools \
    iptables \
    ip6tables \
    bash

COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
```
