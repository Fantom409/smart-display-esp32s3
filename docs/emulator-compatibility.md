## Verification results

| Check | Observed result |
|---|---|
| Current source build | `docker compose run --rm platformio run` succeeded; static RAM 54,044 bytes; app size 1,657,553 bytes, 84.3% of OTA slot |
| Normal ROM/bootloader boot | Reached Arduino `setup()` without bypassing ROM or bootloader |
| PSRAM | Detected 2,045 KB free initially; frame buffer and background copy both allocated in PSRAM |
| First boot | Started `SmartDisplay` AP, captive-portal handlers, and web server |
| AP HTTP access | `/api/status`, `/wifi`, and `/screen.bmp` returned successfully through host forwarding |
| Provisioning | Submitted test credentials through `POST /wifi`; rebooted and recovered stored SSID/city settings |
| Station connection | Connected on first attempt; IP `192.168.4.2`, DNS `192.168.4.1`, RSSI -30 dBm |
| Internet access | Geolocation returned Kyiv/Europe/Kyiv; Markets snapshot contained prices and sparkline charts |
| Clock | Screenshots displayed current time/date; timezone switched to the Europe/Kyiv POSIX rule |
| All seven modes | Selected IDs 0–6 through `POST /mode`; status API reported each requested ID |
| Framebuffer snapshots | Each mode returned a valid 240×280 BMP, 201,654 bytes; visually inspected the captured images |
| Saved flash persistence | A fresh emulator process recovered `myssid`, Kyiv and mode 6 from saved NVS and reconnected on its first attempt |
| Bounded run | Completed the 90-second emulator run with no intercepted application panic |

## Caveats and unverified features

- Use **`--console usb-jtag`**. The firmware uses Arduino HWCDC
  (`ARDUINO_USB_MODE=1`, `ARDUINO_USB_CDC_ON_BOOT=1`); the emulator's automatic
  console selection may omit these application logs. See the official
  [console documentation](https://github.com/espressif/esp-emulator/blob/main/docs/guides/CLI.md).
- Startup logs `spiAttachMISO(): HSPI Does not have default pins on ESP32S3!`.
  TFT_eSPI passes the configured `TFT_MISO=-1` to Arduino's SPI initialization;
  Arduino logs this when HSPI has no default MISO. Startup and rendering continued.
  This warning alone does not establish a display failure.
- The software-requested reboot after provisioning appeared as ROM reset
  `RTCWDT_SYS_RST` and application reset reason `other watchdog (7)`.
  Settings survived and the station connected. Reset-reason fidelity is therefore
  not verified; this result does not diagnose a watchdog problem on real hardware.
- One status request during the mode sweep failed with a connection reset and
  succeeded on retry. Additional client-close/write-reset messages appeared in
  the firmware log. HTTP worked, but this was not a sustained reliability test.
- `/screen.bmp` verifies the firmware's RAM framebuffer. It does not prove that
  an ST7789 panel receives correct SPI commands, offsets, colors or timing.
  The documented CLI provides no ST7789 panel visualization option.
- Physical TTP223 gestures and the optional capacitive-touch path were not tested.
- Weather retrieval was skipped because no WeatherAPI key was supplied.
  OTA upload, OTA slot switching, browser/WASM execution, no-PSRAM operation,
  alternate PSRAM sizes and long-duration stability were not tested.

## Reproduce

For the Docker service, run `docker compose up --build -d esp-emulator` and
open <http://localhost:18080/wifi>. It builds the firmware, merges a flash image
on first start, and keeps it in `.pio/emulator/` across container recreation.
Provision `myssid` / `mypassword`, then open <http://localhost:18080/>.
Stop with `docker compose stop esp-emulator`; delete `.pio/emulator/` while
stopped to reset settings and load the latest build on the next start.
See the [README](../README.md#run-without-a-board) for details.

### Native emulator

Install the pinned native release using Espressif's
[release assets](https://github.com/espressif/esp-emulator/releases/tag/v0.51.0)
and verify its checksum. Run the following from the repository root with
`esp-emu` on `PATH`.

```sh
docker compose run --rm platformio run

# Create a disposable merged image; the OTA-only firmware.bin cannot boot alone.
# These offsets come from the current min_spiffs partition layout.
python3 .pio/core/packages/tool-esptoolpy/esptool.py --chip esp32s3 merge_bin \
  -o /tmp/smart-display-esp-emu-full.bin \
  --flash_mode keep --flash_freq keep --flash_size 4MB \
  0x0 .pio/build/supermini/bootloader.bin \
  0x8000 .pio/build/supermini/partitions.bin \
  0xe000 .pio/core/packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin \
  0x10000 .pio/build/supermini/firmware.bin

esp-emu --chip esp32s3 \
  --firmware /tmp/smart-display-esp-emu-full.bin \
  --elf .pio/build/supermini/firmware.elf \
  --console usb-jtag --psram-size 2M \
  --wifi-ssid myssid --wifi-password mypassword \
  --net 'user,hostfwd=tcp:127.0.0.1:18080-:80' \
  --timeout 90s --save-state
```

While the emulator runs, open <http://127.0.0.1:18080/wifi> and provision
SSID `myssid`, password `mypassword`. These are disposable emulator credentials.
After reboot the station joins the emulator's virtual AP. Requests in flight
during reboot may fail and need to be repeated.

```sh
curl --fail http://127.0.0.1:18080/api/status
curl --fail -d 'mode=6' http://127.0.0.1:18080/mode
curl --fail http://127.0.0.1:18080/screen.bmp -o /tmp/screen.bmp
```

`--save-state` writes NVS and other flash changes back to the disposable image
on exit. Launch it again to retain settings; rerun the merge command to start
with blank settings. No physical ESP32 is flashed.

The native backend supports both firmware AP and station access; see
[Espressif's networking guide](https://github.com/espressif/esp-emulator/blob/main/docs/guides/NETWORKING.md).
The hosted browser emulator needs a local proxy for networking, so these native
results should not be assumed to apply to the hosted browser unchanged.
