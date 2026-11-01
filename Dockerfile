FROM python:3.12-slim-bookworm AS platformio

ARG PLATFORMIO_VERSION=6.2.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git libusb-1.0-0 \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir "platformio==${PLATFORMIO_VERSION}"

ENV HOME=/tmp \
    PLATFORMIO_CORE_DIR=/project/.pio/core

WORKDIR /project
USER 1000:1000

ENTRYPOINT ["pio"]
CMD ["run"]

FROM platformio AS esp-emulator

USER root
ARG TARGETARCH
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && case "$TARGETARCH" in \
         amd64) arch=x86_64; checksum=2b9e157470edb8b03167996550292c6df8cc6716025ebad8927db950d7931417 ;; \
         arm64) arch=aarch64; checksum=3fca854df8d1fc2fc73e37f3a4e9db214166d0e07dfdbd4702019fd9dcc3146f ;; \
         *) echo "Unsupported emulator architecture: $TARGETARCH" >&2; exit 1 ;; \
       esac \
    && archive="esp-emu-0.51.0-${arch}-unknown-linux-gnu" \
    && curl -fsSL --retry 3 "https://github.com/espressif/esp-emulator/releases/download/v0.51.0/${archive}.tar.gz" -o /tmp/esp-emu.tar.gz \
    && echo "$checksum  /tmp/esp-emu.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/esp-emu.tar.gz -C /tmp \
    && install -m 755 "/tmp/${archive}/esp-emu" /usr/local/bin/esp-emu \
    && rm -rf /tmp/esp-emu.tar.gz "/tmp/${archive}"

COPY --chmod=755 tools/run-emulator.sh /usr/local/bin/run-emulator
USER 1000:1000
ENTRYPOINT ["run-emulator"]
CMD []
