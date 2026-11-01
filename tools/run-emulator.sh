#!/bin/sh
set -eu

build=/project/.pio/build/supermini
state=/project/.pio/emulator
packages=/project/.pio/core/packages

# Reuse the flash image so NVS and OTA changes survive container recreation.
if [ ! -f "$state/flash.bin" ]; then
    if [ ! -f "$build/firmware.elf" ]; then
        echo 'Build firmware first: docker compose run --rm --build platformio' >&2
        exit 1
    fi
    mkdir -p "$state"
    python "$packages/tool-esptoolpy/esptool.py" --chip esp32s3 merge_bin \
        -o "$state/flash.tmp.bin" \
        --flash_mode keep --flash_freq keep --flash_size 4MB \
        0x0 "$build/bootloader.bin" \
        0x8000 "$build/partitions.bin" \
        0xe000 "$packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin" \
        0x10000 "$build/firmware.bin"
    cp "$build/firmware.elf" "$state/firmware.elf"
    mv "$state/flash.tmp.bin" "$state/flash.bin"
fi

exec esp-emu --chip esp32s3 \
    --firmware "$state/flash.bin" --elf "$state/firmware.elf" \
    --console usb-jtag --psram-size 2M \
    --wifi-ssid myssid --wifi-password mypassword \
    --net 'user,hostfwd=tcp:0.0.0.0:18080-:80' \
    --save-state "$@"
