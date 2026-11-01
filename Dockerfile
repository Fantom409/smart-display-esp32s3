FROM python:3.12-slim-bookworm

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
