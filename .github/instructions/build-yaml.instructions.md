---
applyTo: "**/build.yaml"
---

# build.yaml Instructions

## Convention
- Contains the `build_from` map: architecture → base image URL.
- All architectures must use the same base image version.
- When bumping the base image version, update **all** architectures simultaneously.
- Format: `ghcr.io/home-assistant/[arch]-base:[version]`
- Supported architectures: `aarch64`, `amd64`, `armhf`, `armv7`, `i386`.
