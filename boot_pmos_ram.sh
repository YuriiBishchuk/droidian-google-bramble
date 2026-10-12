#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOT_IMG="$DIR/saved_builds/pmos_bringup_20261011/pmos_tethered_boot.img"

echo "==========================================================="
echo " Google Pixel 4a (5G) postmarketOS Tethered RAM Boot "
echo "==========================================================="

if [ ! -f "$BOOT_IMG" ]; then
    echo "[!] Error: Boot image not found: $BOOT_IMG"
    exit 1
fi

if ! fastboot devices | grep -q "fastboot"; then
    echo "[*] Phone not in fastboot. Checking adb..."
    if adb devices | grep -q "device$"; then
        echo "[*] Rebooting phone to bootloader..."
        adb reboot bootloader
        echo "[*] Waiting for fastboot detection..."
        while ! fastboot devices | grep -q "fastboot"; do
            sleep 1
        done
    else
        echo "[!] Phone not detected in adb or fastboot. Please connect device."
        exit 1
    fi
fi

echo "[*] Device detected in fastboot: $(fastboot devices | awk '{print $1}')"
echo "[*] Booting unified pmos_tethered_boot.img (Kernel + 329 Modules + LZ4 Ramdisk) in RAM..."
fastboot boot "$BOOT_IMG"

echo ""
echo "==========================================================="
echo " [OK] Tethered RAM Boot initiated successfully!"
echo " Flash is 100% untouched. Any reboot returns to LineageOS."
echo " Checking for USB network interface (172.16.42.1)..."
echo "==========================================================="
