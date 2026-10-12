#!/bin/bash
# ==============================================================================
# flash_droidian.sh: Fastboot Flasher for Droidian on Google Pixel 4a (5G)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOT_DIR="$SCRIPT_DIR/boot/output"
DOWNLOAD_DIR="$SCRIPT_DIR/downloads"

echo "=============================================================================="
echo "📱 Google Pixel 4a (5G) (bramble) - Droidian (Halium 11) Flasher"
echo "=============================================================================="

if ! command -v fastboot >/dev/null; then
	echo "❌ Error: fastboot utility not found in PATH!"
	exit 1
fi

echo "==> Checking for connected Fastboot device..."
DEVICE=$(fastboot devices | head -n 1 | awk '{print $1}')
if [ -z "$DEVICE" ]; then
	echo "⚠️  No device detected in Fastboot mode!"
	echo "   Please reboot phone into bootloader: 'adb reboot bootloader'"
	echo "   or hold Power + Volume Down."
	exit 1
fi
echo "    Found device: $DEVICE"

# Ensure boot images exist
if [ ! -f "$BOOT_DIR/boot.img" ] || [ ! -f "$BOOT_DIR/vendor_boot.img" ]; then
	echo "==> Boot images not found, building now..."
	"$SCRIPT_DIR/boot/build_boot.sh"
fi

echo ""
echo "Select flashing option:"
echo "  1) Flash Kernel & Bootloader only (boot.img + vendor_boot.img)"
echo "  2) Full Droidian Install (Download Rootfs + Flash All)"
echo "  3) Fastboot Boot Test (boot.img)"
read -rp "Enter choice [1-3]: " CHOICE

case "$CHOICE" in
	1)
		echo "==> Flashing Droidian Halium Bootloader..."
		fastboot flash boot "$BOOT_DIR/boot.img"
		fastboot flash vendor_boot "$BOOT_DIR/vendor_boot.img"
		echo "✅ Bootloader flashed successfully!"
		;;
	2)
		mkdir -p "$DOWNLOAD_DIR"
		ROOTFS_URL="https://github.com/droidian-images/droidian/releases/download/nightly/droidian-OFFICIAL-phosh-phone-rootfs-api30-arm64-next_20261007.zip"
		ROOTFS_ZIP="$DOWNLOAD_DIR/droidian-rootfs-api30.zip"
		if [ ! -f "$ROOTFS_ZIP" ]; then
			echo "==> Downloading official Droidian API 30 Rootfs (~1.4 GB)..."
			wget -c "$ROOTFS_URL" -O "$ROOTFS_ZIP"
		fi

		echo "==> Unpacking Rootfs..."
		unzip -o "$ROOTFS_ZIP" -d "$DOWNLOAD_DIR/extracted"

		echo "==> Flashing Droidian Partitions..."
		fastboot flash boot "$BOOT_DIR/boot.img"
		fastboot flash vendor_boot "$BOOT_DIR/vendor_boot.img"
		if [ -f "$DOWNLOAD_DIR/extracted/data/userdata.img" ]; then
			fastboot flash userdata "$DOWNLOAD_DIR/extracted/data/userdata.img"
		fi
		echo "✅ Full Droidian installation completed! Rebooting..."
		fastboot reboot
		;;
	3)
		echo "==> Testing boot.img via 'fastboot boot'..."
		fastboot boot "$BOOT_DIR/boot.img"
		;;
	*)
		echo "Invalid option."
		exit 1
		;;
esac
