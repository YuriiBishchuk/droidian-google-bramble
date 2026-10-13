#!/bin/bash
# ==============================================================================
# flash_stock_a13_base.sh: Flash Google Stock Android 13 Base to Pixel 4a (5G)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMG_DIR="$SCRIPT_DIR/downloads/stock_a13/extracted"

echo "=============================================================================="
echo "📱 Google Pixel 4a (5G) - Flashing Stock Android 13 (API 33) Base"
echo "=============================================================================="

if ! command -v fastboot >/dev/null; then
    echo "❌ Error: fastboot not found in PATH!"
    exit 1
fi

echo "==> [1/6] Flashing Bootloader..."
fastboot flash bootloader "$IMG_DIR/bootloader-bramble-b5-0.5-9825706.img"
fastboot reboot-bootloader
sleep 3

echo "==> [2/6] Flashing Radio (Modem)..."
fastboot flash radio "$IMG_DIR/radio-bramble-g7250-00258-230518-b-10157620.img"
fastboot reboot-bootloader
sleep 3

echo "==> [3/6] Flashing Kernel (boot.img)..."
fastboot flash boot "$IMG_DIR/boot.img"

echo "==> [4/6] Flashing Vendor Boot (vendor_boot.img)..."
fastboot flash vendor_boot "$IMG_DIR/vendor_boot.img"

echo "==> [5/6] Flashing Device Tree (dtbo.img)..."
fastboot flash dtbo "$IMG_DIR/dtbo.img"

echo "==> [6/6] Flashing VBMeta (permissive)..."
fastboot flash vbmeta "$IMG_DIR/vbmeta.img" --disable-verity --disable-verification

echo "=============================================================================="
echo "✅ Stock Android 13 Base flashed successfully!"
echo "=============================================================================="
