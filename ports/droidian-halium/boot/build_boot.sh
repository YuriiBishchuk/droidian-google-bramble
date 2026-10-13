#!/bin/bash
# ==============================================================================
# build_boot.sh: Build Droidian Halium Boot Images for Pixel 4a (5G) (bramble)
# Pixel Boot Header v3 + LineageOS 20 Android 13 Kernel (4.19.269) + LZ4 Ramdisk
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAMDISK_DIR="$SCRIPT_DIR/ramdisk"
KERNEL_DIR="$SCRIPT_DIR/kernel"
OUTPUT_DIR="$SCRIPT_DIR/output"

mkdir -p "$OUTPUT_DIR"

echo "==> [1/3] Packing Droidian Halium Ramdisk (LZ4)..."
(
	cd "$RAMDISK_DIR"
	find . | cpio -o -H newc | lz4 -l -12 --favor-decSpeed > "$OUTPUT_DIR/ramdisk.lz4"
)
echo "    Ramdisk packed: $(ls -lh "$OUTPUT_DIR/ramdisk.lz4" | awk '{print $5}')"

CMDLINE="console=tty0 printk.devkmsg=on androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 service_locator.enable=1 swiotlb=2048 loop.max_part=16 androidboot.usbcontroller=a600000.dwc3 androidboot.selinux=permissive enforcing=0 androidboot.boot_devices=soc/1d84000.ufshc ufs_qcom.async_probe=1 boot=halium datapart=/dev/block/sda19"

echo "==> [2/3] Generating boot.img (Header v3, OS 13.0.0, Kernel only)..."
mkbootimg \
	--header_version 3 \
	--os_version 13.0.0 \
	--os_patch_level 2024-01 \
	--kernel "$KERNEL_DIR/Image.lz4" \
	-o "$OUTPUT_DIR/boot.img"

echo "==> [3/3] Generating vendor_boot.img (Header v3, DTB + Halium LZ4 Ramdisk + Cmdline)..."
mkbootimg \
	--header_version 3 \
	--pagesize 4096 \
	--vendor_cmdline "$CMDLINE" \
	--dtb "$KERNEL_DIR/lito-v2.dtb" \
	--vendor_ramdisk "$OUTPUT_DIR/ramdisk.lz4" \
	--vendor_boot "$OUTPUT_DIR/vendor_boot.img"

echo "=============================================================================="
echo "✅ Droidian Boot Images Successfully Generated!"
echo "   - boot.img:        $OUTPUT_DIR/boot.img ($(ls -lh "$OUTPUT_DIR/boot.img" | awk '{print $5}'))"
echo "   - vendor_boot.img: $OUTPUT_DIR/vendor_boot.img ($(ls -lh "$OUTPUT_DIR/vendor_boot.img" | awk '{print $5}'))"
echo "=============================================================================="
