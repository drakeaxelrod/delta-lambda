# Delta Lambda split keyboard — ZMK firmware build commands

root    := justfile_directory()
zmk_app := root / "zmk/app"
bdir    := root / ".build"
out     := root / "build"
config  := root / "config"

# List available commands
default:
    @just --list

# Initialize west workspace (first time only)
init:
    west init -l config
    west update
    west zephyr-export

# Update west modules (ZMK, Zephyr, etc.)
update:
    west update

# Build firmware (left half acts as central via BLE)
build: _build-left _build-right _build-reset
    mkdir -p {{out}}
    install -m 644 {{bdir}}/left/zephyr/zmk.uf2   {{out}}/delta-lambda-left.uf2
    install -m 644 {{bdir}}/right/zephyr/zmk.uf2   {{out}}/delta-lambda-right.uf2
    install -m 644 {{bdir}}/reset/zephyr/zmk.uf2   {{out}}/delta-lambda-reset.uf2
    @echo ""
    @echo "Firmware ready:"
    @ls -1 {{out}}/delta-lambda-*.uf2

# ── Internal build targets ──────────────────────────────────────────

_build-left:
    west build -s {{zmk_app}} -d {{bdir}}/left -b seeeduino_xiao_ble -- \
        -DSHIELD=delta_lambda_left -DZMK_CONFIG={{config}}

_build-right:
    west build -s {{zmk_app}} -d {{bdir}}/right -b seeeduino_xiao_ble -- \
        -DSHIELD=delta_lambda_right -DZMK_CONFIG={{config}}

_build-reset:
    west build -s {{zmk_app}} -d {{bdir}}/reset -b seeeduino_xiao_ble -- \
        -DSHIELD=settings_reset -DZMK_CONFIG={{config}}

# Flash a target to plugged-in XIAO (double-tap reset first)
# Usage: just flash left | right | reset
flash target:
    #!/usr/bin/env bash
    set -euo pipefail
    dev="/dev/disk/by-label/XIAO-SENSE"
    if [ ! -e "$dev" ]; then
        echo "XIAO not found — double-tap reset and try again"
        exit 1
    fi
    mountpoint=$(udisksctl mount -b "$dev" 2>/dev/null | grep -oP 'at \K.*' || true)
    if [ -z "$mountpoint" ]; then
        mountpoint="/run/media/$USER/XIAO-SENSE"
    fi
    cp "{{out}}/delta-lambda-{{target}}.uf2" "$mountpoint/"
    echo "Flashed {{target}}"

# Download XIAO nRF52840 bootloader
bootloader:
    mkdir -p {{out}}
    curl -fSL -o {{out}}/xiao-bootloader-update.uf2 \
        "https://github.com/0hotpotman0/BLE_52840_Core/raw/main/bootloader/Seeed_XIAO_nRF52840_Sense/update-Seeed_XIAO_nRF52840_Sense_bootloader-0.6.1_nosd.uf2"
    @echo "Bootloader saved to {{out}}/xiao-bootloader-update.uf2"

# Generate SVG layer diagrams
gen-svg:
    python tools/gen_svg_layers.py

# Open serial console
serial device="/dev/ttyACM0":
    picocom -b 115200 {{device}}

# Clean build artifacts
clean:
    rm -rf {{bdir}}
    @echo "Cleaned .build/"
